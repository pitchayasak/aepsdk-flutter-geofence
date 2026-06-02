package com.adobe.example.aepsdk_flutter_geofence

import android.location.Location
import android.os.Bundle
import com.adobe.marketing.mobile.MobileCore
import com.adobe.marketing.mobile.Places
import com.google.android.gms.location.Geofence
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "aep_places_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MobileCore.registerExtensions(listOf(Places.EXTENSION)) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNearbyPointsOfInterest" -> handleGetNearby(call.arguments, result)
                    "processGeofence"           -> handleProcessGeofence(call.arguments, result)
                    "getCurrentPointsOfInterest" -> handleGetCurrent(result)
                    else                        -> result.notImplemented()
                }
            }
    }

    private fun handleGetNearby(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *>
            ?: return result.error("INVALID_ARGS", "Expected map arguments", null)
        val location = Location("flutter").apply {
            latitude = (map["latitude"] as Number).toDouble()
            longitude = (map["longitude"] as Number).toDouble()
        }
        val limit = (map["limit"] as Number).toInt()
        try {
            Places.getNearbyPointsOfInterest(
                location, limit,
                { pois -> runOnUiThread { result.success(poisToJson(pois)) } },
                { error -> runOnUiThread { result.error("PLACES_ERROR", error?.name ?: "unknown", null) } }
            )
        } catch (e: Throwable) {
            result.error("PLACES_ERROR", e.message, null)
        }
    }

    private fun handleProcessGeofence(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *>
            ?: return result.error("INVALID_ARGS", "Expected map arguments", null)
        try {
            val transitionType = (map["transitionType"] as Number).toInt()
            val geofence = Geofence.Builder()
                .setRequestId(map["requestId"] as String)
                .setCircularRegion(
                    (map["latitude"] as Number).toDouble(),
                    (map["longitude"] as Number).toDouble(),
                    (map["radius"] as Number).toFloat()
                )
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(transitionType)
                .build()
            Places.processGeofence(geofence, transitionType)
            result.success(null)
        } catch (e: Throwable) {
            result.error("PLACES_ERROR", e.message, null)
        }
    }

    private fun handleGetCurrent(result: MethodChannel.Result) {
        try {
            Places.getCurrentPointsOfInterest { pois ->
                runOnUiThread { result.success(poisToJson(pois)) }
            }
        } catch (e: Throwable) {
            result.error("PLACES_ERROR", e.message, null)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun poisToJson(pois: List<*>?): String {
        val arr = JSONArray()
        pois?.forEach { poi ->
            // Use reflection to avoid direct PlacesPOI class reference issues
            if (poi == null) return@forEach
            val cls = poi.javaClass
            val obj = JSONObject()
            try { obj.put("identifier", cls.getMethod("getIdentifier").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("name",       cls.getMethod("getName").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("latitude",   cls.getMethod("getLatitude").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("longitude",  cls.getMethod("getLongitude").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("radius",     cls.getMethod("getRadius").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("libraryId",  cls.getMethod("getLibraryId").invoke(poi)) } catch (_: Exception) {}
            try { obj.put("userIsWithin", cls.getMethod("userIsWithin").invoke(poi)) } catch (_: Exception) {}
            try {
                val meta = cls.getMethod("getMetaData").invoke(poi)
                if (meta is Map<*, *>) {
                    val metaObj = JSONObject()
                    meta.forEach { (k, v) -> metaObj.put(k.toString(), v.toString()) }
                    obj.put("metadata", metaObj)
                }
            } catch (_: Exception) {}
            arr.put(obj)
        }
        return arr.toString()
    }
}
