package com.adobe.example.aepsdk_flutter_geofence

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import com.adobe.marketing.mobile.Assurance
import com.adobe.marketing.mobile.Edge
import com.adobe.marketing.mobile.MobileCore
import com.adobe.marketing.mobile.Places
import com.adobe.marketing.mobile.edge.identity.Identity
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
        val appId = BuildConfig.ADOBE_APP_ID
        // Register Places + Assurance แล้ว configure ทันทีใน callback
        // เพื่อให้ Assurance มี OrgId ก่อนที่จะพยายาม connect session
        MobileCore.registerExtensions(listOf(
            Places.EXTENSION,
            Assurance.EXTENSION,
            Edge.EXTENSION,
            Identity.EXTENSION
        )) {
            MobileCore.configureWithAppID(appId)
            Log.d("AEPInit", "SDK initialized with appId: $appId")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeNative"           -> handleInitializeNative(call.arguments, result)
                    "getNearbyPointsOfInterest"  -> handleGetNearby(call.arguments, result)
                    "processGeofence"            -> handleProcessGeofence(call.arguments, result)
                    "getCurrentPointsOfInterest" -> handleGetCurrent(result)
                    "setMockLocation"            -> handleSetMockLocation(call.arguments, result)
                    else                         -> result.notImplemented()
                }
            }
    }

    // ── Native Init ──────────────────────────────────────────────────────────────

    private fun handleInitializeNative(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *>
            ?: return result.error("INVALID_ARGS", "Expected map arguments", null)
        val appId = map["appId"] as? String
            ?: return result.error("INVALID_ARGS", "Missing appId", null)
        try {
            // Register Places + Assurance แล้ว configure ใน callback
            // เพื่อให้ Assurance อ่าน OrgId ได้ทันที
            MobileCore.registerExtensions(listOf(
                Places.EXTENSION,
                Assurance.EXTENSION
            )) {
                MobileCore.configureWithAppID(appId)
                Log.d("AEPInit", "Native extensions registered + configured: $appId")
            }
            result.success(null)
        } catch (e: Throwable) {
            Log.e("AEPInit", "initializeNative failed: ${e.message}")
            result.error("INIT_ERROR", e.message, null)
        }
    }

    // ── Mock Location ────────────────────────────────────────────────────────────

    private fun handleSetMockLocation(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *>
            ?: return result.error("INVALID_ARGS", "Expected map arguments", null)
        val lat = (map["latitude"] as Number).toDouble()
        val lng = (map["longitude"] as Number).toDouble()
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        var anySuccess = false
        providers.forEach { provider ->
            try {
                // Remove ก่อน (ถ้ามีอยู่แล้ว) แล้วค่อย add ใหม่
                try { lm.removeTestProvider(provider) } catch (_: Exception) {}
                lm.addTestProvider(
                    provider,
                    false, false, false, false,
                    true, true, true,
                    android.location.Criteria.POWER_LOW,
                    android.location.Criteria.ACCURACY_FINE
                )
                lm.setTestProviderEnabled(provider, true)
                val mock = Location(provider).apply {
                    latitude = lat
                    longitude = lng
                    altitude = 0.0
                    accuracy = 1f
                    time = System.currentTimeMillis()
                    elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                }
                lm.setTestProviderLocation(provider, mock)
                Log.d("AEPPlaces", "mockLocation set [$provider]: lat=$lat lng=$lng")
                anySuccess = true
            } catch (e: Throwable) {
                Log.e("AEPPlaces", "setMockLocation [$provider] failed: ${e.message}")
            }
        }
        if (anySuccess) {
            result.success(null)
        } else {
            result.error("MOCK_ERROR",
                "ไม่สามารถตั้ง mock location ได้\n\nตรวจสอบว่า:\nSettings → Developer Options → Select mock location app → เลือก AEP Geofence",
                null)
        }
    }

    // ── AEP Places ───────────────────────────────────────────────────────────────

    private fun handleGetNearby(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *>
            ?: return result.error("INVALID_ARGS", "Expected map arguments", null)
        val location = Location("flutter").apply {
            latitude = (map["latitude"] as Number).toDouble()
            longitude = (map["longitude"] as Number).toDouble()
        }
        val limit = (map["limit"] as Number).toInt()
        Log.d("AEPPlaces", "getNearbyPOIs lat=${location.latitude} lng=${location.longitude} limit=$limit")
        try {
            Places.getNearbyPointsOfInterest(
                location, limit,
                { pois ->
                    Log.d("AEPPlaces", "success: ${pois?.size ?: 0} POIs returned")
                    pois?.forEach {
                        Log.d("AEPPlaces", "  POI: ${it.javaClass.getMethod("getName").invoke(it)}")
                    }
                    runOnUiThread { result.success(poisToJson(pois)) }
                },
                { error ->
                    Log.e("AEPPlaces", "error callback: ${error?.name}")
                    runOnUiThread { result.error("PLACES_ERROR", error?.name ?: "unknown", null) }
                }
            )
        } catch (e: Throwable) {
            Log.e("AEPPlaces", "exception: ${e.message}")
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
