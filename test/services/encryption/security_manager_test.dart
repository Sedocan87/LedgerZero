import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'; // Import this for AuthMessages

// Create a new mock for this test
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

class MockLocalAuthentication extends Mock implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics => Future.value(true);

  @override
  Future<bool> isDeviceSupported() => Future.value(true);

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) => Future.value(true);
}

void main() {
  late SecurityManager manager;
  late MockFlutterSecureStorage mockStorage;
  late MockLocalAuthentication mockAuth;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    mockAuth = MockLocalAuthentication();
    manager = SecurityManager(storage: mockStorage, localAuth: mockAuth);
  });

  group('SecurityManager', () {
    test('generateSecureKey returns 32 bytes (base64 encoded)', () {
      final key = manager.generateSecureKey();
      // Base64 of 32 bytes is approx 43-44 chars
      expect(key.length, greaterThanOrEqualTo(40));
    });

    test('deriveKeyFromPassword returns consistent key', () {
      const pass = 'password123';
      const salt = 'salt123';
      final key1 = manager.deriveKeyFromPassword(pass, salt, iterations: 100);
      final key2 = manager.deriveKeyFromPassword(pass, salt, iterations: 100);
      expect(key1, equals(key2));
    });

    test('storeKey and getKey work', () async {
      const key = 'my-secret-key';
      await manager.storeKey(key);
      expect(await manager.getKey(), equals(key));
    });

    test('hasKey returns correct value', () async {
      expect(await manager.hasKey(), isFalse);
      await manager.storeKey('key');
      expect(await manager.hasKey(), isTrue);
    });

    test('clearKey removes key', () async {
      await manager.storeKey('key');
      await manager.clearKey();
      expect(await manager.hasKey(), isFalse);
    });

    test('verifier logic works', () async {
      const key = 'test-key';
      await manager.storeVerifier(key);

      expect(await manager.verifyKey(key), isTrue);
      expect(await manager.verifyKey('wrong-key'), isFalse);
    });

    test('session key management', () {
      SecurityManager.setSessionKey('session-key');
      expect(SecurityManager.sessionKey, 'session-key');
      SecurityManager.setSessionKey(null);
      expect(SecurityManager.sessionKey, null);
    });
  });
}
