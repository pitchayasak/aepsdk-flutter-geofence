# Build & Integration Issues — AEP Places 3.x via Method Channel

บันทึกปัญหาที่เจอและวิธีแก้ไขระหว่างการ implement geofence ด้วย AEP Places 3.x บน Flutter Android

---

## 1. `flutter_acpplaces` ขัดแย้งกับ `flutter_aepcore` (ACP/AEP SDK Conflict)

**ปัญหา:**  
`flutter_acpplaces` (ACP 1.x) และ `flutter_aepcore` (AEP 5.x) ต่างฝ่ายต่าง ship class `com.adobe.marketing.mobile.MobileCore` ทำให้ AEP version ชนะตอน runtime → ACP Places ไม่มี MobileCore ที่รู้จัก → app crash ทันทีที่กด "GET NEARBY POIs"

**วิธีแก้:**  
ลบ `flutter_acpplaces` ออกทั้งหมด แล้วใช้ **AEP Places 3.0.2 native Android SDK** ผ่าน Flutter MethodChannel แทน  
- เพิ่ม `com.adobe.marketing.mobile:places:3.0.2` ใน `android/app/build.gradle.kts`
- สร้าง MethodChannel `aep_places_channel` ใน `MainActivity.kt`
- สร้าง Dart wrapper `lib/services/aep_places_channel.dart`

---

## 2. `namespace` ไม่มีใน `build.gradle` ของ flutter_acpplaces (AGP 8+)

**ปัญหา:**  
```
A problem occurred configuring project ':flutter_acpcore'.
> Namespace not specified. Specify a namespace in the module's build file
```
AGP 8+ บังคับต้องมี `namespace` ใน `build.gradle` ของทุก module แต่ `flutter_acpcore` และ `flutter_acpplaces` เวอร์ชันเก่าไม่มี

**วิธีแก้ (ชั่วคราว ก่อนย้ายไป AEP):**  
คัดลอก packages มาไว้ใน `local_packages/` แล้วเพิ่ม `namespace` ใน build.gradle แต่ละตัว จากนั้นใช้ `dependency_overrides` ใน `pubspec.yaml` ชี้ไปที่ local copies

```groovy
// local_packages/flutter_acpcore/android/build.gradle
android {
    namespace 'com.adobe.marketing.mobile.flutter'
    ...
}
```

**วิธีแก้ถาวร:**  
ย้ายไปใช้ AEP Places 3.x ซึ่งไม่มีปัญหานี้เลย

---

## 3. `PlacesPOI` class ไม่สามารถ reference โดยตรงได้ใน Kotlin

**ปัญหา:**  
```
error: Unresolved reference 'PlacesPOI'
Unresolved reference 'identifier', 'name', 'latitude'...
```
Import `com.adobe.marketing.mobile.PlacesPOI` ไม่พบ หรือ property names ไม่ตรง

**วิธีแก้:**  
ใช้ reflection เพื่อเข้าถึง properties ของ PlacesPOI แทนการ reference โดยตรง

```kotlin
private fun poisToJson(pois: List<*>?): String {
    pois?.forEach { poi ->
        val cls = poi.javaClass
        try { obj.put("name", cls.getMethod("getName").invoke(poi)) } catch (_: Exception) {}
        try { obj.put("latitude", cls.getMethod("getLatitude").invoke(poi)) } catch (_: Exception) {}
        // ...
    }
}
```

---

## 4. `Geofence` class ไม่พบ (play-services-location ขาด)

**ปัญหา:**  
```
error: Unresolved reference 'Geofence'
Cannot access class 'Geofence'. Check your module classpath for missing or conflicting dependencies
```
`com.google.android.gms.location.Geofence` ไม่อยู่ใน compile classpath ของ app module

**วิธีแก้:**  
เพิ่ม dependency ใน `android/app/build.gradle.kts` โดยตรง

```kotlin
dependencies {
    implementation("com.adobe.marketing.mobile:places:3.0.2")
    implementation("com.google.android.gms:play-services-location:21.0.1")
}
```

