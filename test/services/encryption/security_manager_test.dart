import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';

void main() {
  group('SecurityManager', () {
    late SecurityManager securityManager;

    setUp(() {
      securityManager = SecurityManager();
    });

    test('generateSecureKey returns a valid base64 encoded string', () {
      final key = securityManager.generateSecureKey();
      expect(key, isNotEmpty);

      // Attempt to decode to verify it's valid base64
      final bytes = base64Url.decode(key);
      expect(bytes, isNotEmpty);
    });

    test('generateSecureKey returns a 32-byte key (256 bits)', () {
      final key = securityManager.generateSecureKey();
      final bytes = base64Url.decode(key);
      expect(bytes.length, 32);
    });

    test('generateSecureKey generates unique keys', () {
      final key1 = securityManager.generateSecureKey();
      final key2 = securityManager.generateSecureKey();
      expect(key1, isNot(equals(key2)));
    });
  });
}
