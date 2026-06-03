import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_aepassurance/flutter_aepassurance.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/poi_model.dart';
import '../services/aep_places_channel.dart';
import '../services/places_service.dart';
import '../config.dart';
import '../widgets/add_poi_dialog.dart';
import '../widgets/poi_bottom_sheet.dart';
import 'identity_screen.dart';

class GeofenceMapScreen extends StatefulWidget {
  const GeofenceMapScreen({super.key});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  // เริ่มต้นที่ Lotus Bangkapi จนกว่า GPS จริงจะพร้อม
  Position _currentPosition = Position(
    latitude: 13.7657,
    longitude: 100.6331,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  LatLng? _testLocation; // user-draggable test pin
  List<PoiModel> _pois = [];
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  double _radius = 500;
  final int _poiLimit = 10;
  bool _isLoading = false;

  // tracks which POIs the test location is currently inside
  Set<String> _insidePois = {};

  static const _testMarkerId = MarkerId('__test_location__');

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    // ขอ permission เท่านั้น ไม่ดึง GPS — ปล่อยให้ _currentPosition
    // อยู่ที่ Lotus Bangkapi จนกว่าผู้ใช้จะกด "center on me"
    await Permission.locationWhenInUse.request();
  }

  Future<void> _refreshGpsPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() => _currentPosition = pos);
    } catch (_) {}
  }

  Future<void> _animateToPosition(LatLng target) async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newLatLng(target));
  }

  // ── Zoom ────────────────────────────────────────────────────────────────────

  Future<void> _zoomIn() async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.zoomOut());
  }

  // ── POI fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetchNearbyPois() async {
    setState(() => _isLoading = true);
    final lat = _currentPosition.latitude.toStringAsFixed(5);
    final lng = _currentPosition.longitude.toStringAsFixed(5);
    try {
      final pois = await PlacesService.getNearbyPois(_currentPosition, _poiLimit);
      _buildMapOverlays(pois);
      setState(() {
        _pois = pois;
        _isLoading = false;
      });
      if (pois.isEmpty) {
        _snack('ไม่พบ POI ที่ ($lat, $lng) — ตรวจสอบ Places Library ใน Adobe Launch');
      }
      if (_testLocation != null) _evaluateGeofences(_testLocation!);
    } on PlacesException catch (e) {
      setState(() => _isLoading = false);
      _showPlacesErrorDialog('($lat, $lng)\n\n${e.message}');
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error: $e');
    }
  }

  // ── Map overlays ─────────────────────────────────────────────────────────────

  void _buildMapOverlays(List<PoiModel> pois) {
    final markers = <Marker>{};
    final circles = <Circle>{};
    for (final poi in pois) {
      final latLng = LatLng(poi.latitude, poi.longitude);
      markers.add(Marker(
        markerId: MarkerId(poi.identifier),
        position: latLng,
        infoWindow: InfoWindow(title: poi.name, snippet: 'Tap to view details'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _showPoiDetails(poi),
      ));
      circles.add(Circle(
        circleId: CircleId(poi.identifier),
        center: latLng,
        radius: poi.radius.toDouble(),
        fillColor: Colors.blue.withValues(alpha: 0.15),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ));
    }
    // preserve test location marker if present
    if (_testLocation != null) markers.add(_buildTestMarker(_testLocation!));
    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  Marker _buildTestMarker(LatLng pos) => Marker(
        markerId: _testMarkerId,
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: '📍 Test Location',
          snippet: 'Long-press map to move',
        ),
        zIndexInt: 10,
      );

  // ── Test location ────────────────────────────────────────────────────────────

  void _onMapLongPress(LatLng tapped) {
    _moveTestLocation(tapped);
  }

  void _moveTestLocation(LatLng pos) {
    // ตั้ง mock GPS บน emulator ให้ตรงกับ test location ที่ปัก
    AepPlacesChannel.setMockLocation(pos.latitude, pos.longitude).then((err) {
      if (err != null && mounted) _snack('Mock GPS: $err');
    });

    // อัปเดต _currentPosition ด้วย เพื่อให้ GET NEARBY POIs ค้นหาจากจุดนี้
    _currentPosition = Position(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    final markers = Set<Marker>.from(
      _markers.where((m) => m.markerId != _testMarkerId),
    )..add(_buildTestMarker(pos));

    setState(() {
      _testLocation = pos;
      _markers = markers;
    });
    _animateToPosition(pos);
    _evaluateGeofences(pos);
  }

  void _showSetLocationDialog() {
    final latCtrl = TextEditingController(
      text: _testLocation?.latitude.toStringAsFixed(6) ??
          _currentPosition.latitude.toStringAsFixed(6),
    );
    final lngCtrl = TextEditingController(
      text: _testLocation?.longitude.toStringAsFixed(6) ??
          _currentPosition.longitude.toStringAsFixed(6),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Set Test Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ใส่พิกัดที่ต้องการทดสอบ หรือกดค้างบนแผนที่เพื่อย้าย marker',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: latCtrl,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                prefixIcon: Icon(Icons.north),
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngCtrl,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                prefixIcon: Icon(Icons.east),
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text);
              final lng = double.tryParse(lngCtrl.text);
              if (lat == null || lng == null) {
                _snack('Invalid coordinates');
                return;
              }
              Navigator.pop(ctx);
              _moveTestLocation(LatLng(lat, lng));
            },
            child: const Text('Move Here'),
          ),
        ],
      ),
    );
  }

  // ── Geofence evaluation ──────────────────────────────────────────────────────

  void _evaluateGeofences(LatLng testPos) {
    if (_pois.isEmpty) return;

    final nowInside = <String>{};
    for (final poi in _pois) {
      final dist = _haversineMeters(
        testPos.latitude, testPos.longitude,
        poi.latitude, poi.longitude,
      );
      if (dist <= poi.radius) nowInside.add(poi.identifier);
    }

    final entered = nowInside.difference(_insidePois);
    final exited = _insidePois.difference(nowInside);

    for (final id in entered) {
      final poi = _pois.firstWhere((p) => p.identifier == id);
      _showGeofenceAlert(poi, isEntry: true);
      PlacesService.processEntry(poi);
    }
    for (final id in exited) {
      final poi = _pois.firstWhere((p) => p.identifier == id);
      _showGeofenceAlert(poi, isEntry: false);
      PlacesService.processExit(poi);
    }

    setState(() => _insidePois = nowInside);
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  void _showGeofenceAlert(PoiModel poi, {required bool isEntry}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isEntry ? Colors.green[50] : Colors.orange[50],
        icon: Icon(
          isEntry ? Icons.login : Icons.logout,
          color: isEntry ? Colors.green[700] : Colors.orange[700],
          size: 36,
        ),
        title: Text(
          isEntry ? 'เข้าสู่ POI แล้ว!' : 'ออกจาก POI แล้ว!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isEntry ? Colors.green[800] : Colors.orange[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              poi.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Adobe Places event ถูกส่งแล้ว',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: isEntry ? Colors.green[700] : Colors.orange[700],
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addManualPoi(PoiModel poi) {
    final newPois = [..._pois, poi];
    _buildMapOverlays(newPois);
    setState(() => _pois = newPois);
    if (_testLocation != null) _evaluateGeofences(_testLocation!);
    _snack('เพิ่ม POI "${poi.name}" แล้ว');
  }

  void _showPlacesErrorDialog(String error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Adobe Places Error'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('สามารถเพิ่ม POI เองสำหรับทดสอบ geofence ได้ด้วยปุ่ม + บนแผนที่'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddPoiDialog();
            },
            child: const Text('+ เพิ่ม POI'),
          ),
        ],
      ),
    );
  }

  void _showAddPoiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddPoiDialog(
        defaultLocation: _testLocation ??
            LatLng(_currentPosition.latitude, _currentPosition.longitude),
        onAdd: (poi) {
          Navigator.pop(ctx);
          _addManualPoi(poi);
        },
      ),
    );
  }

  void _showPoiDetails(PoiModel poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PoiBottomSheet(poi: poi),
    );
  }

  void _showAssuranceDialog() {
    final ctrl = TextEditingController();
    bool connecting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.security, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Assurance Session'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'App ID: ${AppConfig.adobeAppId}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Session URL',
                  hintText: 'griffon://?adb_validation_sessionid=...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AEP → Assurance → Create Session\n→ Copy Link → วางที่นี่',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: connecting ? null : () async {
                final url = ctrl.text.trim();
                if (url.isEmpty) return;
                setDialogState(() => connecting = true);
                try {
                  await Assurance.startSession(url);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Assurance connecting... ตรวจสอบใน Adobe Experience Platform'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                } catch (e) {
                  final msg = e.toString();
                  final isAlreadyExists = msg.toLowerCase().contains('already exist') ||
                      msg.toLowerCase().contains('session already');
                  setDialogState(() => connecting = false);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isAlreadyExists
                          ? '✅ Assurance session กำลัง active อยู่แล้ว — ตรวจสอบใน Adobe Experience Platform'
                          : 'Error: $msg'),
                      backgroundColor: isAlreadyExists ? Colors.green[700] : Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: connecting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialTarget = LatLng(_currentPosition.latitude, _currentPosition.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Explorer'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Identity & Tracking',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IdentityScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Assurance',
            onPressed: _showAssuranceDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            circles: _circles,
            onMapCreated: (ctrl) => _mapController.complete(ctrl),
            onLongPress: _onMapLongPress,
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // ── Zoom + Center buttons (right side) ──────────────────────────
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _MapIconButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.my_location,
                  tooltip: 'Center on me',
                  onTap: () async {
                    await _refreshGpsPosition();
                    _animateToPosition(
                      LatLng(_currentPosition.latitude, _currentPosition.longitude),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Set Test Location button (left side) ────────────────────────
          Positioned(
            left: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MapIconButton(
                  icon: Icons.edit_location_alt,
                  tooltip: 'Set test location',
                  color: Colors.indigo[700]!,
                  onTap: _showSetLocationDialog,
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.add_location_alt,
                  tooltip: 'Add POI manually',
                  color: Colors.teal[700]!,
                  onTap: _showAddPoiDialog,
                ),
                if (_testLocation != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📍 Test Location',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_testLocation!.latitude.toStringAsFixed(5)},\n${_testLocation!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        if (_insidePois.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '✅ Inside ${_insidePois.length} POI(s)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom panel ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              radius: _radius,
              isLoading: _isLoading,
              poiCount: _pois.length,
              onRadiusChanged: (v) => setState(() => _radius = v),
              onFetch: _fetchNearbyPois,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable map icon button ───────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final double radius;
  final bool isLoading;
  final int poiCount;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onFetch;

  const _BottomPanel({
    required this.radius,
    required this.isLoading,
    required this.poiCount,
    required this.onRadiusChanged,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 8)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(
                'Radius: ${radius.toInt()} m',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (poiCount > 0) ...[
                const Spacer(),
                Chip(
                  label: Text('$poiCount POIs'),
                  backgroundColor: Colors.indigo[50],
                  labelStyle: TextStyle(color: Colors.indigo[700]),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          Slider(
            value: radius,
            min: 100,
            max: 2000,
            divisions: 19,
            activeColor: Colors.indigo[700],
            onChanged: onRadiusChanged,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onFetch,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.satellite_alt),
              label: const Text('GET NEARBY POIs'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
