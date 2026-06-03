import 'package:flutter/material.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';

import 'config.dart';
import 'screens/geofence_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initSdks();
  runApp(const MyApp());
}

Future<void> _initSdks() async {
  try {
    await MobileCore.setLogLevel(LogLevel.debug);
    // Places + Assurance registered natively in MainActivity.onCreate
    // initializeWithAppId handles Core extensions (Identity, Lifecycle, Signal)
    await MobileCore.initializeWithAppId(appId: AppConfig.adobeAppId);
  } catch (e) {
    debugPrint('AEP SDK init error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AEP Geofence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const GeofenceMapScreen(),
    );
  }
}
