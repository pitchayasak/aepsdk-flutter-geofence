package com.adobe.example.aepsdk_flutter_geofence

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerAcpPlaces()
    }

    private fun registerAcpPlaces() {
        try {
            // Register ACP Places extension with ACP MobileCore so that
            // FlutterACPPlaces native calls don't crash on uninitialized SDK.
            val mobileCoreClass = Class.forName("com.adobe.marketing.mobile.MobileCore")
            val placesClass = Class.forName("com.adobe.marketing.mobile.Places")

            // MobileCore.setApplication(application)
            mobileCoreClass.getMethod("setApplication", android.app.Application::class.java)
                .invoke(null, application)

            // MobileCore.registerExtension(Places.class, null) — ACP 1.x API
            try {
                val extClass = Class.forName("com.adobe.marketing.mobile.Extension")
                val registerExt = mobileCoreClass.getMethod(
                    "registerExtension",
                    Class::class.java,
                    Class.forName("com.adobe.marketing.mobile.ExtensionErrorCallback")
                )
                registerExt.invoke(null, placesClass, null)
            } catch (e: Exception) {
                Log.w("AcpPlacesInit", "registerExtension failed (AEP MobileCore active?): ${e.message}")
            }

            // MobileCore.start(null)
            try {
                val startMethod = mobileCoreClass.getMethod(
                    "start",
                    Class.forName("com.adobe.marketing.mobile.AdobeCallback")
                )
                startMethod.invoke(null, null)
            } catch (e: Exception) {
                Log.w("AcpPlacesInit", "start failed: ${e.message}")
            }

            Log.d("AcpPlacesInit", "ACP Places registration attempted")
        } catch (e: Exception) {
            Log.e("AcpPlacesInit", "ACP Places init failed: ${e.message}")
        }
    }
}
