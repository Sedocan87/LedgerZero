import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/presentation/widgets/filtered_export_dialog.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // final backupScheduler = ref.watch(backupSchedulerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndRestore)),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.export),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: Text(l10n.exportToCsv),
            subtitle: const Text('Export transactions to CSV'),
            onTap: () async {
              try {
                final transactions = await ref.read(transactionRepositoryProvider).getAllTransactions();
                final payees = await ref.read(payeeRepositoryProvider).getAllPayees();
                final categories = await ref.read(categoryRepositoryProvider).getAllCategories();
                final accounts = await ref.read(accountRepositoryProvider).getAllAccounts();

                await TransactionExportService().exportTransactionsToCsv(
                  transactions: transactions,
                  payeeNames: {for (var p in payees) p.id: p.name},
                  categoryNames: {for (var c in categories) c.id: c.name},
                  accountNames: {for (var a in accounts) a.id: a.name},
                );
              } catch (e) {
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Export Filtered Transactions'),
            subtitle: const Text('Export specific transactions'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const FilteredExportDialog(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Export All Data (JSON)'),
            subtitle: const Text('Full backup in JSON format'),
            onTap: () async {
              try {
                await ref.read(dataPortabilityServiceProvider).exportAllDataToJson();
              } catch (e) {
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
          ),

          const Divider(),
          _buildSectionHeader(context, 'Backup'),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Create Full Backup'),
            subtitle: const Text('Create a full database backup'),
            onTap: () async {
               try {
                 final path = await ref.read(backupServiceProvider).createBackup();
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup created at $path')));
                 }
               } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                 }
               }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Backup'),
            subtitle: const Text('Restore from a backup file'),
            onTap: () {
               // Restore logic involves picking a file, which RestoreService handles usually
               // For now just show a message or implement file picker if RestoreService requires path
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore not fully implemented in UI yet')));
            },
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.settings),
          // We need a FutureBuilder or similar to get current frequency
          // Since BackupScheduler uses SharedPreferences synchronously in setFrequency but usually async for reading?
          // The provider exposes the class. The class methods are async.
          // We should probably have a provider that watches the preference.
          // For now, let's assume we can implement a simple dialog.
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Backup Frequency'),
            subtitle: Text(
              ref
                      .watch(sharedPreferencesProvider)
                      .getString('backup_frequency')
                      ?.toUpperCase() ??
                  'WEEKLY',
            ),
            onTap: () => _showFrequencyDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showFrequencyDialog(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) {
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Backup Frequency'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'daily'),
            child: const Text('Daily'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'weekly'),
            child: const Text('Weekly'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'monthly'),
            child: const Text('Monthly'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'never'),
            child: const Text('Never'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(backupSchedulerProvider).setFrequency(result);
      setState(() {}); // refresh subtitle
    }
  }
}
