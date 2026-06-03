import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepcore/flutter_aepidentity.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi_model.dart';
import 'aep_places_channel.dart';
import 'edge_service.dart';

class PlacesService {
  static Future<List<PoiModel>> getNearbyPois(
    Position position,
    int limit,
  ) async {
    try {
      final result = await AepPlacesChannel.getNearbyPointsOfInterest(
        position.latitude,
        position.longitude,
        limit,
      );
      if (result == null || result.isEmpty) return [];
      final List<dynamic> rawList = jsonDecode(result);
      return rawList
          .map((p) => PoiModel.fromAcpPoi(p as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw PlacesException(e.message ?? e.code);
    } catch (e) {
      throw PlacesException(e.toString());
    }
  }

  static Future<void> processEntry(PoiModel poi) async {
    // 1. ส่ง Places processGeofence (แนบ ECID อัตโนมัติ)
    try {
      await AepPlacesChannel.processGeofenceEntry(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius,
      );
    } catch (_) {}

    // 2. trackAction (Analytics) พร้อม POI data + identity
    await _trackGeofenceEvent('places_poi_entry', poi);
    // 3. Edge Network — XDM event ส่งตรงไป Adobe Experience Platform
    EdgeService.sendPoiEntry(poi);
  }

  static Future<void> processExit(PoiModel poi) async {
    try {
      await AepPlacesChannel.processGeofenceExit(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius,
      );
    } catch (_) {}

    await _trackGeofenceEvent('places_poi_exit', poi);
    EdgeService.sendPoiExit(poi);
  }

  /// ส่ง trackAction พร้อม POI info + identity ที่มีอยู่ใน event payload
  static Future<void> _trackGeofenceEvent(String action, PoiModel poi) async {
    try {
      // ดึง identifiers ที่ sync ไว้ (email, lumaCRMId, custom ฯลฯ)
      final identifiers = await Identity.identifiers;
      final identityData = <String, String>{};
      for (final id in identifiers) {
        identityData['identity.${id.idType}'] = id.identifier;
      }

      final contextData = <String, String>{
        'poi.identifier': poi.identifier,
        'poi.name': poi.name,
        'poi.latitude': poi.latitude.toStringAsFixed(6),
        'poi.longitude': poi.longitude.toStringAsFixed(6),
        'poi.radius': poi.radius.toString(),
        if (poi.category != null) 'poi.category': poi.category!,
        ...identityData, // แนบ identity ทั้งหมดเข้า event
      };

      await MobileCore.trackAction(action, data: contextData);
    } catch (_) {}
  }
}

class PlacesException implements Exception {
  final String message;
  final bool sdkUnavailable;
  PlacesException(this.message, {this.sdkUnavailable = false});
  @override
  String toString() => message;
}
