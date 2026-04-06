import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/local_http_server.dart';
import '../services/auth_service.dart';
import '../services/module_registry_service.dart';
import '../webview/module_webview.dart';
import 'login_screen.dart';

class ModuleListScreen extends StatefulWidget {
  final List<ModuleEntry> modules;
  const ModuleListScreen({Key? key, required this.modules}) : super(key: key);

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _httpServer = LocalHttpServer.instance;

  // -1 = module list visible, 0..n = that module's WebView is on top
  int _selectedIndex = -1;

  Map<String, dynamic> _authContext = {};
  bool _serverReady = false;
  String _serverStatus = 'Starting...';
  bool _serverError = false;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    // Server kept alive — stopped only on logout.
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _serverStatus = 'Starting local server...';
      _serverError = false;
    });

    final token = await AuthService().getToken();
    final user = await AuthService().getCachedUser();
    if (token != null) {
      _authContext = {
        'token': token,
        'user': user ?? {},
        'apiBaseUrl': dotenv.env['API_BASE_URL'] ?? '',
      };
    }

    final port = await _httpServer.start(startPort: 8080);
    if (port == null) {
      setState(() {
        _serverStatus = 'ERROR: Could not start local HTTP server';
        _serverError = true;
      });
      return;
    }

    final base = _httpServer.baseUrl;
    if (base == null) {
      setState(() {
        _serverStatus = 'ERROR: Could not determine server base URL';
        _serverError = true;
      });
      return;
    }

    print('[ModuleList] Server ready at $base — ${widget.modules.length} module(s) loaded');

    setState(() {
      _baseUrl = base;
      _serverReady = true;
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();
    _httpServer.stop();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openModule(int index) => setState(() => _selectedIndex = index);
  void _closeModule() => setState(() => _selectedIndex = -1);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept Android back button: go back to list instead of leaving
      canPop: _selectedIndex < 0,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedIndex >= 0) _closeModule();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: _selectedIndex >= 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to modules',
                  onPressed: _closeModule,
                )
              : null,
          title: Text(
            _selectedIndex >= 0
                ? widget.modules[_selectedIndex].name
                : 'Foundry',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _logout,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_serverError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _serverStatus,
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
            Text(_serverStatus),
          ],
        ),
      );
    }

    if (widget.modules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No modules available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // IndexedStack keeps ALL WebViews alive in memory.
    // Switching modules just changes the visible index — no WebView is ever destroyed.
    return Stack(
      children: [
        IndexedStack(
          index: _selectedIndex < 0 ? 0 : _selectedIndex,
          children: widget.modules.map((module) {
            final url = '$_baseUrl/${module.slug}/';
            return ModuleWebView(url: url, authContext: _authContext);
          }).toList(),
        ),
        // Module picker overlay — covers WebViews when no module is selected
        if (_selectedIndex < 0) _buildModuleList(),
      ],
    );
  }

  Widget _buildModuleList() {
    return Container(
      color: const Color(0xFFF5F6FA),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.modules.length,
        itemBuilder: (context, index) {
          final module = widget.modules[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openModule(index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.widgets_outlined,
                        color: Color(0xFF6C63FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1a1a2e),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${module.version}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
