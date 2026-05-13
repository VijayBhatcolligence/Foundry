import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/module_registry_service.dart';
import '../services/module_download_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class LoadingScreen extends StatefulWidget {
  /// Optional token passed directly from LoginScreen after a fresh login.
  /// Avoids a Keychain re-read on iPad where the write may not have
  /// propagated by the time initState fires.
  final String? initialToken;

  const LoadingScreen({super.key, this.initialToken});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _status = 'Loading...';
  double? _downloadProgress;
  String? _signatureError;
  List<ModuleEntry> _registry = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    // Use the token passed from LoginScreen if available (avoids Keychain
    // timing race on iPad); otherwise read from secure storage (app restart).
    String token;
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      token = widget.initialToken!;
    } else {
      try {
        token = await AuthService().getValidToken();
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
    }

    // Sync content
    setState(() => _status = 'Preparing your workspace...');
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
          _status = 'Loading ${entry.name}...';
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
        } on BundleSignatureException catch (e) {
          print('[SECURITY] BundleSignatureException: ${e.slug}@${e.version}');
          setState(() {
            _signatureError = e.slug;
            _status = 'Module integrity check failed';
            _downloadProgress = null;
          });
          return; // stop processing further modules; do not navigate to DashboardScreen
        }
      }

      setState(() { _downloadProgress = null; });
    } catch (e) {
      if (e is BundleSignatureException) rethrow;
      print('[LoadingScreen] OTA check failed (continuing): $e');
      setState(() { _downloadProgress = null; });
    }

    // Navigate to ShellScreen with registry (or fallback from cache)
    if (!mounted) return;
    if (_signatureError != null) return;

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
              signature: '',
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_signatureError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Module integrity check failed',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Module: $_signatureError',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
                'Loading content... ${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
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
