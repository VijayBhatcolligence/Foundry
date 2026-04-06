import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Local HTTP server that serves React module bundles from Flutter assets.
///
/// Uses shelf to serve static files from assets/modules/{moduleId}/
/// so the WebView can load them from http://localhost:{port}/{moduleId}/
///
/// Key features (from POC — proven in production):
/// - Auto-finds free port starting from 8080
/// - CORS headers on every response (required for WebView fetch calls)
/// - Proper content-type mapping for JS, CSS, HTML, fonts
/// - Comprehensive logging for debugging
class LocalHttpServer {
  static final LocalHttpServer instance = LocalHttpServer._();
  LocalHttpServer._();

  HttpServer? _server;
  int? _port;
  bool _isRunning = false;
  Directory? _appDocDir;

  int? get port => _port;
  bool get isRunning => _isRunning;
  String? get baseUrl =>
      _isRunning && _port != null ? 'http://localhost:$_port' : null;

  /// Start the HTTP server.
  /// Finds a free port starting from [startPort] (default 8080).
  /// Returns port number on success, null on failure.
  Future<int?> start({int startPort = 8080}) async {
    if (_isRunning) {
      print('[LocalHttpServer] Already running on port $_port');
      return _port;
    }

    print('[LocalHttpServer] Starting... searching for free port from $startPort');

    // Cache app doc dir once — used for filesystem-first module serving
    try {
      _appDocDir = await getApplicationDocumentsDirectory();
    } catch (e) {
      print('[LocalHttpServer] WARNING: Could not get app doc dir: $e');
    }

    try {
      final freePort = await _findFreePort(startPort);
      if (freePort == null) {
        print('[LocalHttpServer] ERROR: No free port found in range $startPort-${startPort + 100}');
        return null;
      }

      final handler = Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_loggingMiddleware())
          .addHandler(_assetHandler);

      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        freePort,
      );

      _port = freePort;
      _isRunning = true;

      print('[LocalHttpServer] started on port $_port');
      print('[LocalHttpServer] Base URL: http://localhost:$_port');
      return freePort;
    } catch (e) {
      print('[LocalHttpServer] ERROR: Failed to start: $e');
      return null;
    }
  }

  /// Stop the server and free the port.
  Future<void> stop() async {
    if (!_isRunning || _server == null) return;

    await _server!.close(force: true);
    _server = null;
    _port = null;
    _isRunning = false;
    print('[LocalHttpServer] Stopped');
  }

  /// Try ports sequentially until one is free.
  Future<int?> _findFreePort(int startPort) async {
    for (int p = startPort; p < startPort + 100; p++) {
      try {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, p);
        await s.close();
        return p;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// CORS middleware — required so WebView JS can fetch() relative URLs.
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Map<String, String> _corsHeaders() => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '86400',
      };

  /// Logging middleware — prints every request/response for debugging.
  Middleware _loggingMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final start = DateTime.now();
        final response = await handler(request);
        final ms = DateTime.now().difference(start).inMilliseconds;
        print('[LocalHttpServer] ${response.statusCode} ${request.method} '
            '${request.url.path} (${ms}ms)');
        return response;
      };
    };
  }

  /// Main handler — serves files from assets/modules/{moduleId}/{file}
  Future<Response> _assetHandler(Request request) async {
    final urlPath = request.url.path;

    // Root → index listing
    if (urlPath.isEmpty || urlPath == '/') {
      return Response.ok(
        '<html><body><h2>Foundry Module Server running on port $_port</h2></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    }

    // Ignore browser auto-requests
    if (urlPath == 'favicon.ico') return Response.notFound('');

    // Parse: /{moduleId}/{file}
    final segments = urlPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return Response.notFound('Not found');

    final moduleId = segments[0];
    final filePath = segments.skip(1).join('/');
    final targetFile = filePath.isEmpty ? 'index.html' : filePath;
    final assetPath = 'assets/modules/$moduleId/$targetFile';

    // Filesystem cache-first: check downloaded module before APK asset
    if (_appDocDir != null) {
      try {
        final fsPath = path.join(_appDocDir!.path, 'modules', moduleId, targetFile);
        final fsFile = File(fsPath);
        if (fsFile.existsSync()) {
          final content = await fsFile.readAsBytes();
          print('[LocalHttpServer] serving from cache: $fsPath');
          return Response.ok(
            content,
            headers: {
              'Content-Type': _contentType(targetFile),
              'Cache-Control': 'no-cache',
            },
          );
        }
      } catch (e) {
        print('[LocalHttpServer] cache read error (falling back to asset): $e');
      }
    }

    try {
      final bytes = await rootBundle.load(assetPath);
      final content = bytes.buffer.asUint8List();
      return Response.ok(
        content,
        headers: {
          'Content-Type': _contentType(targetFile),
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      print('[LocalHttpServer] 404 asset not found: $assetPath');
      return Response.notFound('Asset not found: $assetPath');
    }
  }

  String _contentType(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.html': return 'text/html; charset=utf-8';
      case '.js':   return 'application/javascript; charset=utf-8';
      case '.json': return 'application/json; charset=utf-8';
      case '.css':  return 'text/css; charset=utf-8';
      case '.png':  return 'image/png';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.svg':  return 'image/svg+xml';
      case '.woff': return 'font/woff';
      case '.woff2':return 'font/woff2';
      case '.ttf':  return 'font/ttf';
      default:      return 'application/octet-stream';
    }
  }
}
