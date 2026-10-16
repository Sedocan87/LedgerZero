import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';

/// Exports the transactions matching a date range, accounts and categories
/// to CSV (Backup & Export screen).
class FilteredExportDialog extends ConsumerStatefulWidget {
  const FilteredExportDialog({super.key});

  @override
  ConsumerState<FilteredExportDialog> createState() =>
      _FilteredExportDialogState();
}

class _FilteredExportDialogState extends ConsumerState<FilteredExportDialog> {
  /// Inclusive calendar days (UTC midnight).
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedAccountIds = {};
  final Set<String> _selectedCategoryIds = {};
  bool _isLoading = false;

  Future<DateTime?> _pickDate(DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: CalendarDate.toLocalDay(current ?? CalendarDate.today()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return picked == null ? null : CalendarDate.fromLocalPick(picked);
  }

  Widget _chips(
    Map<String, String> options,
    Set<String> selected, {
    required String emptyText,
  }) {
    if (options.isEmpty) {
      return Text(emptyText);
    }
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          FilterChip(
            label: Text(entry.value),
            selected: selected.contains(entry.key),
            onSelected: (value) => setState(
              () =>
                  value ? selected.add(entry.key) : selected.remove(entry.key),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final accountsAsync = ref.watch(accountMapProvider);
    final categoriesAsync = ref.watch(categoryMapProvider);
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return AlertDialog(
      title: Text(l10n.exportFilteredCsv),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dateRange, style: labelStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await _pickDate(_startDate);
                      if (picked != null && mounted) {
                        setState(() => _startDate = picked);
                      }
                    },
                    child: Text(
                      _startDate != null
                          ? fmt.formatDate(_startDate!)
                          : l10n.startDate,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await _pickDate(_endDate);
                      if (picked != null && mounted) {
                        setState(() => _endDate = picked);
                      }
                    },
                    child: Text(
                      _endDate != null
                          ? fmt.formatDate(_endDate!)
                          : l10n.endDate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.accounts, style: labelStyle),
            accountsAsync.when(
              data: (accounts) => _chips(
                accounts,
                _selectedAccountIds,
                emptyText: l10n.exportFilterAll,
              ),
              loading: () => const AppLoadingIndicator(),
              error: (_, _) => Text(l10n.errorOccurred),
            ),
            const SizedBox(height: 16),
            Text(l10n.categories, style: labelStyle),
            categoriesAsync.when(
              data: (categories) => _chips(
                categories,
                _selectedCategoryIds,
                emptyText: l10n.exportFilterAll,
              ),
              loading: () => const AppLoadingIndicator(),
              error: (_, _) => Text(l10n.errorOccurred),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exportFilterHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _export,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.export),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final shareText = AppLocalizations.of(context)!.transactionsShareText;
    setState(() => _isLoading = true);
    try {
      final filter = TransactionFilter(
        startDate: _startDate,
        endDate: _endDate,
        accountIds: _selectedAccountIds.isEmpty
            ? null
            : _selectedAccountIds.toList(),
        categoryIds: _selectedCategoryIds.isEmpty
            ? null
            : _selectedCategoryIds.toList(),
      );
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getTransactions(filter: filter);
      final payees = await ref.read(payeeRepositoryProvider).getAllPayees();
      final categories = await ref
          .read(categoryRepositoryProvider)
          .getAllCategories();
      final accounts = await ref
          .read(accountRepositoryProvider)
          .getAllAccounts();

      await TransactionExportService(
        files: ref.read(exportFileServiceProvider),
      ).exportTransactionsToCsv(
        transactions: transactions,
        payeeNames: {for (final p in payees) p.id: p.name},
        categoryNames: {for (final c in categories) c.id: c.name},
        accountNames: {for (final a in accounts) a.id: a.name},
        filenamePrefix: 'filtered_transactions',
        shareText: shareText,
      );
      if (mounted) {
        navigator.pop();
      }
    } catch (e, st) {
      Logger.error('Filtered export failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedGeneric)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
