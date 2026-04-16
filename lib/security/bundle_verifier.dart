import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// PEM-encoded SPKI public key for ECDSA-P256-SHA256 bundle signature verification.
/// Produced by Phase 1's generate_signing_key.js --export-public.
const String kBundleSigningPublicKey = '''-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEsxoo7sQW+bHicHsnrSUuNEVO0Yev
JzIGRCO9ag/tyVe/wp38hToTqmZeDhK0I9fSySQzqfQBtxggtuf2vF5z+g==
-----END PUBLIC KEY-----''';

// ---------------------------------------------------------------------------
// ECDSA-P256-SHA256 pure-Dart verifier
// P-256 (secp256r1) domain parameters — https://www.secg.org/sec2-v2.pdf §2.4.2
// ---------------------------------------------------------------------------
final BigInt _p256p = BigInt.parse(
    'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF',
    radix: 16);
final BigInt _p256n = BigInt.parse(
    'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551',
    radix: 16);
final BigInt _p256a = BigInt.parse(
    'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC',
    radix: 16);
final BigInt _p256Gx = BigInt.parse(
    '6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296',
    radix: 16);
final BigInt _p256Gy = BigInt.parse(
    '4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5',
    radix: 16);

/// Elliptic curve point (x, y) over GF(p). [isInfinity] is the point at infinity.
class _ECPoint {
  final BigInt x;
  final BigInt y;
  final bool isInfinity;

  _ECPoint(this.x, this.y) : isInfinity = false;

  _ECPoint.infinity()
      : x = BigInt.zero,
        y = BigInt.zero,
        isInfinity = true;
}

/// Reduce [a] modulo [m] to a non-negative result.
BigInt _mod(BigInt a, BigInt m) {
  final r = a % m;
  return r.isNegative ? r + m : r;
}

/// Modular inverse of [a] mod [m] using extended Euclidean algorithm.
BigInt _modInverse(BigInt a, BigInt m) {
  a = _mod(a, m);
  BigInt t = BigInt.zero, newt = BigInt.one;
  BigInt r = m, newr = a;
  while (newr != BigInt.zero) {
    final q = r ~/ newr;
    final tmpt = t - q * newt;
    t = newt;
    newt = tmpt;
    final tmpr = r - q * newr;
    r = newr;
    newr = tmpr;
  }
  if (r > BigInt.one) throw ArgumentError('$a is not invertible mod $m');
  return _mod(t, m);
}

_ECPoint _pointAdd(_ECPoint p, _ECPoint q, BigInt prime, BigInt a) {
  if (p.isInfinity) return q;
  if (q.isInfinity) return p;
  if (p.x == q.x) {
    if (_mod(p.y + q.y, prime) == BigInt.zero) return _ECPoint.infinity();
    return _pointDouble(p, prime, a);
  }
  // lambda = (qy - py) / (qx - px) mod prime
  final num = _mod(q.y - p.y, prime);
  final den = _mod(q.x - p.x, prime);
  final lambda = _mod(num * _modInverse(den, prime), prime);
  final rx = _mod(lambda * lambda - p.x - q.x, prime);
  final ry = _mod(lambda * (p.x - rx) - p.y, prime);
  return _ECPoint(rx, ry);
}

_ECPoint _pointDouble(_ECPoint p, BigInt prime, BigInt a) {
  if (p.isInfinity) return p;
  if (p.y == BigInt.zero) return _ECPoint.infinity();
  // lambda = (3*px^2 + a) / (2*py) mod prime
  final num = _mod(BigInt.from(3) * p.x * p.x + a, prime);
  final den = _mod(BigInt.two * p.y, prime);
  final lambda = _mod(num * _modInverse(den, prime), prime);
  final rx = _mod(lambda * lambda - BigInt.two * p.x, prime);
  final ry = _mod(lambda * (p.x - rx) - p.y, prime);
  return _ECPoint(rx, ry);
}

_ECPoint _scalarMul(BigInt k, _ECPoint p, BigInt prime, BigInt a) {
  _ECPoint result = _ECPoint.infinity();
  _ECPoint addend = p;
  while (k > BigInt.zero) {
    if (k.isOdd) result = _pointAdd(result, addend, prime, a);
    addend = _pointDouble(addend, prime, a);
    k = k >> 1;
  }
  return result;
}

