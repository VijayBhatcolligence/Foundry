import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_app/security/bundle_verifier.dart';

/// Test fixture: bundle bytes used for all signature tests.
/// Signed offline using the production private key from Phase 1.
final Uint8List kTestBundleBytes = Uint8List.fromList([0x01, 0x02, 0x03]);

/// Valid ECDSA-P256-SHA256 DER signature (base64) over kTestBundleBytes,
/// produced by the Phase 1 production private key (matching kBundleSigningPublicKey).
/// Generated offline via Node.js crypto.createSign('SHA256') with dsaEncoding: 'der'.
const String kValidBase64Signature =
    'MEYCIQDN0FrUtXXYwdlFWxvmGMylMUrtD9VWqzOS3pvWMtt4cgIhAISJ/bfJ3WLDeBTCIsgFojAVBW2aei2ntwzJyUT2q7bV';

/// Valid signature with byte at index 10 flipped (XOR 0xFF).
/// Should NOT verify against kBundleSigningPublicKey.
const String kTamperedBase64Signature =
    'MEYCIQDN0FrUtYrYwdlFWxvmGMylMUrtD9VWqzOS3pvWMtt4cgIhAISJ/bfJ3WLDeBTCIsgFojAVBW2aei2ntwzJyUT2q7bV';

/// ECDSA-P256-SHA256 DER signature (base64) over kTestBundleBytes,
/// produced by a DIFFERENT P-256 private key (not the production key).
/// Should NOT verify against kBundleSigningPublicKey.
const String kWrongKeyBase64Signature =
    'MEYCIQDrUVaUdWVY34zIgZVpJ20o0ok28kAnhcU8eItry9RtSQIhANYtLjbgcgSEXNl3dzm84lXi665wRfqRZseiTTTfhQa4';

void main() {
  // AC-4.4: BundleVerifier.verify returns true for valid signature
  test('BundleVerifier verify returns true for valid signature', () async {
    final result = await BundleVerifier.verify(kTestBundleBytes, kValidBase64Signature);
    expect(result, isTrue);
  });

  // AC-4.5: BundleVerifier.verify returns false for tampered signature
  test('BundleVerifier verify returns false for tampered signature', () async {
    final result = await BundleVerifier.verify(kTestBundleBytes, kTamperedBase64Signature);
    expect(result, isFalse);
  });

  // AC-4.6: BundleVerifier.verify returns false when signature was produced by a different key
  test('BundleVerifier verify returns false for wrong public key', () async {
    final result = await BundleVerifier.verify(kTestBundleBytes, kWrongKeyBase64Signature);
    expect(result, isFalse);
  });

  // AC-4.8: BundleVerifier.verify returns false for empty signature string
  test('BundleVerifier verify returns false for empty signature', () async {
    final result = await BundleVerifier.verify(
      Uint8List.fromList([1, 2, 3]),
      '',
    );
    expect(result, isFalse);
  });

  // AC-4.9: BundleVerifier.verify returns false for non-base64 garbage input
  test('BundleVerifier verify returns false for non-base64 signature', () async {
    final result = await BundleVerifier.verify(
      Uint8List.fromList([1, 2, 3]),
      '!!!not_base64!!!',
    );
    expect(result, isFalse);
  });

  // AC-4.10: BundleVerifier.verify returns false for empty bundle bytes
  test('BundleVerifier verify returns false for empty bundle bytes', () async {
    final result = await BundleVerifier.verify(
      Uint8List(0),
      kValidBase64Signature,
    );
    expect(result, isFalse);
  });
}
