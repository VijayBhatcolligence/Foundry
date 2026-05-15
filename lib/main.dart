import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env — if missing or malformed, app still launches (API calls
  // will fail gracefully and the user lands on the login screen).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] dotenv.load failed: $e');
  }

  // Init Firebase — GoogleService-Info.plist must be in Xcode bundle resources.
  await Firebase.initializeApp();

  runApp(const FoundryApp());
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
