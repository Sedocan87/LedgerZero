import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

/// The iOS build has no Google client ID (GIDClientID), so Google Sign-In
/// would abort the app. Drive sync is unavailable in such builds.
class GoogleSignInNotConfiguredException implements Exception {
  const GoogleSignInNotConfiguredException();
  @override
  String toString() =>
      'Google Drive is not configured in this iOS build '
      '(GOOGLE_IOS_CLIENT_ID, see docs/GOOGLE_DRIVE_SETUP.md)';
}

class GoogleAuthService {
  static const MethodChannel _platform = MethodChannel(
    'com.ledgerzero.app/platform',
  );
  bool? _configured;

  /// On iOS, whether the build carries a Google client ID. Always true on
  /// other platforms (Android identifies the app by package and signature).
  Future<bool> isConfigured() async {
    if (!Platform.isIOS) {
      return true;
    }
    if (_configured != null) {
      return _configured!;
    }
    try {
      _configured =
          await _platform.invokeMethod<bool>('googleSignInConfigured') ?? false;
    } on PlatformException {
      _configured = false;
    } on MissingPluginException {
      _configured = false;
    }
    return _configured!;
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<GoogleSignInAccount?> signIn() async {
    if (!await isConfigured()) {
      throw const GoogleSignInNotConfiguredException();
    }
    try {
      final account = await ExternalUiGuard.run(_googleSignIn.signIn);
      if (account != null) {
        Logger.info('Signed in to Google');
      }
      return account;
    } catch (e) {
      Logger.error('Error signing in to Google: $e');
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signOut() async {
    try {
      final account = await _googleSignIn.disconnect();
      Logger.info('Signed out from Google');
      return account;
    } catch (e) {
      Logger.error('Error signing out from Google: $e');
      rethrow;
    }
  }

  Future<AuthClient?> getAuthenticatedClient() async {
    if (!await isConfigured()) {
      return null;
    }
    final user = _googleSignIn.currentUser;
    if (user == null) {
      // Try silent sign-in if needed
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        return null;
      }
    }

    try {
      return await _googleSignIn.authenticatedClient();
    } catch (e) {
      Logger.error('Error getting authenticated client: $e');
      rethrow;
    }
  }

  Future<bool> isSignedIn() async {
    return _googleSignIn.currentUser != null;
  }

  Future<void> signInSilently() async {
    if (!await isConfigured()) {
      return;
    }
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      Logger.error('Error signing in silently: $e');
    }
  }
}
