import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/presentation/widgets/filtered_export_dialog.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final backupScheduler = ref.watch(backupSchedulerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndExport)),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.exportData),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: Text(l10n.exportTransactionsCsv),
            subtitle: Text(l10n.exportTransactionsCsvSubtitle),
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
            title: Text(l10n.exportFilteredTransactions),
            subtitle: Text(l10n.exportFilteredTransactionsSubtitle),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const FilteredExportDialog(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(l10n.exportAllDataJson),
            subtitle: Text(l10n.exportAllDataJsonSubtitle),
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
          _buildSectionHeader(context, l10n.backup),
          ListTile(
            leading: const Icon(Icons.save),
            title: Text(l10n.createFullBackup),
            subtitle: Text(l10n.createFullBackupSubtitle),
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
            title: Text(l10n.restoreBackup),
            subtitle: Text(l10n.restoreBackupSubtitle),
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
            title: Text(l10n.backupFrequency),
             subtitle: FutureBuilder<String?>(
               future: ref.read(sharedPreferencesProvider).then((p) => p.getString('backup_frequency') ?? 'weekly'),
               builder: (context, snapshot) {
                 return Text(snapshot.data?.toUpperCase() ?? l10n.loading);
               },
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
    final prefs = await ref.read(sharedPreferencesProvider);
    final current = prefs.getString('backup_frequency') ?? 'weekly';

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Backup Frequency'),
        children: [
          SimpleDialogOption(child: const Text('Daily'), onPressed: () => Navigator.pop(context, 'daily')),
          SimpleDialogOption(child: const Text('Weekly'), onPressed: () => Navigator.pop(context, 'weekly')),
          SimpleDialogOption(child: const Text('Monthly'), onPressed: () => Navigator.pop(context, 'monthly')),
          SimpleDialogOption(child: const Text('Never'), onPressed: () => Navigator.pop(context, 'never')),
        ],
      ),
    );

    if (result != null) {
      await ref.read(backupSchedulerProvider).setFrequency(result);
      setState(() {}); // refresh subtitle
    }
  }
}
