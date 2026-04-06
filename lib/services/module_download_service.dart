import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'module_registry_service.dart';

class ChecksumMismatchException implements Exception {
  final String slug;
  ChecksumMismatchException(this.slug);
  @override
  String toString() => 'ChecksumMismatchException: $slug bundle.js checksum failed';
}

class ModuleDownloadService {
  /// Download index.html + bundle.js for [entry], verify checksum, write to filesystem.
  /// Optional [onProgress] callback receives values from 0.0 to 1.0.
  static Future<void> download(
    ModuleEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dirPath = path.join(appDocDir.path, 'modules', entry.slug);

    // Ensure directory exists
    final moduleDir = Directory(dirPath);
    if (!moduleDir.existsSync()) {
      moduleDir.createSync(recursive: true);
    }

    print('[ModuleDownload] Downloading ${entry.slug} ${entry.version}...');

    // 1. Download index.html
    final indexResponse = await http
        .get(Uri.parse(entry.indexUrl))
        .timeout(const Duration(seconds: 60));
    if (indexResponse.statusCode != 200) {
      throw Exception('Failed to download index.html: ${indexResponse.statusCode}');
    }
    File(path.join(dirPath, 'index.html')).writeAsBytesSync(indexResponse.bodyBytes);
    onProgress?.call(0.1);

    // 2. Download bundle.js with progress tracking
    final bundleUri = Uri.parse(entry.cdnUrl);
    final client = http.Client();
    try {
      final request = http.Request('GET', bundleUri);
      final streamedResponse = await client.send(request);

      final totalBytes = streamedResponse.contentLength ?? -1;
      var receivedBytes = 0;
      final chunks = <int>[];

      await for (final chunk in streamedResponse.stream) {
        chunks.addAll(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call((receivedBytes / totalBytes) * 0.9 + 0.1);
        }
      }

      final bundleBytes = Uint8List.fromList(chunks);

      // Verify checksum (skip if not provided)
      if (entry.checksum.isNotEmpty) {
        final digest = sha256.convert(bundleBytes);
        if (digest.toString() != entry.checksum) {
          throw ChecksumMismatchException(entry.slug);
        }
      }

      // Write bundle.js
      final bundleFile = File('${moduleDir.path}/bundle.js');
      await bundleFile.writeAsBytes(bundleBytes);
      onProgress?.call(1.0);
    } finally {
      client.close();
    }

    // 3. Update version cache
    await ModuleRegistryService.updateCacheEntry(entry.slug, entry.version, dirPath);

    print('[ModuleDownload] Downloaded ${entry.slug} ${entry.version} → $dirPath');
  }
}
