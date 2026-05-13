import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_app/services/module_registry_service.dart';

void main() {
  // Base JSON with all required fields (including signature)
  const Map<String, dynamic> fullJson = {
    'slug': 's',
    'name': 'n',
    'version': '1.0.0',
    'cdn_url': 'https://cdn.example.com/b.js',
    'index_url': 'https://cdn.example.com/index.js',
    'checksum': 'abc123',
    'signature': 'MEYCIQDtest==',
  };

  // Base JSON without the signature key (legacy server / key absent)
  const Map<String, dynamic> noSignatureKeyJson = {
    'slug': 's',
    'name': 'n',
    'version': '1.0.0',
    'cdn_url': 'https://cdn.example.com/b.js',
    'index_url': 'https://cdn.example.com/index.js',
    'checksum': 'abc123',
  };

  // JSON with explicit null value for signature key
  const Map<String, dynamic> nullSignatureJson = {
    'slug': 's',
    'name': 'n',
    'version': '1.0.0',
    'cdn_url': 'https://cdn.example.com/b.js',
    'index_url': 'https://cdn.example.com/index.js',
    'checksum': 'abc123',
    'signature': null,
  };

  // AC-4.2: ModuleEntry.fromJson parses signature field from JSON
  test('ModuleEntry fromJson parses signature', () {
    final entry = ModuleEntry.fromJson(fullJson);
    expect(entry.signature, equals('MEYCIQDtest=='));
    expect(entry.slug, equals('s'));
    expect(entry.name, equals('n'));
    expect(entry.version, equals('1.0.0'));
    expect(entry.cdnUrl, equals('https://cdn.example.com/b.js'));
    expect(entry.indexUrl, equals('https://cdn.example.com/index.js'));
    expect(entry.checksum, equals('abc123'));
  });

  // AC-4.3: ModuleEntry.fromJson sets signature to empty string when key is absent or null
  test('ModuleEntry fromJson missing signature defaults to empty', () {
    // (a) Key absent — legacy server
    final entryNoKey = ModuleEntry.fromJson(noSignatureKeyJson);
    expect(entryNoKey.signature, equals(''));

    // (b) Key present but value is JSON null
    final entryNullValue = ModuleEntry.fromJson(nullSignatureJson);
    expect(entryNullValue.signature, equals(''));
  });

  // Additional: empty string signature value is preserved (not null)
  test('ModuleEntry fromJson preserves empty string signature', () {
    final json = Map<String, dynamic>.from(fullJson);
    json['signature'] = '';
    final entry = ModuleEntry.fromJson(json);
    expect(entry.signature, equals(''));
  });

  // Verify signature field is non-nullable String
  test('ModuleEntry signature field is non-nullable String', () {
    final entry = ModuleEntry.fromJson(fullJson);
    // Static type is String — this test confirms the field is accessible
    // and its type is String (Dart sound null safety)
    final String sig = entry.signature;
    expect(sig, isA<String>());
  });
}
