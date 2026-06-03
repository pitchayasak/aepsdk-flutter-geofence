# AEP SDK Flutter Geofence

Flutter app สำหรับทดสอบ Adobe Experience Platform (AEP) Places Geofence บน Android  
แสดงแผนที่ Google Maps, ดึง POI จาก Adobe Places, ตรวจจับ entry/exit geofence และส่งข้อมูลผ่านหลายช่องทาง

---

## Features

| หมวด | รายละเอียด |
|------|-----------|
| 🗺️ แผนที่ | Google Maps พร้อม POI markers, geofence circle overlay, zoom +/- |
| 📍 POI | ดึง Nearby POIs จาก Adobe Places SDK 3.x |
| 🔵 Test Location | กดค้างบนแผนที่เพื่อวาง test pin + mock GPS บน emulator |
| 🔔 Geofence | ตรวจจับ entry/exit อัตโนมัติ + dialog แจ้งเตือน |
| ➕ Manual POI | เพิ่ม POI เองสำหรับทดสอบ (ปุ่ม + บนแผนที่) |
| 👤 Identity | Sync email, lumaCRMId, CIF และ custom identifiers |
| 📊 Tracking | trackAction / trackState พร้อม context data |
| 🧑‍💼 Profile | User Profile attributes (set/get/remove) |
| 🔒 PII | Collect PII ผ่าน MobileCore |
| 🔵 Edge | ส่ง XDM events ไปยัง Adobe Edge Network |
| 🛡️ Assurance | Debug AEP events แบบ real-time |

---

## Data Flow

```
POI Entry/Exit
  ├── Places.processGeofence     → Adobe Places backend
  ├── MobileCore.trackAction     → Analytics (พร้อม identity context data)
  └── Edge.sendEvent (XDM)       → Adobe Edge Network → AEP

Identity Sync
  ├── Identity.syncIdentifiers   → AEP Identity (เชื่อมกับ ECID)
  └── Edge.sendEvent (XDM)       → Adobe Edge Network → AEP

Custom Tracking
  ├── MobileCore.trackAction     → Analytics
  └── Edge.sendEvent (XDM)       → Adobe Edge Network → AEP
```

---

## การตั้งค่าก่อนรัน

### 1. Google Maps API Key

