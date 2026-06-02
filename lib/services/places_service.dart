import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_acpplaces/flutter_acpplaces.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi_model.dart';

class PlacesService {
  static Future<List<PoiModel>> getNearbyPois(
    Position position,
    int limit,
  ) async {
    final location = {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
    try {
      final result = await FlutterACPPlaces.getNearbyPointsOfInterest(
        location,
        limit,
      );
      if (result == null || result.isEmpty) return [];
      final List<dynamic> rawList = jsonDecode(result);
      return rawList
          .map((p) => PoiModel.fromAcpPoi(p as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw PlacesException(
        e.code == 'PLACES_SDK_UNAVAILABLE'
            ? 'Adobe Places SDK ไม่พร้อมใช้งาน\n\nเนื่องจาก ACP SDK (1.x) ไม่เข้ากันกับ AEP SDK (5.x)\nในขณะนี้ กรุณาเพิ่ม POI เองด้วยปุ่ม +'
            : (e.message ?? e.code),
        sdkUnavailable: e.code == 'PLACES_SDK_UNAVAILABLE',
      );
    } catch (e) {
      throw PlacesException(e.toString());
    }
  }

  static Future<void> processEntry(PoiModel poi) async {
    try {
      final geofence = Geofence.createGeofence(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius.toDouble(),
        -1,
      );
      await FlutterACPPlaces.processGeofence(
        geofence,
        ACPPlacesRegionEventType.entry,
      );
    } catch (_) {
      // processGeofence errors are non-fatal for testing flow
    }
  }

  static Future<void> processExit(PoiModel poi) async {
    try {
      final geofence = Geofence.createGeofence(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius.toDouble(),
        -1,
      );
      await FlutterACPPlaces.processGeofence(
        geofence,
        ACPPlacesRegionEventType.exit,
      );
    } catch (_) {
      // processGeofence errors are non-fatal for testing flow
    }
  }
}

class PlacesException implements Exception {
  final String message;
  final bool sdkUnavailable;
  PlacesException(this.message, {this.sdkUnavailable = false});
  @override
  String toString() => message;
}
