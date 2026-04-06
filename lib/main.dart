import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (API_BASE_URL etc.)
  await dotenv.load(fileName: '.env');

  // Init Firebase (google-services.json already in android/app/)
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
