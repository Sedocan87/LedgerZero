import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_view_models.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

/// Local edits that lost against newer edits from another device.
class SyncConflictsScreen extends ConsumerWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conflicts = ref.watch(
      syncControllerProvider.select((s) => s.conflicts),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncConflictsTitle)),
      body: conflicts.isEmpty
          ? Center(child: Text(l10n.syncConflictsEmpty))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.syncConflictsExplanation),
                const SizedBox(height: 16),
                for (final conflict in conflicts)
                  _ConflictCard(conflict: conflict),
              ],
            ),
    );
  }
}

String syncTableLabel(AppLocalizations l10n, String table) => switch (table) {
  'accounts' => l10n.syncTableAccounts,
  'categories' => l10n.syncTableCategories,
  'category_groups' => l10n.syncTableCategoryGroups,
  'transactions' => l10n.syncTableTransactions,
  'payees' => l10n.syncTablePayees,
  'budgets' => l10n.syncTableBudgets,
  'scheduled_transactions' => l10n.syncTableScheduledTransactions,
  'budget_templates' => l10n.syncTableBudgetTemplates,
  'report_notes' => l10n.syncTableReportNotes,
  'import_profiles' => l10n.syncTableImportProfiles,
  'rules' => l10n.syncTableRules,
  _ => table,
};

/// Display name of a synced column; unknown columns keep their name.
String syncFieldLabel(AppLocalizations l10n, String column) => switch (column) {
  'name' => l10n.syncFieldName,
  'amount' => l10n.amount,
  'budgeted' => l10n.budgeted,
  'starting_balance' => l10n.startingBalanceLabel,
  'shared_balance' => l10n.accountBalanceLabel,
  'target_amount' => l10n.goalTarget,
  'date' => l10n.date,
  'month' => l10n.month,
  'memo' => l10n.memo,
  'note' => l10n.note,
  'notes' => l10n.notes,
  'payee_id' => l10n.payee,
  'category_id' => l10n.category,
  'account_id' => l10n.account,
  'transfer_account_id' => l10n.toAccount,
  'category_group_id' => l10n.categoryGroup,
  'cleared' => l10n.status,
  'is_hidden' => l10n.hidden,
  'is_deleted' => l10n.syncConflictDeleted,
  'color' => l10n.color,
  'icon' => l10n.icon,
  'currency' => l10n.currency,
  'frequency' => l10n.frequency,
  'next_date' => l10n.nextDate,
  'end_date' => l10n.endDate,
  'auto_approve' => l10n.autoApprove,
  _ => column,
};

const _moneyColumns = {
  'amount',
  'budgeted',
  'starting_balance',
  'shared_balance',
  'target_amount',
};

class _ConflictCard extends ConsumerWidget {
  final SyncConflictItem conflict;

  const _ConflictCard({required this.conflict});

  Map<String, Object?>? _decode(String? json) =>
      json == null ? null : jsonDecode(json) as Map<String, Object?>;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final mine = _decode(conflict.localSnapshot);
    final theirs = _decode(conflict.remoteSnapshot);
    final label = [
      for (final key in const ['name', 'memo', 'month', 'date', 'note'])
        if ((mine ?? theirs)?[key] is String) (mine ?? theirs)![key] as String,
    ].firstOrNull;
    final columns = {...?mine?.keys, ...?theirs?.keys}
      ..removeAll(SyncSchema.metadataColumns)
      ..remove('id');
    final changed = [
      for (final c in columns)
        if (mine?[c] != theirs?[c]) c,
    ]..sort();
    String show(String column, Object? value) =>
        _moneyColumns.contains(column) && value is int
        ? fmt.formatMoney(value)
        : '${value ?? '–'}';
    final controller = ref.read(syncControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label == null
                  ? syncTableLabel(l10n, conflict.syncTable)
                  : l10n.labelValue(
                      syncTableLabel(l10n, conflict.syncTable),
                      label,
                    ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              l10n.syncConflictResolvedAt(
                fmt.formatDateTime(conflict.resolvedAt.toLocal()),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (mine == null || theirs == null)
              Text(
                '${l10n.labelValue(l10n.syncConflictMine, mine == null ? l10n.syncConflictDeleted : '…')}\n'
                '${l10n.labelValue(l10n.syncConflictTheirs, theirs == null ? l10n.syncConflictDeleted : '…')}',
              )
            else
              for (final c in changed.take(6))
                Text(
                  '${syncFieldLabel(l10n, c)} — '
                  '${l10n.labelValue(l10n.syncConflictMine, show(c, mine[c]))} · '
                  '${l10n.labelValue(l10n.syncConflictTheirs, show(c, theirs[c]))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => controller.dismissConflict(conflict.id),
                  child: Text(l10n.syncConflictDismiss),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final ok = await controller.keepMine(conflict.id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.syncConflictKeepFailed)),
                      );
                    }
                  },
                  child: Text(l10n.syncConflictKeepMine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
