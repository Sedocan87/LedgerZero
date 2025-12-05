import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';
import 'package:ledger_zero/presentation/screens/settings/security/biometrics_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

    Widget buildOption(BuildContext context, String label, int value) {
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
        title: Text(l10n.settings),
      ),
      body: ListView(
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
                subtitle:
                    Text(isEncrypted ? l10n.encrypted : l10n.notEncrypted),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.syncSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: Text(l10n.recoveryKey),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/recovery-key'),
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
                await ref.read(autoLockDurationProvider.notifier).setDuration(selected);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/change-password'),
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
                          .toggleBiometrics(value);
                      if (!success && value) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.biometricsSetupFailed)),
                          );
                        }
                      }
                    }
                  : null,
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.fingerprint),
              title: Text('Loading...'),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.importCsv),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/import-csv'),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Import from Mint'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/import-mint'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(l10n.payees),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/payees'),
          ),
          ListTile(
            leading: const Icon(AppIcons.calendar),
            title: Text(l10n.scheduledTransactions),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/scheduled-transactions'),
          ),
        ],
      ),
    );
  }
}
