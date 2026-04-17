import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import 'barcode_scanner_screen.dart';

/// Result wrapper for all bridge method responses.
/// Matches the shape React modules expect: { success, data, error }
class BridgeResult {
  final bool success;
  final dynamic data;
  final String? error;

  BridgeResult.ok(this.data)
      : success = true,
        error = null;

  BridgeResult.err(this.error)
      : success = false,
        data = null;

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': data,
        'error': error,
      };
}

/// Flutter ↔ JavaScript bridge for the Foundry shell.
///
/// Phase 1: ping, capturePhoto (stub)
/// Phase 2: getAuthToken
/// Phase 4: capturePhoto (upgraded), getNetworkState, scanBarcode
/// Phase 8: capturePhoto saves to file system + returns filePath; readFile added; submitTransaction removed
class ShellBridge {
  final BuildContext context;
  ShellBridge(this.context);

  Future<Map<String, dynamic>> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    print('[ShellBridge] received: $method args=$args');

    try {
      switch (method) {
        // ── Phase 1 ───────────────────────────────────────────────────
        case 'ping':
          return BridgeResult.ok({'pong': true}).toJson();

        // ── Phase 2 ───────────────────────────────────────────────────
        case 'getAuthToken':
          final token = await AuthService().getValidToken();
          return BridgeResult.ok({'token': token}).toJson();

        // ── Phase 4 / Phase 8 ─────────────────────────────────────────
        case 'capturePhoto':
          final picker = ImagePicker();
          final XFile? photo = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1024,
          );
          if (photo == null) {
            return BridgeResult.ok({'cancelled': true}).toJson();
          }
          // Save to app documents directory for queue persistence
          final directory = await getApplicationDocumentsDirectory();
          final photosDir = Directory('${directory.path}/photos');
          if (!await photosDir.exists()) {
            await photosDir.create(recursive: true);
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final savedPath = '${photosDir.path}/$timestamp.jpg';
          await File(photo.path).copy(savedPath);
          // Read bytes for immediate display in React UI
          final bytes = await File(savedPath).readAsBytes();
          final b64 = base64Encode(bytes);
          return BridgeResult.ok({
            'cancelled': false,
            'dataUrl': 'data:image/jpeg;base64,$b64',
            'filePath': savedPath,
          }).toJson();

        case 'readFile':
          final filePath = args['filePath'] as String?;
          if (filePath == null || filePath.isEmpty) {
            return BridgeResult.err('filePath is required').toJson();
          }
          final file = File(filePath);
          if (!await file.exists()) {
            return BridgeResult.err('File not found: $filePath').toJson();
          }
          final fileBytes = await file.readAsBytes();
          final fileB64 = base64Encode(fileBytes);
          return BridgeResult.ok({
            'dataUrl': 'data:image/jpeg;base64,$fileB64',
          }).toJson();

        case 'getNetworkState':
          final results = await Connectivity().checkConnectivity();
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          String type = 'none';
          if (results.contains(ConnectivityResult.wifi)) {
            type = 'wifi';
          } else if (results.contains(ConnectivityResult.mobile)) {
            type = 'mobile';
          } else if (isOnline) {
            type = 'other';
          }
          return BridgeResult.ok({'isOnline': isOnline, 'type': type}).toJson();

        case 'scanBarcode':
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const BarcodeScannerScreen(),
            ),
          );
          if (result == null) {
            return BridgeResult.ok({'cancelled': true}).toJson();
          }
          return BridgeResult.ok(result).toJson();

        default:
          print('[ShellBridge] unknown method: $method');
          return BridgeResult.err('Unknown method: $method').toJson();
      }
    } catch (e) {
      print('[ShellBridge] ERROR in $method: $e');
      return BridgeResult.err(e.toString()).toJson();
    }
  }
}
