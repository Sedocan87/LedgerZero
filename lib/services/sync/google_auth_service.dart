import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        Logger.info('Signed in as ${account.email}');
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
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      Logger.error('Error signing in silently: $e');
    }
  }
}
