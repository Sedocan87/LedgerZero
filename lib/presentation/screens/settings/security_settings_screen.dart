import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/privacy_settings_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  /// Turning the app lock on needs a screen lock and one successful prompt,
  /// so nobody locks themselves out with a lock that cannot work.
  Future<void> _setAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(appLockEnabledProvider.notifier);
    if (!enabled) {
      await notifier.set(false);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final authenticator = ref.read(appLockAuthenticatorProvider);
    if (!await authenticator.canAuthenticate()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.appLockNeedsScreenLock)),
      );
      return;
    }
    final result = await ExternalUiGuard.run(
      () => authenticator.authenticate(
        title: l10n.appLockPromptTitle,
        subtitle: l10n.appLockPromptSubtitle,
      ),
    );
    if (result == AppLockResult.success) {
      await notifier.set(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentDuration = ref.watch(autoLockDurationProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final encryption = ref.watch(databaseEncryptionStatusProvider);
    final privacy = ref.watch(privacySettingsProvider);

    String getDurationLabel(int duration) {
      if (duration == 0) {
        return l10n.autoLockImmediate;
      }
      if (duration == -1) {
        return l10n.autoLockNever;
      }
      return l10n.autoLockMinutes(duration);
    }

    Widget buildOption<T>(BuildContext context, String label, T value) {
      return SimpleDialogOption(
        onPressed: () => Navigator.pop(context, value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
    }

    final status = encryption.valueOrNull ?? DatabaseEncryptionStatus.unknown;
    final (statusIcon, statusColor, statusText) = switch (status) {
      DatabaseEncryptionStatus.encrypted => (
        Icons.lock,
        Colors.green,
        l10n.encryptionStatusEncrypted,
      ),
      DatabaseEncryptionStatus.plaintext => (
        Icons.lock_open,
        Colors.red,
        l10n.encryptionStatusPlaintext,
      ),
      DatabaseEncryptionStatus.unknown => (
        Icons.help_outline,
        Colors.grey,
        l10n.encryptionStatusUnknown,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securitySettings)),
      body: ListView(
        children: [
          SettingsSection(
            title: l10n.securitySettings,
            children: [
              ListTile(
                leading: Icon(statusIcon, color: statusColor),
                title: Text(l10n.encryptionStatus),
                subtitle: Text(statusText),
              ),
              SwitchListTile(
                key: const Key('security_app_lock'),
                secondary: const Icon(Icons.fingerprint),
                title: Text(l10n.appLockTitle),
                subtitle: Text(l10n.appLockSubtitle),
                value: appLockEnabled,
                onChanged: (value) => _setAppLock(context, ref, value),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: Text(l10n.autoLock),
                subtitle: Text(getDurationLabel(currentDuration)),
                enabled: appLockEnabled,
                onTap: () async {
                  final selected = await showDialog<int>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(l10n.autoLock),
                      children: [
                        buildOption(context, l10n.autoLockImmediate, 0),
                        buildOption(context, l10n.autoLockMinutes(1), 1),
                        buildOption(context, l10n.autoLockMinutes(5), 5),
                        buildOption(context, l10n.autoLockMinutes(15), 15),
                        buildOption(context, l10n.autoLockMinutes(30), 30),
                        buildOption(context, l10n.autoLockNever, -1),
                      ],
                    ),
                  );

                  if (selected != null) {
                    await ref
                        .read(autoLockDurationProvider.notifier)
                        .setDuration(selected);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_clock),
                title: Text(l10n.lockNow),
                enabled: appLockEnabled,
                onTap: () =>
                    ref.read(authProvider.notifier).setAuthenticated(false),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.privacySection,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_off_outlined),
                title: Text(l10n.notificationAmountsTitle),
                subtitle: Text(l10n.notificationAmountsSubtitle),
                value: privacy.notificationAmounts,
                onChanged: (value) => ref
                    .read(privacySettingsProvider.notifier)
                    .setNotificationAmounts(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.crashReportsTitle),
                subtitle: Text(l10n.crashReportsSubtitle),
                value: privacy.crashReports,
                onChanged: (value) => ref
                    .read(privacySettingsProvider.notifier)
                    .setCrashReports(value),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.diagnosticsTitle),
                subtitle: Text(l10n.diagnosticsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/security/diagnostics'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
