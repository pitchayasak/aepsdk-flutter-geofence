import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.adobe.example.aepsdk_flutter_geofence"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    val secretsFile = rootProject.file("secrets.properties")
    val secrets = Properties()
    if (secretsFile.exists()) {
        secretsFile.inputStream().use { secrets.load(it) }
    }

    defaultConfig {
        applicationId = "com.adobe.example.aepsdk_flutter_geofence"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = secrets.getProperty("MAPS_API_KEY", "")
        buildConfigField("String", "ADOBE_APP_ID", "\"${secrets.getProperty("ADOBE_APP_ID", "")}\"")

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.adobe.marketing.mobile:places:3.0.2")
    implementation("com.adobe.marketing.mobile:assurance:3.0.1")
    implementation("com.adobe.marketing.mobile:edge:3.0.0")
    implementation("com.adobe.marketing.mobile:edgeidentity:3.0.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
}
