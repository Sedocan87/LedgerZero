import 'dart:convert';
import 'dart:math';

class SecurityManager {
  /// Generates a cryptographically secure random key.
  ///
  /// The key is 256 bits (32 bytes) long and is returned as a Base64 encoded string.
  /// This is suitable for use as an SQLCipher encryption key (AES-256).
  String generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
