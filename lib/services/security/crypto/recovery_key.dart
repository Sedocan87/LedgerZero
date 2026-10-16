import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';

/// A random recovery key: 160 bits, shown to the user as 32 Crockford
/// base32 characters in groups of four (`ABCD-EFGH-...`).
///
/// Typing it back is tolerant: case, spaces and dashes are ignored, and the
/// look-alikes O/I/L are read as 0/1/1.
class RecoveryKey {
  static const int byteLength = 20;
  static const int charLength = 32;
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  final Uint8List bytes;

  RecoveryKey._(this.bytes);

  factory RecoveryKey.generate() =>
      RecoveryKey._(secureRandomBytes(byteLength));

  factory RecoveryKey.fromBytes(Uint8List bytes) {
    if (bytes.length != byteLength) {
      throw ArgumentError('recovery key must be $byteLength bytes');
    }
    return RecoveryKey._(Uint8List.fromList(bytes));
  }

  /// Parses user input. Returns null when it is not a well-formed key.
  static RecoveryKey? tryParse(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toUpperCase().runes) {
      final c = String.fromCharCode(rune);
      if (c == ' ' ||
          c == '-' ||
          c == '_' ||
          c == '\n' ||
          c == '\t' ||
          c == '\r') {
        continue;
      }
      buffer.write(switch (c) {
        'O' => '0',
        'I' || 'L' => '1',
        _ => c,
      });
    }
    final normalized = buffer.toString();
    if (normalized.length != charLength) {
      return null;
    }
    final out = Uint8List(byteLength);
    var acc = 0;
    var bits = 0;
    var index = 0;
    for (final ch in normalized.split('')) {
      final value = _alphabet.indexOf(ch);
      if (value < 0) {
        return null;
      }
      acc = (acc << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out[index++] = (acc >> bits) & 0xff;
        acc &= (1 << bits) - 1;
      }
    }
    return RecoveryKey._(out);
  }

  /// The display form, e.g. `7K3M-...` (8 groups of 4).
  String format() {
    final chars = StringBuffer();
    var acc = 0;
    var bits = 0;
    for (final b in bytes) {
      acc = (acc << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        chars.write(_alphabet[(acc >> bits) & 0x1f]);
      }
      acc &= (1 << bits) - 1;
    }
    final s = chars.toString();
    final groups = <String>[];
    for (var i = 0; i < s.length; i += 4) {
      groups.add(s.substring(i, i + 4));
    }
    return groups.join('-');
  }

  void destroy() => zeroBytes(bytes);
}
