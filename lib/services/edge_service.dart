import 'package:flutter/foundation.dart';
import 'package:flutter_aepedge/flutter_aepedge.dart';
import 'package:flutter_aepedgeidentity/flutter_aepedgeidentity.dart' as edge_identity;
import '../models/poi_model.dart';

class EdgeService {
  // เก็บ identities ที่ sync ล่าสุดไว้ใน memory
  // เพื่อ inject เข้า XDM event payload โดยตรง (guaranteed ว่าส่งไปพร้อมกัน)
  static Map<String, dynamic> _cachedIdentityMap = {};
  // ── Geofence Events ───────────────────────────────────────────────────────

  /// ส่ง XDM event เมื่อเข้า POI ผ่าน Adobe Edge Network
  static Future<List<EventHandle>> sendPoiEntry(PoiModel poi) async {
    debugPrint('[EdgeService] sendPoiEntry called: ${poi.name} id=${poi.identifier}');
    final xdm = _buildPoiXdm(eventType: 'location.entry', poi: poi);
    return _sendEvent(xdm);
  }

  /// ส่ง XDM event เมื่อออก POI ผ่าน Adobe Edge Network
  static Future<List<EventHandle>> sendPoiExit(PoiModel poi) async {
    debugPrint('[EdgeService] sendPoiExit called: ${poi.name} id=${poi.identifier}');
    final xdm = _buildPoiXdm(eventType: 'location.exit', poi: poi);
    return _sendEvent(xdm);
  }

  // ── Edge Identity (updateIdentities) ─────────────────────────────────────

  /// ลงทะเบียน identities กับ Edge Identity extension
  /// หลังจากนี้ ทุก Edge event จะมี email/CIF/lumaCRMId ใน identityMap อัตโนมัติ
  /// authenticatedState จะเป็น "authenticated" แทน "ambiguous"
  static Future<void> updateEdgeIdentities({
    String? email,
    String? lumaCRMId,
    String? cif,
    Map<String, String>? customIds,
  }) async {
    // 1. Cache identities สำหรับ inject เข้า XDM โดยตรง
    final idMap = <String, dynamic>{};
    void addId(String ns, String id, bool primary) {
      idMap[ns] = [{'id': id, 'authenticatedState': 'authenticated', 'primary': primary}];
    }
    if (email != null && email.isNotEmpty) addId('Email', email, true);
    if (lumaCRMId != null && lumaCRMId.isNotEmpty) addId('lumaCRMId', lumaCRMId, false);
    if (cif != null && cif.isNotEmpty) addId('CIF', cif, false);
    customIds?.forEach((ns, id) { if (id.isNotEmpty) addId(ns, id, false); });
    _cachedIdentityMap = idMap;

    // 2. ลอง EdgeIdentity.updateIdentities() ด้วย (best-effort)
    try {
      final map = edge_identity.IdentityMap();
      if (email != null && email.isNotEmpty) {
        map.addItem(edge_identity.IdentityItem(email, edge_identity.AuthenticatedState.AUTHENTICATED, true), 'Email');
      }
      if (lumaCRMId != null && lumaCRMId.isNotEmpty) {
        map.addItem(edge_identity.IdentityItem(lumaCRMId, edge_identity.AuthenticatedState.AUTHENTICATED), 'lumaCRMId');
      }
      if (cif != null && cif.isNotEmpty) {
        map.addItem(edge_identity.IdentityItem(cif, edge_identity.AuthenticatedState.AUTHENTICATED), 'CIF');
      }
      customIds?.forEach((ns, id) {
        if (id.isNotEmpty) map.addItem(edge_identity.IdentityItem(id, edge_identity.AuthenticatedState.AUTHENTICATED), ns);
      });
      if (!map.isEmpty()) await edge_identity.Identity.updateIdentities(map);
      debugPrint('[EdgeService] EdgeIdentity.updateIdentities OK');
    } catch (e) {
      debugPrint('[EdgeService] EdgeIdentity.updateIdentities failed: $e');
    }
  }