---

## 5. `build.gradle.kts` syntax error — `java.util.Properties` ไม่รู้จัก

**ปัญหา:**  
```
Unresolved reference: util
Unresolved reference: load
```
Kotlin DSL ใน `build.gradle.kts` ไม่สามารถใช้ `java.util.Properties` โดยไม่ import

**วิธีแก้:**  
เพิ่ม import ที่ต้น file และใช้ syntax ที่ถูกต้อง

```kotlin
import java.util.Properties

// ...
val secrets = Properties()
if (secretsFile.exists()) {
    secretsFile.inputStream().use { secrets.load(it) }
}
```

---

## 6. Mock Location — `powerUsage is out of range of [1, 3]`

**ปัญหา:**  
```
setMockLocation [gps] failed: powerUsage is out of range of [1, 3] (too low)
```
`LocationManager.addTestProvider` รับ `powerUsage` เป็นค่า 1–3 แต่เราส่ง `0`

**วิธีแก้:**  
ใช้ค่าคงที่จาก `android.location.Criteria` แทนตัวเลขตรงๆ

```kotlin
lm.addTestProvider(
    provider,
    false, false, false, false, true, true, true,
    android.location.Criteria.POWER_LOW,   // = 1
    android.location.Criteria.ACCURACY_FINE // = 1
)
```

---

## 7. Mock Location — `gps provider is not a test provider`

**ปัญหา:**  
```
setMockLocation [gps] failed: gps provider is not a test provider
```
`addTestProvider` ถูก catch เงียบๆ แล้ว `setTestProviderLocation` fail เพราะ provider ไม่ได้ถูก add จริง

**วิธีแก้:**  
Remove provider ก่อนแล้ว re-add ใหม่ และตั้งค่าทั้ง GPS + Network provider พร้อมกัน

```kotlin
try { lm.removeTestProvider(provider) } catch (_: Exception) {}
lm.addTestProvider(provider, ...)
lm.setTestProviderEnabled(provider, true)
lm.setTestProviderLocation(provider, mock)
```

> **หมายเหตุ:** ต้องตั้งค่า **Settings → Developer Options → Select mock location app → เลือก AEP Geofence** ก่อนใช้งาน

---

## 8. `GET NEARBY POIs` ค้นหาพิกัดผิด (Googleplex แทน Lotus Bangkapi)

**ปัญหา:**  
ค้นหา POI ที่ lat=37.42, lng=-122.08 (Googleplex, California) ทั้งที่แผนที่แสดง Lotus Bangkapi เพราะ `_currentPosition` ถูก override ด้วย GPS จาก emulator

**วิธีแก้:**  
ตั้งค่า `_currentPosition` เริ่มต้นเป็น Lotus Bangkapi โดยตรง และไม่ auto-update จาก GPS ตอน init

```dart
Position _currentPosition = Position(
  latitude: 13.7657,
  longitude: 100.6331,
  // ...
);

Future<void> _initLocation() async {
  await Permission.locationWhenInUse.request();
  // ไม่ดึง GPS อัตโนมัติ — รอให้ผู้ใช้กด "center on me"
}
```

---

## 9. AEP Assurance — `SDK configuration is not available to read OrgId`

**ปัญหา:**  
```
Assurance/AssuranceStateManager - SDK configuration is not available to read OrgId
```
`MobileCore.registerExtensions([..., Assurance.EXTENSION])` ถูกเรียกก่อนที่ `configureWithAppID` จะทำงาน ทำให้ Assurance ไม่รู้จัก OrgId

**สาเหตุ:**  
`registerExtensions` อยู่ใน `MainActivity.onCreate` (เร็ว) แต่ `configureWithAppID` ถูกเรียกจาก Dart ผ่าน `MobileCore.initializeWithAppId` (ช้ากว่า เพราะรอ Flutter engine)

**วิธีแก้:**  
เรียก `configureWithAppID` ใน callback ของ `registerExtensions` เองทันที และอ่าน App ID จาก `BuildConfig` ที่มาจาก `secrets.properties`

