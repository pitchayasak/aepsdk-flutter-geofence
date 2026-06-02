import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi_model.dart';
import 'aep_places_channel.dart';

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
    try {
      await AepPlacesChannel.processGeofenceEntry(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius,
      );
    } catch (_) {
      // non-fatal: geofence detection still works in Dart layer
    }
  }

  static Future<void> processExit(PoiModel poi) async {
    try {
      await AepPlacesChannel.processGeofenceExit(
        poi.identifier,
        poi.latitude,
        poi.longitude,
        poi.radius,
      );
    } catch (_) {
      // non-fatal: geofence detection still works in Dart layer
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
