import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:intl/intl.dart';

class FilteredExportDialog extends ConsumerStatefulWidget {
  const FilteredExportDialog({super.key});

  @override
  ConsumerState<FilteredExportDialog> createState() =>
      _FilteredExportDialogState();
}

class _FilteredExportDialogState extends ConsumerState<FilteredExportDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedAccountIds = [];
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref
        .watch(accountRepositoryProvider)
        .watchAllAccounts();
    final categoriesAsync = ref
        .watch(categoryRepositoryProvider)
        .watchAllCategories();

    return AlertDialog(
      title: const Text('Export Filtered Transactions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range
            Text(l10n.dateRange, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                    child: Text(
                      _startDate != null
                          ? DateFormat.yMd().format(_startDate!)
                          : 'Start Date',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                    child: Text(
                      _endDate != null
                          ? DateFormat.yMd().format(_endDate!)
                          : l10n.endDate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Accounts
            Text(l10n.accounts, style: Theme.of(context).textTheme.labelLarge),
            StreamBuilder(
              stream: accountsAsync,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const AppLoadingIndicator();
                }
                final accounts = snapshot.data!;
                return Wrap(
                  spacing: 8,
                  children: accounts.map((account) {
                    final isSelected = _selectedAccountIds.contains(account.id);
                    return FilterChip(
                      label: Text(account.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAccountIds.add(account.id);
                          } else {
                            _selectedAccountIds.remove(account.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Categories
            Text(
              l10n.categories,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            StreamBuilder(
              stream: categoriesAsync,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const AppLoadingIndicator();
                }
                final categories = snapshot.data!;
                // Just show a count or simplified selector if too many
                if (categories.length > 10) {
                  return OutlinedButton(
                    onPressed: () {
                      // Show full category picker dialog
                      // Simplified for this MVP: Just toggle "All" or "None"
                      setState(() {
                        if (_selectedCategoryIds.isEmpty) {
                          _selectedCategoryIds.addAll(
                            categories.map((c) => c.id),
                          );
                        } else {
                          _selectedCategoryIds.clear();
                        }
                      });
                    },
                    child: Text(
                      _selectedCategoryIds.isEmpty
                          ? 'Select All Categories'
                          : '${_selectedCategoryIds.length} Categories Selected',
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategoryIds.contains(cat.id);
                    return FilterChip(
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategoryIds.add(cat.id);
                          } else {
                            _selectedCategoryIds.remove(cat.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
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
    setState(() => _isLoading = true);
    try {
      final filter = TransactionFilter(
        startDate: _startDate,
        endDate: _endDate,
        accountIds: _selectedAccountIds.isNotEmpty ? _selectedAccountIds : null,
        categoryIds: _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds
            : null,
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

      await TransactionExportService().exportTransactionsToCsv(
        transactions: transactions,
        payeeNames: {for (var p in payees) p.id: p.name},
        categoryNames: {for (var c in categories) c.id: c.name},
        accountNames: {for (var a in accounts) a.id: a.name},
        filenamePrefix: 'filtered_transactions',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.exportSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
