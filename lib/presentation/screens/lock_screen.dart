import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/presentation/screens/legacy_unlock_view.dart';
import 'package:ledger_zero/presentation/widgets/security/reset_app_dialog.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

enum _Phase {
  /// Opening the database.
  starting,

  /// Waiting for the fingerprint/face or device PIN.
  locked,

  /// An install from before the device key: unlock once with the master
  /// password.
  legacy,

  /// The database key is missing or does not open the database.
  keyError,

  /// The key store failed to answer (it may work on the next try).
  readError,

  /// Opening the database file threw (I/O; it may work on the next try).
  openError,
}

/// Start-up and the app lock.
///
/// Every start passes through here: the database session is opened with
/// the key from [DeviceKeyStore] (so sync and card capture can run even
/// while the lock is showing), then the app lock asks for the fingerprint,
/// face or device PIN if it is on. After the auto-lock time it is shown
/// over the app (`LockOverlay`); the session stays open.
///
/// The system prompt only opens while the app is in the foreground: a lock
/// that happened on the way to the background asks when the user returns,
/// never over another app or the home screen.
///
/// Failures: a key store or file error is retried ("Retry"); the
/// destructive reset is offered only when the key is missing or does not
/// open the database, or when a transient error has repeated
/// [maxTransientFailures] times or is known to be permanent (the KeyStore
/// wrapping key is gone). A failed prompt keeps the app locked and shows
/// the system's reason; only a removed screen lock turns the lock off.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.starting;
  bool _prompting = false;

  /// Starts in a row that ended in [_Phase.readError] or
  /// [_Phase.openError]; after [maxTransientFailures] (or a key store error
  /// that is known to be permanent) the reset is offered as well.
  int _transientFailures = 0;
  bool _keyStoreLost = false;

  /// The system's reason for the last failed prompt.
  String? _authFailure;

  static const int maxTransientFailures = 3;

  /// The prompt is due but the app is not in the foreground.
  bool _promptOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: when the session is already open (the app
    // lock came back after the auto-lock time) the prompt follows without
    // an await, and it needs the localisations of a built context.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _promptOnResume) {
      _promptOnResume = false;
      unawaited(_authenticate());
    }
  }

  static bool get _inForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    // Unknown only very early at start-up, when the app is being opened.
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> _start() async {
    try {
      if (!ref.read(sessionProvider).isUnlocked) {
        final migration = ref.read(legacyKeyMigrationProvider);
        final Uint8List? dek;
        try {
          dek = await _readKey();
        } catch (e, stackTrace) {
          Logger.error('Reading the database key failed', e, stackTrace);
          _transientFailures++;
          _keyStoreLost = _keyStoreLost || isPermanentKeyStoreError(e);
          _setPhase(_Phase.readError);
          return;
        }
        if (dek == null) {
          _setPhase(
            await migration.isPending() ? _Phase.legacy : _Phase.keyError,
          );
          return;
        }
        final bool opens;
        try {
          opens = await _opensDatabase(dek);
        } catch (e, stackTrace) {
          // The file could not be opened at all (I/O), which says nothing
          // about the key: retryable, not the destructive reset.
          zeroBytes(dek);
          Logger.error('Opening the database file failed', e, stackTrace);
          _transientFailures++;
          _setPhase(_Phase.openError);
          return;
        }
        if (!opens) {
          zeroBytes(dek);
          _setPhase(_Phase.keyError);
          return;
        }
        ref.read(sessionProvider.notifier).open(dek);
        zeroBytes(dek);
        _transientFailures = 0;
        // An interrupted migration may have left the old entries behind.
        unawaited(migration.deleteLeftovers());
      }
      await _passLock();
    } catch (e, stackTrace) {
      Logger.error('Opening the database failed', e, stackTrace);
      _transientFailures++;
      _setPhase(_Phase.openError);
    }
  }

  /// Whether [error] from the key store says the wrapping key is gone for
  /// good (the Android KeyStore was wiped, e.g. by a vendor's screen-lock
  /// change), rather than being busy.
  @visibleForTesting
  static bool isPermanentKeyStoreError(Object error) {
    final text = error.toString();
    return const [
      'BadPaddingException',
      'AEADBadTagException',
      'UnrecoverableKeyException',
      'KeyStoreException',
      'InvalidKeyException',
      'KeyPermanentlyInvalidatedException',
    ].any(text.contains);
  }

  /// The transient error has repeated often enough (or is known to be
  /// permanent) to offer the reset next to "Retry".
  bool get _offerReset =>
      _keyStoreLost || _transientFailures >= maxTransientFailures;

  /// The device key; a failing key store is asked up to three times (it
  /// can fail transiently right after an app update), so a temporary error
  /// is never shown as missing data.
  Future<Uint8List?> _readKey() async {
    final store = ref.read(deviceKeyStoreProvider);
    for (var attempt = 1; ; attempt++) {
      try {
        return await store.read();
      } catch (_) {
        if (attempt == 3) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  void _retry() {
    _setPhase(_Phase.starting);
    unawaited(_start());
  }

  static Future<bool> _opensDatabase(Uint8List dek) async {
    final file = await databaseFile();
    // A missing file is created on first use with this key.
    return !file.existsSync() || SqlCipher.canOpen(file, RawSqlCipherKey(dek));
  }

  /// Unlocks the UI, asking for the app lock first when it is on.
  Future<void> _passLock() async {
    if (!ref.read(appLockEnabledProvider)) {
      _unlockUi();
      return;
    }
    _setPhase(_Phase.locked);
    if (!_inForeground) {
      _promptOnResume = true;
      return;
    }
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_prompting || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final authenticator = ref.read(appLockAuthenticatorProvider);
    setState(() {
      _prompting = true;
      _authFailure = null;
    });
    final result = await ExternalUiGuard.run(
      () => authenticator.authenticate(
        title: l10n.appLockPromptTitle,
        subtitle: l10n.appLockPromptSubtitle,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _prompting = false);
    switch (result) {
      case AppLockResult.success:
        _unlockUi();
      case AppLockResult.unavailable:
        // Reported only when the screen lock was removed in the system
        // settings (which needs the old one): the app lock cannot work,
        // so it is turned off instead of locking the user out.
        await ref.read(appLockEnabledProvider.notifier).set(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.appLockTurnedOffNoScreenLock)),
          );
        }
        _unlockUi();
      case AppLockResult.cancelled:
        break;
      case AppLockResult.failed:
        // Sensor busy, lockout, ...: stay locked and say why.
        setState(() => _authFailure = authenticator.lastFailure ?? '');
    }
  }

  /// At start-up the router then leaves this screen (for a remembered deep
  /// link or Home); later the overlay disappears.
  void _unlockUi() {
    ref.read(authProvider.notifier).setAuthenticated(true);
  }

  /// After the one-time unlock of an older install.
  Future<void> _adoptLegacyKey(Uint8List dek) async {
    try {
      await ref.read(legacyKeyMigrationProvider).adopt(dek);
      ref.read(sessionProvider.notifier).open(dek);
    } finally {
      zeroBytes(dek);
    }
    // Whoever had a master password gets the app lock (when the phone
    // has a screen lock); it can be turned off in Settings.
    final canLock = await ref
        .read(appLockAuthenticatorProvider)
        .canAuthenticate();
    await ref.read(appLockEnabledProvider.notifier).set(canLock);
    _unlockUi();
  }

  Future<void> _resetApp() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ResetAppDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _phase = _Phase.starting);
    try {
      await ref.read(factoryResetServiceProvider).reset();
      if (mounted) {
        // The overlay is outside the router.
        final GoRouter router =
            GoRouter.maybeOf(context) ?? ref.read(routerProvider);
        router.go('/onboarding');
      }
    } catch (e, stackTrace) {
      Logger.error('Factory reset failed', e, stackTrace);
      _setPhase(_Phase.keyError);
    }
  }

  void _setPhase(_Phase phase) {
    if (mounted) {
      setState(() => _phase = phase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: switch (_phase) {
              _Phase.starting => const CircularProgressIndicator(),
              _Phase.locked => _buildLocked(l10n),
              _Phase.legacy => LegacyUnlockView(
                onUnlocked: _adoptLegacyKey,
                onReset: _resetApp,
              ),
              _Phase.keyError => _buildKeyError(l10n),
              _Phase.readError => _buildTransientError(
                l10n,
                _keyStoreLost
                    ? l10n.lockScreenReadErrorPersistent
                    : l10n.lockScreenReadError,
              ),
              _Phase.openError => _buildTransientError(
                l10n,
                l10n.lockScreenOpenError,
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocked(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, size: 64, color: Colors.teal),
        const SizedBox(height: 32),
        Text(
          l10n.lockScreenTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          key: const Key('lock_unlock'),
          onPressed: _prompting ? null : _authenticate,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.fingerprint),
          label: Text(l10n.loginUnlock),
        ),
        if (_authFailure != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.lockScreenAuthFailed(_authFailure!),
            key: const Key('lock_auth_failed'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  /// A failure that may pass: "Retry", and the reset once it keeps
  /// failing (see [_offerReset]).
  Widget _buildTransientError(AppLocalizations l10n, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _retryButton(l10n),
        if (_offerReset) ...[const SizedBox(height: 16), _resetButton(l10n)],
      ],
    );
  }

  Widget _buildKeyError(AppLocalizations l10n) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline, size: 64, color: error),
        const SizedBox(height: 24),
        Text(l10n.lockScreenKeyError, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _retryButton(l10n),
        const SizedBox(height: 16),
        _resetButton(l10n),
      ],
    );
  }

  Widget _retryButton(AppLocalizations l10n) => ElevatedButton(
    key: const Key('lock_retry'),
    onPressed: _retry,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    child: Text(l10n.retry),
  );

  Widget _resetButton(AppLocalizations l10n) => OutlinedButton.icon(
    key: const Key('login_reset_app'),
    onPressed: _resetApp,
    icon: const Icon(Icons.restart_alt),
    label: Text(l10n.loginResetApp),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
