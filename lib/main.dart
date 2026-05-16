import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'services/auth_service.dart';

bool _firebaseReady = false;

bool get firebaseReady => _firebaseReady;

const _appVersion = '3.0.1';

/// Clears stored session on fresh install or app update.
/// Uses a file in the documents directory (wiped on reinstall, unlike Keychain).
Future<void> _clearSessionIfNewInstallOrUpdate() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final marker = File('${dir.path}/.foundry_version');
    if (marker.existsSync()) {
      final stored = marker.readAsStringSync().trim();
      if (stored == _appVersion) return; // same version, keep session
    }
    // First launch, reinstall, or version change — clear session
    debugPrint('[main] New install or update detected — clearing session');
    await AuthService().logout();
    marker.writeAsStringSync(_appVersion);
  } catch (e) {
    debugPrint('[main] Session check failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] dotenv.load failed: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[main] Firebase.initializeApp: $e');
  }
  _firebaseReady = Firebase.apps.isNotEmpty;

  await _clearSessionIfNewInstallOrUpdate();
  await _clearSessionIfExpired();

  runApp(const FoundryApp());
}

/// Clears session if older than 7 days.
Future<void> _clearSessionIfExpired() async {
  try {
    if (await AuthService().isSessionExpired()) {
      final hasToken = await AuthService().isLoggedIn();
      if (hasToken) {
        debugPrint('[main] Session older than ${AuthService.sessionMaxDays} days — clearing');
        await AuthService().logout();
      }
    }
  } catch (e) {
    debugPrint('[main] Session expiry check failed: $e');
  }
}

class FoundryApp extends StatelessWidget {
  const FoundryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foundry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      // LoadingScreen checks stored JWT → routes to LoginScreen or ShellScreen
      home: const LoadingScreen(),
    );
  }
}
