import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'foundry_jwt';
  static const _userKey = 'foundry_user';

  String get _apiBase => dotenv.env['API_BASE_URL'] ?? '';

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Returns a valid JWT, refreshing via Firebase if the stored token is
  /// expired or expiring within 60 seconds.
  Future<String> getValidToken() async {
    final stored = await getToken();
    if (stored == null) throw Exception('No token stored');

    // Decode JWT payload (middle segment) — base64url → JSON
    final parts = stored.split('.');
    if (parts.length != 3) throw Exception('Malformed token');
    String payload = parts[1];
    // Pad to multiple of 4
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(payload)),
    ) as Map<String, dynamic>;

    final exp = decoded['exp'] as int?;
    if (exp != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      if (expiry.difference(now).inSeconds > 60) {
        // Token is still fresh
        return stored;
      }
    }

    // Token is expired or expiring soon — refresh via Firebase
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      await logout();
      throw Exception('Session expired');
    }

    final firebaseIdToken = await firebaseUser.getIdToken(true);
    if (firebaseIdToken == null) {
      await logout();
      throw Exception('Session expired');
    }

    final response = await http.post(
      Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': firebaseIdToken}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = data['token'] as String;
      await _storage.write(key: _tokenKey, value: newToken);
      return newToken;
    } else {
      await logout();
      throw Exception('Session expired');
    }
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Sign in with email/password → get Firebase ID token → exchange for JWT
  Future<Map<String, dynamic>> login(String email, String password) async {
    // 1. Firebase sign-in
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Get Firebase ID token
    final idToken = await credential.user!.getIdToken();

    // 3. Exchange with backend
    final response = await http.post(
      Uri.parse('$_apiBase/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'firebase_token': idToken}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Login failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;

    // 4. Persist
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));

    return user;
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