1. ไปที่ [Google Cloud Console](https://console.cloud.google.com)
2. **APIs & Services → Credentials → Create Credentials → API key**
3. **APIs & Services → Library** → เปิดใช้ **Maps SDK for Android**
4. (แนะนำ) จำกัด key ด้วย package name `com.adobe.example.aepsdk_flutter_geofence`

```bash
cp android/secrets.properties.example android/secrets.properties
```

แก้ไข `android/secrets.properties`:
```properties
MAPS_API_KEY=AIzaSy...YOUR_KEY_HERE
ADOBE_APP_ID=xxxx/xxxx/launch-xxxx-development
```

> `secrets.properties` อยู่ใน `.gitignore` — ไม่ถูก commit

---

### 2. Adobe App ID

1. ไปที่ [Adobe Experience Platform Data Collection](https://experience.adobe.com/#/data-collection)
2. เลือก **Mobile Property** → **Environments** → คัดลอก **App ID**

**Extensions ที่ต้องติดตั้งใน Mobile Property:**
- Mobile Core
- Places
- Edge Network
- Edge Identity
- (แนะนำ) Assurance

```bash
cp lib/config.example.dart lib/config.dart
```

แก้ไข `lib/config.dart`:
```dart
class AppConfig {
  static const String adobeAppId = 'YOUR_APP_ID_HERE';
}
```

> `lib/config.dart` อยู่ใน `.gitignore` — ไม่ถูก commit

---

### 3. ติดตั้ง Dependencies

```bash
flutter pub get
```

---

## การตั้งค่า Android Emulator

### เปิด Developer Options

1. **Settings → About emulated device**
2. กด **Build number** 7 ครั้ง จนขึ้น "You are now a developer!"
3. กลับไปที่ **Settings → System → Developer Options**

### ตั้งค่า Mock Location App

1. ใน **Developer Options** → **Select mock location app**
2. เลือก **AEP Geofence**

> หลังตั้งค่าแล้ว การกดค้างบนแผนที่จะ set GPS ของ emulator ไปที่จุดนั้นทันที

---

## วิธีรัน

```bash
flutter run                       # รันบน emulator ที่เชื่อมต่ออยู่
flutter run -d emulator-5554      # ระบุ device
flutter build apk --debug         # สร้าง APK สำหรับติดตั้งบนมือถือ
```

---

## วิธีใช้งาน

### Geofence (หน้าหลัก)

1. เปิด app — แผนที่เริ่มต้นที่ **Lotus Bangkapi, Bangkok** (13.7657, 100.6331)
2. กด **GET NEARBY POIs** — ดึง POI จาก Adobe Places
3. ถ้าไม่มี POI → กดปุ่ม **🟢 +** เพื่อเพิ่ม POI เองสำหรับทดสอบ
4. **กดค้างบนแผนที่** → วาง test location (marker สีฟ้า) + GPS emulator ย้ายไปด้วย
5. test location เข้าใน radius POI → dialog **"เข้าสู่ POI แล้ว!"** พร้อมส่ง event 3 ช่องทาง:
   - `Places.processGeofence` → Adobe Places
   - `MobileCore.trackAction` → Analytics
   - `Edge.sendEvent` (XDM placeContext) → Edge Network
6. ย้ายออก → dialog **"ออกจาก POI แล้ว!"**
7. กด marker → Bottom Sheet → กด **ENTRY / EXIT** เพื่อส่ง event โดยตรง

### Identity & Tracking (ไอคอน 👤)

| Tab | API | หน้าที่ |
|-----|-----|--------|
| **Identity** | `Identity.syncIdentifiersWithAuthState` | Sync email, lumaCRMId, CIF, custom identifiers |
| **Track** | `MobileCore.trackAction/State` | ส่ง Analytics events พร้อม context data |
| **Profile** | `UserProfile.updateUserAttributes` | Set/Get/Remove user profile attributes |
| **PII** | `MobileCore.collectPii` | ส่ง PII (ชื่อ, email, เบอร์) |
| **Edge** | `Edge.sendEvent` | ส่ง XDM events ไป Adobe Edge Network โดยตรง |

**Edge tab มี:**
- **Identity XDM** — ส่ง `identity.update` พร้อม email, lumaCRMId, CIF
- **Custom XDM** — กำหนด `eventType` + XDM schema + free-form data เองได้

### AEP Assurance (ไอคอน 🛡️)

1. ไปที่ [experience.adobe.com](https://experience.adobe.com) → **Assurance → Create Session**
2. กด **Copy Link** → ได้ URL รูปแบบ `griffon://...`
3. ใน app กดไอคอน 🛡️ → วาง URL → กด **Connect**
4. รอ ~5 วินาทีหลัง app เปิดก่อนกด Connect (ให้ startup timeout ผ่านก่อน)

---

## โครงสร้าง Project

```
lib/
├── main.dart                        # AEP SDK initialization
├── config.dart                      # API keys (gitignored)
├── config.example.dart              # Template
├── models/
│   └── poi_model.dart               # POI data class
├── screens/
│   ├── geofence_map_screen.dart     # หน้าหลัก (แผนที่ + POI)
│   └── identity_screen.dart         # Identity & Tracking (5 tabs)
├── services/
│   ├── aep_places_channel.dart      # Flutter ↔ Android MethodChannel
│   ├── edge_service.dart            # AEP Edge XDM event builder
│   └── places_service.dart          # Places + trackAction + Edge wrapper
└── widgets/
    ├── add_poi_dialog.dart           # Dialog เพิ่ม POI
    └── poi_bottom_sheet.dart         # POI detail + Entry/Exit buttons

android/
├── secrets.properties               # API keys (gitignored)
├── secrets.properties.example       # Template
└── app/src/main/kotlin/.../
    └── MainActivity.kt              # Places + Assurance + Edge MethodChannel
```

---

## Dependencies

### Flutter Packages

| Package | Version | หน้าที่ |
|---------|---------|--------|
| flutter_aepcore | ^5.0.1 | AEP Mobile Core + Identity |
| flutter_aepassurance | ^5.0.0 | AEP Assurance |
| flutter_aepuserprofile | ^5.0.0 | User Profile |
| flutter_aepedge | ^5.0.0 | AEP Edge Network |
| google_maps_flutter | ^2.9.0 | Google Maps |
| geolocator | ^13.0.0 | GPS location |
| permission_handler | ^11.3.1 | Location permissions |

### Native Android (registered in MainActivity.kt)

| Artifact | Version | หน้าที่ |
|----------|---------|--------|
| `com.adobe.marketing.mobile:places` | 3.0.2 | AEP Places SDK |
| `com.adobe.marketing.mobile:assurance` | 3.0.1 | AEP Assurance |
| `com.adobe.marketing.mobile:edge` | 3.0.0 | AEP Edge Network |
| `com.adobe.marketing.mobile:edgeidentity` | 3.0.0 | Edge Identity |
| `com.google.android.gms:play-services-location` | 21.0.1 | Geofence Builder |

---

## AEP SDK Initialization Order

```kotlin
// MainActivity.onCreate — native extensions ต้อง configure ก่อน
MobileCore.registerExtensions([Places, Assurance, Edge, EdgeIdentity]) {
    MobileCore.configureWithAppID(BuildConfig.ADOBE_APP_ID)  // อยู่ใน callback
}
```

```dart
// main.dart — Dart extensions
await MobileCore.initializeWithAppId(appId: AppConfig.adobeAppId)
// registers: Identity, Lifecycle, Signal, Configuration
```

> ⚠️ `configureWithAppID` ต้องเรียกใน callback ของ `registerExtensions` เพื่อให้ Assurance อ่าน OrgId ได้ทันที

---

## Known Issues & Solutions

ดู [`build_issues.md`](build_issues.md) สำหรับรายละเอียดปัญหาทั้ง 11 ข้อที่พบและวิธีแก้ไขระหว่างการพัฒนา