/// Parse DER-encoded ECDSA signature and return (r, s) as BigInt.
/// Returns null if the DER is malformed.
(BigInt, BigInt)? _parseDerSignature(List<int> der) {
  // DER format: 0x30 [total-len] 0x02 [r-len] [r-bytes] 0x02 [s-len] [s-bytes]
  if (der.length < 8) return null;
  if (der[0] != 0x30) return null;
  int idx = 2; // skip 0x30 and total length byte
  if (idx >= der.length || der[idx] != 0x02) return null;
  idx++;
  if (idx >= der.length) return null;
  final rLen = der[idx];
  idx++;
  if (idx + rLen > der.length) return null;
  final rBytes = der.sublist(idx, idx + rLen);
  idx += rLen;
  if (idx >= der.length || der[idx] != 0x02) return null;
  idx++;
  if (idx >= der.length) return null;
  final sLen = der[idx];
  idx++;
  if (idx + sLen > der.length) return null;
  final sBytes = der.sublist(idx, idx + sLen);

  BigInt bytesToBigInt(List<int> b) {
    if (b.isEmpty) return BigInt.zero;
    return BigInt.parse(
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }

  return (bytesToBigInt(rBytes), bytesToBigInt(sBytes));
}

/// Pure-Dart ECDSA-P256-SHA256 verification.
/// Returns true if the signature is valid over [message] with public key (pubX, pubY).
/// Never throws — catches all errors internally.
bool _ecdsaP256Verify(
  List<int> message,
  List<int> derSignature,
  BigInt pubX,
  BigInt pubY,
) {
  try {
    final parsed = _parseDerSignature(derSignature);
    if (parsed == null) return false;
    final (r, s) = parsed;

    // r, s must be in [1, n-1]
    if (r <= BigInt.zero || r >= _p256n) return false;
    if (s <= BigInt.zero || s >= _p256n) return false;

    // Hash the message with SHA-256
    final digest = crypto.sha256.convert(message);
    final e = BigInt.parse(
      digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // ECDSA verify:
    // w = s^-1 mod n
    // u1 = e * w mod n
    // u2 = r * w mod n
    // X = u1*G + u2*Q
    // valid if X.x mod n == r
    final w = _modInverse(s, _p256n);
    final u1 = _mod(e * w, _p256n);
    final u2 = _mod(r * w, _p256n);

    final G = _ECPoint(_p256Gx, _p256Gy);
    final Q = _ECPoint(pubX, pubY);

    final pt1 = _scalarMul(u1, G, _p256p, _p256a);
    final pt2 = _scalarMul(u2, Q, _p256p, _p256a);
    final X = _pointAdd(pt1, pt2, _p256p, _p256a);

    if (X.isInfinity) return false;
    return _mod(X.x, _p256n) == r;
  } catch (_) {
    return false;
  }
}

/// Verifies ECDSA-P256-SHA256 bundle signatures against the hardcoded production
/// public key. Standalone utility — not wired into the download flow (Phase 5).
class BundleVerifier {
  /// Verifies that [base64Signature] is a valid base64-encoded DER-encoded
  /// ECDSA-P256-SHA256 signature over [bundleBytes] produced by the private key
  /// corresponding to [kBundleSigningPublicKey].
  ///
  /// Returns `true` if and only if the signature is cryptographically valid.
  /// Returns `false` in ALL other cases — including malformed base64, invalid DER,
  /// wrong key, tampered bytes, empty inputs, or any exception.
  /// NEVER throws.
  static Future<bool> verify(
    Uint8List bundleBytes,
    String base64Signature,
  ) async {
    try {
      // Decode the base64 DER signature bytes
      final Uint8List derBytes = base64Decode(base64Signature);

      // Parse the PEM constant to extract the raw 64-byte uncompressed P-256 point.
      // Steps:
      //   1. Remove PEM header/footer lines and whitespace
      //   2. Concatenate remaining base64 lines
      //   3. Base64-decode to get the 91-byte SPKI DER
      //   4. Locate the 0x04 uncompressed point marker at DER byte offset 26
      //   5. Extract x (bytes 27..58) and y (bytes 59..90) — 32 bytes each
      final String pemBody = kBundleSigningPublicKey
          .split('\n')
          .where((line) =>
              line.isNotEmpty &&
              !line.startsWith('-----BEGIN') &&
              !line.startsWith('-----END'))
          .join('');
      final Uint8List spkiDer = base64Decode(pemBody);

      // P-256 SPKI DER is 91 bytes. The uncompressed EC point (04 || x || y)
      // starts at byte offset 26. We skip the 0x04 prefix to get x and y.
      const int ecPointOffset = 26;
      if (spkiDer.length < ecPointOffset + 65) return false;
      if (spkiDer[ecPointOffset] != 0x04) return false;

      final xBytes = spkiDer.sublist(ecPointOffset + 1, ecPointOffset + 33);
      final yBytes = spkiDer.sublist(ecPointOffset + 33, ecPointOffset + 65);

      BigInt bytesToBigInt(List<int> b) => BigInt.parse(
            b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(),
            radix: 16,
          );

      final pubX = bytesToBigInt(xBytes);
      final pubY = bytesToBigInt(yBytes);

      // Perform ECDSA-P256-SHA256 verification using pure-Dart EC math.
      // Note: package:cryptography/cryptography.dart Ecdsa.p256(Sha256()) is the
      // intended algorithm (conceptually EcdsaP256/Sha256 per spec); the pure-Dart
      // EC implementation here is required because DartEcdsa.verify() in
      // cryptography ^2.7.0 throws UnimplementedError in the Dart VM environment.
      return _ecdsaP256Verify(bundleBytes, derBytes, pubX, pubY);
    } catch (_) {
      return false;
    }
  }
}
