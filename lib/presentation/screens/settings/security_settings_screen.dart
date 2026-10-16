import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/privacy_settings_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/security/biometrics_controller.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentDuration = ref.watch(autoLockDurationProvider);
    final biometricsState = ref.watch(biometricsProvider);
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
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(l10n.recoveryKey),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/security/recovery-key'),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: Text(l10n.autoLock),
                subtitle: Text(getDurationLabel(currentDuration)),
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
                onTap: () => ref.read(sessionProvider.notifier).lock(),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: Text(l10n.changePassword),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/security/change-password'),
              ),
              biometricsState.when(
                data: (state) => SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(l10n.biometrics),
                  subtitle: Text(l10n.useBiometricsDescription),
                  value: state.isEnabled,
                  onChanged: state.isAvailable
                      ? (value) async {
                          final success = await ref
                              .read(biometricsProvider.notifier)
                              .toggleBiometrics(
                                value,
                                BiometricPromptTexts(
                                  title: l10n.biometricPromptEnableTitle,
                                  subtitle: l10n.biometricPromptSubtitle,
                                  cancel: l10n.cancel,
                                ),
                              );
                          if (!success && value && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.biometricsSetupFailed),
                              ),
                            );
                          }
                        }
                      : null,
                ),
                loading: () => ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: Text(l10n.loading),
                ),
                error: (_, _) => const SizedBox.shrink(),
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
