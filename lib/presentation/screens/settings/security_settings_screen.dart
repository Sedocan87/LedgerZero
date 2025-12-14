import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/security/biometrics_controller.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_section.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentDuration = ref.watch(autoLockDurationProvider);
    final biometricsState = ref.watch(biometricsProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.secure), // "Secure" or "Security Settings"
      ),
      body: ListView(
        children: [
          SettingsSection(
            title: l10n.securitySettings,
            children: [
              FutureBuilder<bool>(
                future: ref.watch(databaseProvider).isEncrypted,
                builder: (context, snapshot) {
                  final isEncrypted = snapshot.data ?? false;
                  return ListTile(
                    leading: Icon(
                      isEncrypted ? Icons.lock : Icons.lock_open,
                      color: isEncrypted ? Colors.green : Colors.red,
                    ),
                    title: Text(l10n.encryptionStatus),
                    subtitle: Text(
                      isEncrypted ? l10n.encrypted : l10n.notEncrypted,
                    ),
                  );
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.security),
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
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l10n.changePassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/settings/security/change-password'),
                ),
              if (!kIsWeb)
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
                                .toggleBiometrics(value);
                            if (!success && value) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.biometricsSetupFailed),
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                  ),
                  loading: () => ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: Text(l10n.loading),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
