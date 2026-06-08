import 'package:flutter_aepedge/flutter_aepedge.dart';
import 'package:flutter_aepedgeidentity/flutter_aepedgeidentity.dart' as edge_identity;
import '../models/poi_model.dart';

class EdgeService {
  // ── Geofence Events ───────────────────────────────────────────────────────

  /// ส่ง XDM event เมื่อเข้า POI ผ่าน Adobe Edge Network
  static Future<List<EventHandle>> sendPoiEntry(PoiModel poi) async {
    final xdm = _buildPoiXdm(
      eventType: 'location.entry',
      poi: poi,
    );
    return _sendEvent(xdm);
  }

  /// ส่ง XDM event เมื่อออก POI ผ่าน Adobe Edge Network
  static Future<List<EventHandle>> sendPoiExit(PoiModel poi) async {
    final xdm = _buildPoiXdm(
      eventType: 'location.exit',
      poi: poi,
    );
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
    try {
      final map = edge_identity.IdentityMap();

      if (email != null && email.isNotEmpty) {
        map.addItem(
          edge_identity.IdentityItem(email, edge_identity.AuthenticatedState.AUTHENTICATED, true),
          'Email',
        );
      }
      if (lumaCRMId != null && lumaCRMId.isNotEmpty) {
        map.addItem(
          edge_identity.IdentityItem(lumaCRMId, edge_identity.AuthenticatedState.AUTHENTICATED),
          'lumaCRMId',
        );
      }
      if (cif != null && cif.isNotEmpty) {
        map.addItem(
          edge_identity.IdentityItem(cif, edge_identity.AuthenticatedState.AUTHENTICATED),
          'CIF',
        );
      }
      customIds?.forEach((namespace, id) {
        if (id.isNotEmpty) {
          map.addItem(
            edge_identity.IdentityItem(id, edge_identity.AuthenticatedState.AUTHENTICATED),
            namespace,
          );
        }
      });

      if (!map.isEmpty()) {
        await edge_identity.Identity.updateIdentities(map);
      }
    } catch (_) {}
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
    return {
      'eventType': eventType,
      'placeContext': {
        'POIinteraction': {
          // poiEntries/poiExits บอก AEP ว่าเป็น entry หรือ exit
          'poiEntries': {'value': eventType == 'location.entry' ? 1 : 0},
          'poiExits':   {'value': eventType == 'location.exit'  ? 1 : 0},
          'poiDetail': {
            'name': poi.name,
            // ใช้ 'poiID' แทน 'POIID' เพื่อหลีกเลี่ยง duplicate column
            'poiID': poi.identifier,
            'geoInteractionDetails': {
              'distanceToCenter': 0,
              'accuracy': poi.radius.toDouble(),
              // ลบ _id และ _schema ออก เพราะเป็น system fields ที่ชนกัน
              'geoShape': {
                'circle': {
                  'radius': poi.radius.toDouble(),
                  'coordinates': [poi.longitude, poi.latitude],
                }
              }
            }
          }
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
      final event = ExperienceEvent.createEvent(xdmData, freeFormData, datasetId);
      final handles = await Edge.sendEvent(event);
      return handles;
    } catch (_) {
      return [];
    }
  }
}
