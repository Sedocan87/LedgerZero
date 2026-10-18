import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ledgerzero.app/app_lock');

  void answerWith(Future<Object?> Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => answerWith(null));

  Future<AppLockResult> authenticate(PlatformAppLockAuthenticator auth) =>
      auth.authenticate(title: 'Unlock', subtitle: null);

  test('a sensor or hardware problem is a failure with its reason, not '
      '"unavailable"', () async {
    answerWith(
      (call) async => throw PlatformException(
        code: 'failed',
        message: 'Fingerprint hardware not available',
      ),
    );
    final auth = PlatformAppLockAuthenticator(isAndroid: true);
    expect(await authenticate(auth), AppLockResult.failed);
    expect(auth.lastFailure, 'Fingerprint hardware not available');
  });

  test('"unavailable" (no screen lock) and "cancelled" are passed on', () async {
    answerWith(
      (call) async => throw PlatformException(code: 'unavailable'),
    );
    expect(
      await authenticate(PlatformAppLockAuthenticator(isAndroid: true)),
      AppLockResult.unavailable,
    );
    answerWith((call) async => throw PlatformException(code: 'cancelled'));
    expect(
      await authenticate(PlatformAppLockAuthenticator(isAndroid: true)),
      AppLockResult.cancelled,
    );
  });

  test('a missing native channel does not unlock', () async {
    answerWith(null);
    final auth = PlatformAppLockAuthenticator(isAndroid: true);
    expect(await authenticate(auth), AppLockResult.failed);
    expect(auth.lastFailure, isNotNull);
  });

  test('success clears the last failure', () async {
    answerWith((call) async => throw PlatformException(code: 'failed'));
    final auth = PlatformAppLockAuthenticator(isAndroid: true);
    await authenticate(auth);
    answerWith((call) async => true);
    expect(await authenticate(auth), AppLockResult.success);
    expect(auth.lastFailure, isNull);
  });
}
