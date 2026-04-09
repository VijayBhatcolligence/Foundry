import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/module_registry_service.dart';
import '../services/module_download_service.dart';
import 'login_screen.dart';
import 'module_list_screen.dart';
import 'dashboard_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _status = 'Loading...';
  double? _downloadProgress;
  String _currentModuleName = '';
  List<ModuleEntry> _registry = [];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Validate token (auto-refresh if expired)
    String token;
    try {
      token = await AuthService().getValidToken();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // OTA update check
    setState(() => _status = 'Checking for updates...');
    try {
      final registry = await ModuleRegistryService.fetchRegistry(token);
      _registry = registry;
      final pruned = await ModuleRegistryService.pruneRevokedModules(
        registry.map((m) => m.slug).toList(),
      );
      if (pruned.isNotEmpty) {
        print('[LoadingScreen] Removed ${pruned.length} revoked module(s): $pruned');
      }
      final cache = await ModuleRegistryService.loadLocalCache();
      final outdated = ModuleRegistryService.getOutdatedModules(registry, cache);

      for (var moduleIndex = 0; moduleIndex < outdated.length; moduleIndex++) {
        final entry = outdated[moduleIndex];
        if (!mounted) return;
        setState(() {
          _status = 'Updating ${entry.name}...';
          _currentModuleName = entry.name;
        });

        try {
          await ModuleDownloadService.download(
            entry,
            onProgress: (p) {
              setState(() {
                _downloadProgress =
                    (moduleIndex / outdated.length) + (p / outdated.length);
              });
            },
          );
        } on ChecksumMismatchException {
          print('[LoadingScreen] Checksum mismatch for ${entry.slug}, retrying...');
          await ModuleDownloadService.download(
            entry,
            onProgress: (p) {
              setState(() {
                _downloadProgress =
                    (moduleIndex / outdated.length) + (p / outdated.length);
              });
            },
          );
        }
      }

      setState(() { _downloadProgress = null; });
    } catch (e) {
      print('[LoadingScreen] OTA check failed (continuing): $e');
      setState(() { _downloadProgress = null; });
    }

    // Navigate to ShellScreen with registry (or fallback from cache)
    if (!mounted) return;

    List<ModuleEntry> modulesToLoad = _registry.isNotEmpty
        ? _registry
        : _buildFallbackFromCache(await ModuleRegistryService.loadLocalCache());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(modules: modulesToLoad)),
    );
  }

  List<ModuleEntry> _buildFallbackFromCache(Map<String, String> cache) {
    return cache.entries
        .map((e) => ModuleEntry(
              slug: e.key,
              name: e.key,
              version: e.value,
              cdnUrl: '',
              indexUrl: '',
              checksum: '',
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_downloadProgress != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: LinearProgressIndicator(value: _downloadProgress),
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading $_currentModuleName... ${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ] else
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
