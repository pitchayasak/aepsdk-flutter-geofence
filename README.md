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
| 🔵 Edge | ส่ง XDM events ไปยัง Adobe Edge Network พร้อม identity ครบ |
| 🛡️ Assurance | Debug AEP events แบบ real-time |

---

## Data Flow

```
POI Entry/Exit (กด ENTRY/EXIT หรือ auto-detect)
  ├── Places.processGeofence     → Adobe Places backend
  ├── MobileCore.trackAction     → Analytics (พร้อม identity context data)
  └── Edge.sendEvent (XDM)       → Adobe Edge Network
      identityMap: Email ✓ lumaCRMId ✓ CIF ✓ ECID ✓

Identity Sync (กด Sync All)
  ├── Identity.syncIdentifiers   → AEP Core Identity
  ├── EdgeIdentity.updateIdentities → Edge Identity (persists for future events)
  └── EdgeService cache          → inject identityMap ใน XDM ทุก event

Custom Tracking
  ├── MobileCore.trackAction     → Analytics
  └── Edge.sendEvent (XDM)       → Adobe Edge Network
```

---

## XDM Event ที่ส่งเมื่อ POI Entry/Exit

```json
{
  "eventType": "location.entry",
  "placeContext": {
    "POIinteraction": {
      "poiEntries": {"value": 1},
      "poiExits":   {"value": 0},
      "poiDetail":  {"name": "...", "poiID": "..."}
    }
  },
  "identityMap": {
    "Email":     [{"id": "...", "authenticatedState": "authenticated", "primary": true}],
    "lumaCRMId": [{"id": "...", "authenticatedState": "authenticated"}],
    "CIF":       [{"id": "...", "authenticatedState": "authenticated"}],
    "ECID":      [{"id": "...", "authenticatedState": "ambiguous"}]
  },
  "_data": {"poi": {"latitude": ..., "longitude": ..., "radius": ...}}
}
```

---

## การตั้งค่าก่อนรัน

### 1. Google Maps API Key

