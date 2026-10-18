import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

/// Onboarding step 1: explains where the data lives and offers the app
/// lock.
///
/// "Continue" creates the database key in [DeviceKeyStore] (removing any
/// half-created database and key material from an earlier attempt or an
/// older version) and opens the session. When a database exists that the
/// stored device key opens (the onboarding flag was lost, not the data),
/// nothing is deleted: the session opens on it and onboarding is finished
/// at once. Turning the app lock on asks for the fingerprint/face or
/// device PIN once, so the user knows it works.
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
    var keptExisting = false;
    try {
      final session = ref.read(sessionProvider.notifier);
      await session.close();
      final keyStore = ref.read(deviceKeyStoreProvider);
      final existing = await _existingDataKey(keyStore);
      if (existing != null) {
        // Real data from before: the onboarding flag was lost, not the
        // database. One tap must not destroy it.
        Logger.warning(
          'Onboarding found an existing database that the device key '
          'opens; keeping it',
        );
        session.open(existing);
        zeroBytes(existing);
        keptExisting = true;
      } else {
        // A database left by an abandoned earlier onboarding is keyed with
        // a key that no longer exists.
        await deleteDatabaseFiles();
        await ref.read(legacyKeyMigrationProvider).deleteLeftovers();
        final dek = await keyStore.create();
        session.open(dek);
        zeroBytes(dek);
      }
      await ref.read(appLockEnabledProvider.notifier).set(_useAppLock);
      if (keptExisting) {
        ref.read(authProvider.notifier).setOnboarded(true);
      }
      ref.read(authProvider.notifier).setAuthenticated(true);
    } catch (e, stackTrace) {
      Logger.error('Onboarding key setup failed', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.setupFailed)),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    if (keptExisting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.setupExistingDataKept)),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (keptExisting) {
        context.go('/');
      } else {
        context.goNamed('first-account');
      }
    });
  }

  /// The stored device key when a database file exists and opens with it;
  /// `null` when there is no data to keep (or no key).
  static Future<Uint8List?> _existingDataKey(DeviceKeyStore keyStore) async {
    final file = await databaseFile();
    if (!file.existsSync()) {
      return null;
    }
    final Uint8List? dek;
    try {
      dek = await keyStore.read();
    } catch (e, stackTrace) {
      Logger.warning('Onboarding could not read the device key', e, stackTrace);
      return null;
    }
    if (dek == null) {
      return null;
    }
    try {
      if (SqlCipher.canOpen(file, RawSqlCipherKey(dek))) {
        return dek;
      }
    } catch (e, stackTrace) {
      Logger.warning('Onboarding could not check the database', e, stackTrace);
    }
    zeroBytes(dek);
    return null;
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