  // ── Identity XDM Event (legacy sendEvent approach) ────────────────────────

  /// ส่ง identity.update XDM event (นอกจาก updateEdgeIdentities แล้ว)
  static Future<List<EventHandle>> sendIdentityEvent({
    String? email,
    String? lumaCRMId,
    String? cif,
    Map<String, String>? customIds,
  }) async {
    // 1. Update Edge Identity ก่อน → ทุก event ถัดไปจะมี identities อัตโนมัติ
    await updateEdgeIdentities(
      email: email,
      lumaCRMId: lumaCRMId,
      cif: cif,
      customIds: customIds,
    );

    // 2. ส่ง XDM event identity.update ด้วย
    final identityMap = <String, dynamic>{};
    if (email != null && email.isNotEmpty) {
      identityMap['Email'] = [{'id': email, 'primary': true, 'authenticatedState': 'authenticated'}];
    }
    if (lumaCRMId != null && lumaCRMId.isNotEmpty) {
      identityMap['lumaCRMId'] = [{'id': lumaCRMId, 'authenticatedState': 'authenticated'}];
    }
    if (cif != null && cif.isNotEmpty) {
      identityMap['CIF'] = [{'id': cif, 'authenticatedState': 'authenticated'}];
    }
    customIds?.forEach((type, value) {
      if (value.isNotEmpty) {
        identityMap[type] = [{'id': value, 'authenticatedState': 'authenticated'}];
      }
    });

    if (identityMap.isEmpty) return [];
    return _sendEvent({'eventType': 'identity.update', 'identityMap': identityMap});
  }

  // ── Custom XDM Event ──────────────────────────────────────────────────────

  /// ส่ง XDM event แบบ custom (กำหนด eventType และ data เองได้)
  static Future<List<EventHandle>> sendCustomEvent({
    required String eventType,
    required Map<String, dynamic> xdmData,
    Map<String, dynamic>? freeFormData,
    String? datasetId,
  }) async {
    final xdm = <String, dynamic>{
      'eventType': eventType,
      ...xdmData,
    };
    return _sendEvent(xdm, freeFormData: freeFormData, datasetId: datasetId);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _buildPoiXdm({
    required String eventType,
    required PoiModel poi,
  }) {
    final isEntry = eventType == 'location.entry';
    return {
      'eventType': eventType,
      'placeContext': {
        'POIinteraction': {
          'poiEntries': {'value': isEntry ? 1 : 0},
          'poiExits':   {'value': isEntry ? 0 : 1},
          'poiDetail': {
            'name': poi.name,
            'poiID': poi.identifier,
            // ลบ geoInteractionDetails/geoShape ออก — schema validation อาจปฏิเสธ
            // ถ้าต้องการ geo info ให้ใส่ใน freeFormData แทน
          },
        },
      },
      // ข้อมูล geo เพิ่มเติมใน free-form data (ไม่ผ่าน XDM schema validation)
      '_data': {
        'poi': {
          'latitude': poi.latitude,
          'longitude': poi.longitude,
          'radius': poi.radius,
        }
      },
    };
  }

  static Future<List<EventHandle>> _sendEvent(
    Map<String, dynamic> xdmData, {
    Map<String, dynamic>? freeFormData,
    String? datasetId,
  }) async {
    try {
      final xdmWithIdentity = Map<String, dynamic>.from(xdmData);
      if (_cachedIdentityMap.isNotEmpty) {
        xdmWithIdentity['identityMap'] = _cachedIdentityMap;
      }
      debugPrint('[EdgeService] Edge.sendEvent xdm keys: ${xdmWithIdentity.keys.toList()}');
      final event = ExperienceEvent.createEvent(xdmWithIdentity, freeFormData, datasetId);
      final handles = await Edge.sendEvent(event);
      debugPrint('[EdgeService] Edge.sendEvent OK — ${handles.length} handle(s)');
      return handles;
    } catch (e) {
      debugPrint('[EdgeService] Edge.sendEvent FAILED: $e');
      return [];
    }
  }
}