1. ไปที่ [Google Cloud Console](https://console.cloud.google.com)
2. **APIs & Services → Credentials → Create Credentials → API key**
3. **APIs & Services → Library** → เปิดใช้ **Maps SDK for Android**

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

### 2. Adobe App ID + Default Identity

**หา App ID:**
1. ไปที่ [Adobe Experience Platform Data Collection](https://experience.adobe.com/#/data-collection)
2. เลือก **Mobile Property** → **Environments** → คัดลอก **App ID**

**Extensions ที่ต้องติดตั้งใน Mobile Property:**
- Mobile Core, Places, Edge Network, Edge Identity, (Assurance)

```bash
cp lib/config.example.dart lib/config.dart
```

แก้ไข `lib/config.dart`:
```dart
class AppConfig {
  static const String adobeAppId    = 'YOUR_APP_ID_HERE';
  static const String defaultEmail  = 'user@example.com';
  static const String defaultLumaCRMId = 'YOUR_CRM_ID';
  static const String defaultCIF    = 'YOUR_CIF';
}
```

> `lib/config.dart` อยู่ใน `.gitignore` — ไม่ถูก commit  
> Identity ใน `config.dart` จะถูก set อัตโนมัติตอนเปิด app

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

> กดค้างบนแผนที่จะ set GPS ของ emulator ไปที่จุดนั้นทันที

---

## วิธีรัน

```bash
flutter run                       # รันบน emulator
flutter run -d emulator-5554      # ระบุ device
flutter build apk --debug         # สร้าง APK
```

---

## วิธีใช้งาน

### Geofence (หน้าหลัก)

1. เปิด app — แผนที่เริ่มต้นที่ **Lotus Bangkapi, Bangkok**
2. กด **GET NEARBY POIs** — ดึง POI จาก Adobe Places
3. ถ้าไม่มี POI → กดปุ่ม **🟢 +** เพื่อเพิ่ม POI เองสำหรับทดสอบ
4. **กดค้างบนแผนที่** → วาง test location + GPS emulator ย้ายไปด้วย
5. test location เข้าใน radius POI → dialog + ส่ง event 3 ช่องทางอัตโนมัติ
6. กด marker → Bottom Sheet → กด **ENTRY / EXIT** เพื่อส่ง event โดยตรง

### Identity & Tracking (ไอคอน 👤)

| Tab | หน้าที่ |
|-----|--------|
| **Identity** | Sync email, lumaCRMId, CIF, custom (Core + Edge Identity) |
| **Track** | trackAction / trackState + JSON context data |
| **Profile** | Set/Get/Remove user attributes |
| **PII** | Collect PII (ชื่อ, email, เบอร์) |
| **Edge** | ส่ง XDM events ไป Adobe Edge Network โดยตรง |

> Identity ถูก set อัตโนมัติจาก `config.dart` ตอนเปิด app  
> กด **Sync All** เพื่ออัปเดต identity ใหม่

### AEP Assurance (ไอคอน 🛡️)

1. **AEP → Assurance → Create Session → Copy Link** (`griffon://...`)
2. ใน app กดไอคอน 🛡️ → วาง URL → **Connect**
3. รอ ~5 วินาทีหลัง app เปิดก่อน Connect (startup timeout)
4. ต้อง exclude `connect.griffon.adobe.com` จาก Norton SSL inspection

---

## โครงสร้าง Project

```
lib/
├── main.dart                        # Init SDK + set default identities
├── config.dart                      # API keys + identities (gitignored)
├── config.example.dart              # Template
├── models/poi_model.dart
├── screens/
│   ├── geofence_map_screen.dart     # หน้าหลัก (แผนที่ + POI)
│   └── identity_screen.dart         # Identity & Tracking (5 tabs)
├── services/
│   ├── aep_places_channel.dart      # Flutter ↔ Android MethodChannel
│   ├── edge_service.dart            # XDM event builder + identity cache
│   └── places_service.dart          # Places + trackAction + Edge wrapper
└── widgets/
    ├── add_poi_dialog.dart
    └── poi_bottom_sheet.dart

android/
├── secrets.properties               # Keys (gitignored)
├── secrets.properties.example
└── app/src/main/kotlin/.../
    └── MainActivity.kt              # Places + Assurance + Edge + EdgeIdentity
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
| flutter_aepedgeidentity | ^5.0.0 | Edge Identity (authenticated state) |
| google_maps_flutter | ^2.9.0 | Google Maps |
| geolocator | ^13.0.0 | GPS |
| permission_handler | ^11.3.1 | Permissions |

### Native Android

| Artifact | Version | หน้าที่ |
|----------|---------|--------|
| `com.adobe.marketing.mobile:places` | 3.0.2 | AEP Places |
| `com.adobe.marketing.mobile:assurance` | 3.0.1 | AEP Assurance |
| `com.adobe.marketing.mobile:edge` | 3.0.0 | AEP Edge |
| `com.adobe.marketing.mobile:edgeidentity` | 3.0.0 | Edge Identity |
| `com.google.android.gms:play-services-location` | 21.0.1 | Geofence Builder |

---

## AEP SDK Initialization Order

```kotlin
// MainActivity.onCreate (runs first)
MobileCore.registerExtensions([Places, Assurance, Edge, EdgeIdentity]) {
    MobileCore.configureWithAppID(BuildConfig.ADOBE_APP_ID)
}
```

```dart
// main.dart (runs after Flutter engine ready)
await MobileCore.initializeWithAppId(appId: AppConfig.adobeAppId)
// registers: Identity, Lifecycle, Signal

await EdgeService.updateEdgeIdentities(email: ..., lumaCRMId: ..., cif: ...)
// pre-populate identity cache → all Edge events include identities immediately
```

> ⚠️ `configureWithAppID` ต้องอยู่ใน callback ของ `registerExtensions`  
> เพื่อให้ Assurance อ่าน OrgId ได้ก่อน session start

---

## Known Issues & Solutions

ดู [`build_issues.md`](build_issues.md) สำหรับรายละเอียดปัญหาทั้ง 16 ข้อที่พบระหว่างการพัฒนา
