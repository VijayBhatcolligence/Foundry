import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ModuleEntry {
  final String slug;
  final String name;
  final String version;
  final String cdnUrl;
  final String indexUrl;
  final String checksum;

  ModuleEntry({
    required this.slug,
    required this.name,
    required this.version,
    required this.cdnUrl,
    required this.indexUrl,
    required this.checksum,
  });

  factory ModuleEntry.fromJson(Map<String, dynamic> j) => ModuleEntry(
        slug: j['slug'] as String,
        name: j['name'] as String,
        version: j['version'] as String,
        cdnUrl: j['cdn_url'] as String,
        indexUrl: j['index_url'] as String,
        checksum: j['checksum'] as String,
      );
}

class ModuleRegistryService {
  static String get _apiBase => dotenv.env['API_BASE_URL'] ?? '';
  static const _cacheFileName = 'modules_cache.json';

  /// Fetch active module list from backend. Requires valid JWT.
  static Future<List<ModuleEntry>> fetchRegistry(String token) async {
    final uri = Uri.parse('$_apiBase/api/modules');
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Registry fetch failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['modules'] as List<dynamic>;
    return list.map((e) => ModuleEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Read local version cache. Returns empty map if no cache file yet.
  static Future<Map<String, String>> loadLocalCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, _cacheFileName));
      if (!file.existsSync()) return {};
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, (v as Map)['version'] as String));
    } catch (e) {
      print('[Registry] Error reading cache: $e');
      return {};
    }
  }

  /// Returns modules whose remote version differs from cached version.
  static List<ModuleEntry> getOutdatedModules(
    List<ModuleEntry> remote,
    Map<String, String> cache,
  ) {
    return remote.where((m) {
      final cached = cache[m.slug];
      if (cached == null) {
        print('[Registry] ${m.slug} not cached — needs download');
        return true;
      }
      if (cached != m.version) {
        print('[Registry] ${m.slug} outdated ($cached → ${m.version})');
        return true;
      }
      print('[Registry] ${m.slug} up to date (${m.version})');
      return false;
    }).toList();
  }

  /// Update modules_cache.json after a successful download.
  static Future<void> updateCacheEntry(
    String slug,
    String version,
    String dirPath,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, _cacheFileName));

      Map<String, dynamic> cache = {};
      if (file.existsSync()) {
        cache = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }

      cache[slug] = {
        'version': version,
        'cached_at': DateTime.now().toIso8601String(),
        'path': dirPath,
      };

      file.writeAsStringSync(jsonEncode(cache));
      print('[Registry] cache updated: $slug @ $version');
    } catch (e) {
      print('[Registry] Error updating cache: $e');
    }
  }

  /// Deletes local bundle files and cache entries for any module not in [permittedSlugs].
  /// Only call this when the registry fetch succeeds (online path).
  static Future<List<String>> pruneRevokedModules(List<String> permittedSlugs) async {
    final pruned = <String>[];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File(path.join(dir.path, _cacheFileName));
      if (!cacheFile.existsSync()) return pruned;

      final cache = jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      final revoked = cache.keys.where((slug) => !permittedSlugs.contains(slug)).toList();

      for (final slug in revoked) {
        final moduleDir = Directory(path.join(dir.path, 'modules', slug));
        if (moduleDir.existsSync()) {
          await moduleDir.delete(recursive: true);
          print('[Registry] Pruned revoked module files: $slug');
        } else {
          print('[Registry] Revoked module has no cached files: $slug');
        }
        cache.remove(slug);
        pruned.add(slug);
      }

      if (pruned.isNotEmpty) {
        cacheFile.writeAsStringSync(jsonEncode(cache));
        print('[Registry] Cache updated after pruning ${pruned.length} module(s)');
      }
    } catch (e) {
      print('[Registry] Error during prune: $e');
    }
    return pruned;
  }
}
