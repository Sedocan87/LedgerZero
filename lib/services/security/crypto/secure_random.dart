import 'dart:math';
import 'dart:typed_data';

final Random _random = Random.secure();

/// Returns [length] bytes from the platform's cryptographically secure
/// random number generator.
Uint8List secureRandomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}

/// Overwrites [bytes] with zeros. Use on key material we own once it is no
/// longer needed. (Copies made by the Dart VM, by Strings or by native
/// libraries cannot be reached from here.)
void zeroBytes(Uint8List? bytes) {
  if (bytes == null) {
    return;
  }
  bytes.fillRange(0, bytes.length, 0);
}

/// Constant-time comparison of two byte arrays.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
