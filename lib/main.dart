import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/services/database_service.dart';
import 'core/services/sms_service.dart';
import 'core/services/network_host_service.dart';
import 'desktop/screens/main_dashboard.dart';
import 'mobile/screens/sync_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database
  await DatabaseService().init();
  
  // Initialize SMS Sensor (Android)
  if (Platform.isAndroid) {
    await SmsService().init();
  }
  
  // Start Sync Server (Windows Flutter build only; do not crash if port is busy)
  if (Platform.isWindows) {
    try {
      await NetworkHostService().startServer();
    } catch (e, st) {
      debugPrint('NetworkHostService failed to start: $e');
      debugPrint('$st');
    }
  }
  
  runApp(const VaultIntegrityApp());
}

class VaultIntegrityApp extends StatelessWidget {
  const VaultIntegrityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Integrity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Platform.isWindows ? const MainDashboard() : const SyncScreen(),
    );
  }
}
