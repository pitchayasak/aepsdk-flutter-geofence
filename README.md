# AEP SDK Flutter Geofence

Flutter app สำหรับทดสอบ Adobe Experience Platform (AEP) Places Geofence บน Android
แสดงแผนที่ Google Maps, ดึง POI จาก Adobe Places, และตรวจจับ entry/exit geofence

## Features

- แผนที่ Google Maps พร้อม POI markers และ geofence circle overlay
- ดึง Nearby POIs จาก Adobe Places SDK 3.x
- กดค้างบนแผนที่เพื่อตั้ง test location + mock GPS บน emulator
- ตรวจจับ entry/exit อัตโนมัติพร้อม dialog แจ้งเตือน
- ส่ง processGeofence event ไปยัง Adobe Places
- เพิ่ม POI เองสำหรับทดสอบ (ปุ่ม + บนแผนที่)
- AEP Assurance สำหรับ debug events

---

## การตั้งค่าก่อนรัน

### 1. Google Maps API Key

**สร้าง API Key:**
1. ไปที่ [Google Cloud Console](https://console.cloud.google.com)
2. สร้างหรือเลือก Project
3. ไปที่ **APIs & Services → Credentials → Create Credentials → API key**
4. ไปที่ **APIs & Services → Library** แล้วเปิดใช้ **Maps SDK for Android**
5. (แนะนำ) จำกัด key ให้ใช้ได้เฉพาะ Android app ด้วย package name `com.adobe.example.aepsdk_flutter_geofence`

**ใส่ค่าใน project:**

```bash
# คัดลอก template
cp android/secrets.properties.example android/secrets.properties
```

แก้ไข `android/secrets.properties`:
```properties
MAPS_API_KEY=AIzaSy...YOUR_KEY_HERE
```

> ไฟล์ `secrets.properties` อยู่ใน `.gitignore` จะไม่ถูก commit

---

### 2. Adobe App ID

**หา App ID:**
1. ไปที่ [Adobe Experience Platform Data Collection](https://experience.adobe.com/#/data-collection)
2. เลือก **Mobile Property** ที่ต้องการ
3. ไปที่ **Environments** → คัดลอก **App ID** ของ environment ที่ต้องการ (Development / Staging / Production)

**ตรวจสอบว่า Property มี Extensions ต่อไปนี้ติดตั้งแล้ว:**
- Mobile Core
- Adobe Experience Platform Places

**ใส่ค่าใน project:**

```bash
# คัดลอก template
cp lib/config.example.dart lib/config.dart
```

แก้ไข `lib/config.dart`:
```dart
class AppConfig {
  static const String adobeAppId = 'YOUR_APP_ID_HERE';
}
```

> ไฟล์ `lib/config.dart` อยู่ใน `.gitignore` จะไม่ถูก commit

---

### 3. ติดตั้ง Dependencies

```bash
flutter pub get
```

---

## การตั้งค่า Android Emulator

### เปิด Developer Options

1. เปิด **Settings** บน emulator
2. ไปที่ **About emulated device**
3. กด **Build number** 7 ครั้งติดต่อกัน จนขึ้นข้อความ "You are now a developer!"
4. กลับไปที่ **Settings → System → Developer Options** (หรือ Settings → Developer Options ขึ้นอยู่กับ Android version)

### ตั้งค่า Mock Location App

1. ใน **Developer Options** เลื่อนหา **Select mock location app**
2. เลือก **AEP Geofence**

> หลังจากตั้งค่าแล้ว เมื่อกดค้างบนแผนที่ใน app, GPS ของ emulator จะถูกตั้งค่าไปที่จุดที่ปักทันที ทำให้ blue dot (My Location) และ Adobe Places ใช้พิกัดเดียวกัน

---

## วิธีรัน

```bash
# รันบน emulator ที่เชื่อมต่ออยู่
flutter run

# ระบุ device
flutter run -d emulator-5554
```

---

## วิธีทดสอบ Geofence

1. เปิด app — แผนที่เริ่มต้นที่ **Lotus Bangkapi, Bangkok**
2. กด **GET NEARBY POIs** — ดึง POI จาก Adobe Places (ต้องมี POI Library กำหนดใน Adobe Launch)
3. ถ้าไม่มี POI → กดปุ่ม **+** (สีเขียว) เพื่อเพิ่ม POI เองสำหรับทดสอบ
4. **กดค้างบนแผนที่** เพื่อวาง test location (marker สีฟ้า) — GPS emulator จะย้ายไปด้วย
5. เมื่อ test location อยู่ใน radius ของ POI → dialog **"เข้าสู่ POI แล้ว!"** ขึ้นทันที
6. ย้าย test location ออกนอก radius → dialog **"ออกจาก POI แล้ว!"**
7. กด **ENTRY** / **EXIT** ใน POI bottom sheet เพื่อส่ง event ไปยัง Adobe Places โดยตรง

### AEP Assurance

1. กดไอคอน 🛡️ ที่ AppBar
2. ใส่ Assurance Session URL จาก Adobe Experience Platform
3. กด **Connect** เพื่อ debug events แบบ real-time

---

## โครงสร้าง Project

```
lib/
├── main.dart                        # AEP SDK initialization
├── config.dart                      # API keys (gitignored)
├── config.example.dart              # Template สำหรับ config.dart
├── models/
│   └── poi_model.dart               # POI data class
├── screens/
│   └── geofence_map_screen.dart     # หน้าหลัก
├── services/
│   ├── aep_places_channel.dart      # Flutter ↔ Android MethodChannel
│   └── places_service.dart          # AEP Places wrapper
└── widgets/
    ├── add_poi_dialog.dart          # Dialog เพิ่ม POI
    └── poi_bottom_sheet.dart        # POI detail + Entry/Exit

android/
├── secrets.properties               # API keys (gitignored)
├── secrets.properties.example       # Template สำหรับ secrets.properties
└── app/src/main/kotlin/.../
    └── MainActivity.kt              # AEP Places MethodChannel handler
```

---

## Dependencies หลัก

| Package | Version | หน้าที่ |
|---------|---------|--------|
| flutter_aepcore | ^5.0.1 | AEP Mobile Core |
| flutter_aepassurance | ^5.0.0 | AEP Assurance |
| google_maps_flutter | ^2.9.0 | Google Maps |
| geolocator | ^13.0.0 | GPS |
| permission_handler | ^11.3.1 | Location permissions |

**Native Android (ผ่าน MethodChannel):**
- `com.adobe.marketing.mobile:places:3.0.2` — AEP Places SDK
- `com.google.android.gms:play-services-location:21.0.1` — Geofence API
