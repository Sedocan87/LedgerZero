import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Provider to fetch database stats
final databaseStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = AppDatabase.instance;

  // Row counts
  final accountsCount = await db.select(db.accounts).get().then((l) => l.length);
  final transactionsCount = await db.select(db.transactions).get().then((l) => l.length);
  final categoriesCount = await db.select(db.categories).get().then((l) => l.length);
  final categoryGroupsCount = await db.select(db.categoryGroups).get().then((l) => l.length);
  final payeesCount = await db.select(db.payees).get().then((l) => l.length);
  final budgetsCount = await db.select(db.budgets).get().then((l) => l.length);
  final scheduledCount = await db.select(db.scheduledTransactions).get().then((l) => l.length);
  final syncLogCount = await db.select(db.syncLog).get().then((l) => l.length);

  // File sizes
  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File('${dbFolder.path}/db.sqlite');
  final walFile = File('${dbFolder.path}/db.sqlite-wal');

  int dbSizeBytes = 0;
  if (await dbFile.exists()) {
    dbSizeBytes = await dbFile.length();
  }

  int walSizeBytes = 0;
  if (await walFile.exists()) {
    walSizeBytes = await walFile.length();
  }

  return {
    'rowCounts': {
      'Accounts': accountsCount,
      'Transactions': transactionsCount,
      'Categories': categoriesCount,
      'Category Groups': categoryGroupsCount,
      'Payees': payeesCount,
      'Budgets': budgetsCount,
      'Scheduled Transactions': scheduledCount,
      'Sync Log': syncLogCount,
    },
    'fileSizes': {
      'Database (db.sqlite)': _formatBytes(dbSizeBytes),
      'WAL (db.sqlite-wal)': _formatBytes(walSizeBytes),
    },
    'totalRows': accountsCount + transactionsCount + categoriesCount + categoryGroupsCount + payeesCount + budgetsCount + scheduledCount + syncLogCount,
  };
});

String _formatBytes(int bytes) {
  if (bytes <= 0) {
      return '0 B';
    }
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double d = bytes.toDouble();
  while (d >= 1024 && i < suffixes.length - 1) {
    d /= 1024;
    i++;
  }
  return '${d.toStringAsFixed(2)} ${suffixes[i]}';
}

class DatabaseStatsScreen extends ConsumerWidget {
  const DatabaseStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(databaseStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.databaseStatistics),
      ),
      body: statsAsync.when(
        data: (stats) {
          final rowCounts = stats['rowCounts'] as Map<String, int>;
          final fileSizes = stats['fileSizes'] as Map<String, String>;
          final totalRows = stats['totalRows'] as int;

          return ListView(
            children: [
              _buildSectionTitle(context, l10n.databaseSize),
              ...fileSizes.entries.map((e) => ListTile(
                title: Text(e.key),
                trailing: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
              )),

              const Divider(),

              _buildSectionTitle(context, l10n.tableRowCounts),
              ...rowCounts.entries.map((e) => ListTile(
                title: Text(e.key),
                trailing: Text(e.value.toString()),
              )),

              const Divider(),

              ListTile(
                title: Text(l10n.totalRows, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(totalRows.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
