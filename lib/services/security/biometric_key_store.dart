import 'dart:io';

import 'package:flutter/services.dart';

/// Why a biometric operation did not return a key.
enum BiometricFailure {
  /// The user dismissed the prompt.
  cancelled,

  /// No hardware, nothing enrolled, or no device passcode.
  unavailable,

  /// Biometric enrolment changed, so the hardware key was invalidated and
  /// removed. The user must unlock with the password and enable again.
  invalidated,

  /// No key stored.
  notFound,

  /// Anything else (too many attempts, keystore error).
  failed,
}

class BiometricException implements Exception {
  final BiometricFailure failure;
  final String? detail;
  const BiometricException(this.failure, [this.detail]);

  @override
  String toString() => 'BiometricException(${failure.name})';
}

/// Texts for the system prompt.
class BiometricPromptTexts {
  final String title;
  final String subtitle;
  final String cancel;

  const BiometricPromptTexts({
    required this.title,
    required this.subtitle,
    required this.cancel,
  });

  Map<String, String> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'cancel': cancel,
  };
}

/// Hardware-backed storage for the data key that releases it only after a
/// fresh biometric authentication.
///
/// * Android: an AES-256-GCM key in the Android KeyStore created with
///   `setUserAuthenticationRequired(true)`, per-use authentication
///   (`setUserAuthenticationParameters(0, BIOMETRIC_STRONG)`, or validity
///   -1 below API 30) and `setInvalidatedByBiometricEnrollment(true)`. The
///   data key is encrypted with it through a `BiometricPrompt.CryptoObject`;
///   only the ciphertext is stored.
/// * iOS: a keychain item with access control `biometryCurrentSet` and
///   `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`; every read shows
///   Face ID / Touch ID.
///
/// Native code: android/app/src/main/kotlin/com/ledgerzero/app/
/// BiometricKeyChannel.kt and ios/Runner/AppDelegate.swift.
abstract class BiometricKeyStore {
  Future<bool> isAvailable();
  Future<bool> hasKey();

  /// Stores [secret]. Asks for biometric confirmation first.
  Future<void> store(Uint8List secret, BiometricPromptTexts texts);

  /// Returns the stored secret after a successful biometric prompt.
  Future<Uint8List> read(BiometricPromptTexts texts);

  Future<void> delete();
}

class PlatformBiometricKeyStore implements BiometricKeyStore {
  static const MethodChannel _channel = MethodChannel(
    'com.ledgerzero.app/biometric_key',
  );

  const PlatformBiometricKeyStore();

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<bool> isAvailable() async {
    if (!_supported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> hasKey() async {
    if (!_supported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasKey') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> store(Uint8List secret, BiometricPromptTexts texts) async {
    _requireSupported();
    try {
      await _channel.invokeMethod<void>('store', {
        'secret': secret,
        ...texts.toMap(),
      });
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Uint8List> read(BiometricPromptTexts texts) async {
    _requireSupported();
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'read',
        texts.toMap(),
      );
      if (result == null) {
        throw const BiometricException(BiometricFailure.notFound);
      }
      return result;
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> delete() async {
    if (!_supported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('delete');
    } on PlatformException {
      // Nothing stored.
    } on MissingPluginException {
      // Not available on this platform.
    }
  }

  void _requireSupported() {
    if (!_supported) {
      throw const BiometricException(BiometricFailure.unavailable);
    }
  }

  static BiometricException _map(PlatformException e) {
    final failure = switch (e.code) {
      'cancelled' => BiometricFailure.cancelled,
      'unavailable' => BiometricFailure.unavailable,
      'invalidated' => BiometricFailure.invalidated,
      'not_found' => BiometricFailure.notFound,
      _ => BiometricFailure.failed,
    };
    return BiometricException(failure, e.message);
  }
}
