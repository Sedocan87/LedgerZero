import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Onboarding step 1: explains where the data lives and offers the app
/// lock.
///
/// "Continue" opens the database session. When a database with accounts
/// exists (the onboarding flag was lost, not the data), nothing is deleted:
/// the session opens on it and onboarding is finished at once. A database
/// without accounts (an earlier onboarding stopped at the first-account
/// step) is opened and onboarding goes on; a damaged one, or one from an
/// early test version, is replaced. Back from the first-account step, the
/// session this onboarding opened is kept and "Continue" returns to that
/// step. Turning the app lock on asks for the fingerprint/face or device
/// PIN once, so the user knows it works.
class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() =>
      _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  bool _canLock = false;
  bool _useAppLock = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkScreenLock();
  }

  Future<void> _checkScreenLock() async {
    final available = await ref
        .read(appLockAuthenticatorProvider)
        .canAuthenticate();
    if (mounted) {
      setState(() {
        _canLock = available;
        _useAppLock = available;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (!value) {
      setState(() => _useAppLock = false);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final result = await ExternalUiGuard.run(
      () => ref
          .read(appLockAuthenticatorProvider)
          .authenticate(
            title: l10n.appLockPromptTitle,
            subtitle: l10n.appLockPromptSubtitle,
          ),
    );
    if (mounted && result == AppLockResult.success) {
      setState(() => _useAppLock = true);
    }
  }

  Future<void> _continue() async {
    setState(() => _isLoading = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final existingDataKept = AppLocalizations.of(
      context,
    )!.setupExistingDataKept;
    var keptExisting = false;
    final auth = ref.read(authProvider);
    if (!auth.isOnboarded &&
        auth.hasUnlocked &&
        ref.read(sessionProvider).isOpen) {
      // Back here from the first-account step: this onboarding already
      // opened the session. Keep it (the database is not "existing data",
      // and onboarding is not done yet).
      try {
        await ref.read(appLockEnabledProvider.notifier).set(_useAppLock);
      } catch (e, stackTrace) {
        Logger.error('Saving the app lock choice failed', e, stackTrace);
      }
      router.goNamed('first-account');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    try {
      final session = ref.read(sessionProvider.notifier);
      await session.close();
      final file = await databaseFile();
      switch (await checkDatabaseFile(file)) {
        case DatabaseFileState.usable:
          // Real data from before: the onboarding flag was lost, not the
          // database. One tap must not destroy it.
          keptExisting = _hasAccounts(file);
          if (keptExisting) {
            Logger.warning(
              'Onboarding found an existing database with accounts; '
              'keeping it',
            );
          }
        case DatabaseFileState.damaged:
        case DatabaseFileState.tooOld:
          await deleteDatabaseFiles();
        case DatabaseFileState.missing:
          break;
      }
      session.open();
      await ref.read(appLockEnabledProvider.notifier).set(_useAppLock);
      if (keptExisting) {
        ref.read(authProvider.notifier).setOnboarded(true);
      }
      ref.read(authProvider.notifier).setAuthenticated(true);
    } catch (e, stackTrace) {
      Logger.error('Onboarding setup failed', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.setupFailed)),
        );
      }
      return;
    }
    // The router outlives auth changes (it re-runs its redirect instead of
    // being rebuilt), so the next step opens right away: the first account,
    // or Home when the existing data was kept (onboarding is done).
    if (keptExisting) {
      messenger?.showSnackBar(SnackBar(content: Text(existingDataKept)));
      router.go('/');
    } else {
      router.goNamed('first-account');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Whether the database [file] has an account (open accounts or not).
  static bool _hasAccounts(File file) {
    final db = sqlite.sqlite3.open(file.path);
    try {
      return db.select('SELECT 1 FROM accounts LIMIT 1').isNotEmpty;
    } on sqlite.SqliteException {
      return false;
    } finally {
      db.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupProtectTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.setupDeviceHeading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(l10n.setupDeviceExplanation),
              const SizedBox(height: 16),
              Text(
                l10n.dataLossWarning,
                key: const Key('setup_data_loss_warning'),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                key: const Key('setup_app_lock'),
                secondary: const Icon(Icons.fingerprint),
                title: Text(l10n.appLockTitle),
                subtitle: Text(
                  _canLock ? l10n.appLockSubtitle : l10n.appLockNeedsScreenLock,
                ),
                value: _useAppLock,
                onChanged: _canLock && !_isLoading ? _toggleAppLock : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.continueAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
