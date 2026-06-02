import 'package:flutter/services.dart';

class AepPlacesChannel {
  static const _channel = MethodChannel('aep_places_channel');

  static Future<String?> getNearbyPointsOfInterest(
    double lat,
    double lng,
    int limit,
  ) async {
    return _channel.invokeMethod<String>('getNearbyPointsOfInterest', {
      'latitude': lat,
      'longitude': lng,
      'limit': limit,
    });
  }

  static Future<void> processGeofenceEntry(
    String id,
    double lat,
    double lng,
    int radius,
  ) async {
    await _channel.invokeMethod('processGeofence', {
      'requestId': id,
      'latitude': lat,
      'longitude': lng,
      'radius': radius,
      'transitionType': 1, // Geofence.GEOFENCE_TRANSITION_ENTER
    });
  }

  static Future<void> processGeofenceExit(
    String id,
    double lat,
    double lng,
    int radius,
  ) async {
    await _channel.invokeMethod('processGeofence', {
      'requestId': id,
      'latitude': lat,
      'longitude': lng,
      'radius': radius,
      'transitionType': 2, // Geofence.GEOFENCE_TRANSITION_EXIT
    });
  }

  static Future<String?> getCurrentPointsOfInterest() async {
    return _channel.invokeMethod<String>('getCurrentPointsOfInterest');
  }
}