```kotlin
// android/app/build.gradle.kts
buildConfigField("String", "ADOBE_APP_ID", "\"${secrets.getProperty("ADOBE_APP_ID", "")}\"")

// MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    MobileCore.registerExtensions(listOf(Places.EXTENSION, Assurance.EXTENSION)) {
        MobileCore.configureWithAppID(BuildConfig.ADOBE_APP_ID)
    }
}
```

```properties
# android/secrets.properties (gitignored)
ADOBE_APP_ID=xxxx/xxxx/launch-xxxx-development
```

---

## 10. Assurance — `Session already exists`

**ปัญหา:**  
```
Unable to start Assurance session. Session already exists
```
Session เก่าจาก run ก่อนหน้ายังค้างอยู่ใน SDK state

**วิธีแก้:**  
`flutter_aepassurance` ไม่มี `stopSession` API รอให้ Assurance timeout อัตโนมัติ (~5 วินาทีหลัง app เปิด) แล้วจึงกด Connect  
ใน app เปลี่ยน error message ให้ user-friendly โดยตรวจ error code และแสดง snackbar สีเขียว:

```dart
final isAlreadyExists = msg.toLowerCase().contains('already exist');
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text(isAlreadyExists
      ? '✅ Assurance session กำลัง active อยู่แล้ว'
      : 'Error: $msg'),
  backgroundColor: isAlreadyExists ? Colors.green : Colors.red,
));
```

---

## 11. AEP Edge — `EdgeIdentity` ต้องใช้ import ที่ต่างออกไป

**ปัญหา:**  
ต้องการ register Edge Identity extension ใน `MainActivity.kt` แต่ `Identity` class มี 2 ตัว — AEP Core Identity และ Edge Identity ซึ่งต้องระวัง import ไม่ให้ชนกัน

**วิธีแก้:**  
ใช้ full package path ที่ถูกต้องสำหรับ Edge Identity

```kotlin
import com.adobe.marketing.mobile.edge.identity.Identity  // Edge Identity
// ไม่ใช่ com.adobe.marketing.mobile.Identity              // Core Identity
```

และเพิ่ม native dependency ใน `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.adobe.marketing.mobile:edge:3.0.0")
    implementation("com.adobe.marketing.mobile:edgeidentity:3.0.0")
}
```

---

## สรุป SDK ที่ใช้งานจริง

| Extension | วิธี Register | หมายเหตุ |
|-----------|--------------|----------|
| AEP Core | `MobileCore.initializeWithAppId` (Dart) | auto-registers Identity, Lifecycle, Signal |
| AEP Places | `MobileCore.registerExtensions([Places.EXTENSION])` (native) | ต้อง configure ใน callback |
| AEP Assurance | `MobileCore.registerExtensions([Assurance.EXTENSION])` (native) | ต้อง configure ก่อน session start |
| AEP Edge | `MobileCore.registerExtensions([Edge.EXTENSION])` (native) | ส่ง XDM events ไป Edge Network |
| Edge Identity | `MobileCore.registerExtensions([Identity.EXTENSION])` (native) | `com.adobe.marketing.mobile.edge.identity.Identity` |
| UserProfile | auto via `flutter_aepuserprofile` plugin | — |

---

## สรุป Data Flow

```
POI Entry/Exit
  ├── Places.processGeofence          → Adobe Places backend
  ├── MobileCore.trackAction          → Analytics (พร้อม identity context data)
  └── Edge.sendEvent (XDM)            → Adobe Edge Network → AEP

Identity Sync
  ├── Identity.syncIdentifiersWithAuthState  → AEP Identity (เชื่อมกับ ECID)
  └── Edge.sendEvent (identityMap XDM)       → Adobe Edge Network → AEP

Custom Tracking
  ├── MobileCore.trackAction/State    → Analytics
  └── Edge.sendEvent (custom XDM)     → Adobe Edge Network → AEP
```
