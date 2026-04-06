import 'package:flutter/material.dart';
import '../services/local_http_server.dart';
import '../services/auth_service.dart';
import '../services/module_registry_service.dart';
import '../webview/module_webview.dart';
import 'login_screen.dart';

class ShellScreen extends StatefulWidget {
  final ModuleEntry module;

  const ShellScreen({Key? key, required this.module}) : super(key: key);

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _httpServer = LocalHttpServer.instance;

  Map<String, dynamic> _authContext = {};
  String _status = 'Starting...';
  bool _error = false;
  bool _serverReady = false;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    // Server kept running — reused across module navigations.
    // Only stopped on logout (see _logout below).
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() => _status = 'Starting local server...');

    // Load auth context (token + user info) to inject into WebView
    final token = await AuthService().getToken();
    final user = await AuthService().getCachedUser();
    if (token != null) {
      _authContext = {
        'token': token,
        'user': user ?? {},
      };
    }

    final port = await _httpServer.start(startPort: 8080);

    if (port == null) {
      setState(() {
        _status = 'ERROR: Could not start local HTTP server';
        _error = true;
      });
      return;
    }

    final base = _httpServer.baseUrl;
    if (base == null) {
      setState(() {
        _status = 'ERROR: Could not determine server base URL';
        _error = true;
      });
      return;
    }

    print('[Shell] Server ready at $base, loading module: ${widget.module.slug}');

    setState(() {
      _baseUrl = base;
      _serverReady = true;
      _status = 'Module loaded';
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();
    _httpServer.stop(); // Stop server on logout — will restart on next login
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.name),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startServer,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_serverReady || _baseUrl == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      );
    }

    final url = '$_baseUrl/${widget.module.slug}/';
    print('[Shell] Loading module: $url');
    return ModuleWebView(url: url, authContext: _authContext);
  }
}
