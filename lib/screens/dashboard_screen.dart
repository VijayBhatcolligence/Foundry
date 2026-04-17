// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_http_server.dart';
import '../services/auth_service.dart';
import '../services/module_registry_service.dart';
import '../webview/module_webview.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<ModuleEntry> modules;
  const DashboardScreen({Key? key, required this.modules}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _httpServer = LocalHttpServer.instance;

  // -1 = dashboard visible, 0..n = that module's WebView is on top
  int _selectedIndex = -1;

  Map<String, dynamic> _authContext = {};
  bool _serverReady = false;
  String _serverStatus = 'Initializing...';
  bool _serverError = false;
  String? _baseUrl;

  // User info
  String _userEmail = '';

  // Connectivity
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _startServer();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService().getCachedUser();
    if (user != null && mounted) {
      setState(() {
        _userEmail = (user['email'] as String?) ?? '';
      });
    }
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = results.any((r) => r != ConnectivityResult.none);
        });
      }
    });
    // Check initial state
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isOnline = results.any((r) => r != ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _startServer() async {
    setState(() { _serverStatus = 'Initializing...'; _serverError = false; });

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
      setState(() { _serverStatus = 'ERROR: Could not start local HTTP server'; _serverError = true; });
      return;
    }

    final base = _httpServer.baseUrl;
    if (base == null) {
      setState(() { _serverStatus = 'ERROR: Could not determine server base URL'; _serverError = true; });
      return;
    }

    setState(() { _baseUrl = base; _serverReady = true; });
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
      canPop: _selectedIndex < 0,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedIndex >= 0) _closeModule();
      },
      child: Scaffold(
        backgroundColor: _selectedIndex >= 0
            ? const Color(0xFFF5F6FA)
            : const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: _selectedIndex >= 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to dashboard',
                  onPressed: _closeModule,
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF6C63FF),
                    child: Text(
                      _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
          title: Text(
            _selectedIndex >= 0
                ? widget.modules[_selectedIndex].name
                : 'Foundry',
          ),
          actions: [
            if (_selectedIndex < 0)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                color: const Color(0xFF16213E),
                onSelected: (value) {
                  if (value == 'settings') _openSettings();
                  if (value == 'logout') _logout();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Log Out', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _buildBody() {
    // Server error state
    if (_serverError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_serverStatus, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _startServer, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (!_serverReady || _baseUrl == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(_serverStatus, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // Module WebView mode
    if (_selectedIndex >= 0) {
      return IndexedStack(
        index: _selectedIndex,
        children: widget.modules.map((module) {
          final url = '$_baseUrl/${module.slug}/';
          return ModuleWebView(url: url, authContext: _authContext);
        }).toList(),
      );
    }

    // Dashboard mode
    return _buildDashboard();
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User welcome card
          _buildWelcomeCard(),
          const SizedBox(height: 20),

          // Quick stats row
          _buildStatsRow(),
          const SizedBox(height: 24),

          // Modules section
          const Text(
            'Your Modules',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          if (widget.modules.isEmpty)
            _buildEmptyModules()
          else
            ...widget.modules.asMap().entries.map((e) => _buildModuleCard(e.key, e.value)),

          // Offline banner
          if (!_isOnline) ...[
            const SizedBox(height: 20),
            _buildOfflineBanner(),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4A42D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello${_userEmail.isNotEmpty ? ', $_userEmail' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isOnline ? 'Online — data will sync automatically' : 'Offline — data saved locally',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          icon: Icons.widgets_outlined,
          label: 'Modules',
          value: '${widget.modules.length}',
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          icon: Icons.sync,
          label: 'Status',
          value: _isOnline ? 'Synced' : 'Pending',
        )),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(int index, ModuleEntry module) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openModule(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.widgets_outlined, color: Color(0xFF6C63FF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v${module.version}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyModules() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('No modules available', style: TextStyle(color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're offline — data will sync when connected",
              style: TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
