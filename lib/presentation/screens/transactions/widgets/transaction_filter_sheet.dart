import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

/// Edits a [TransactionFilter]; [onApply] receives the result.
class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  final TransactionFilter initialFilter;
  final ValueChanged<TransactionFilter> onApply;

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  late TransactionFilter _filter;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    final fmt = ref.read(appFormatterProvider);
    if (_filter.minAbsAmount != null) {
      _minController.text = fmt.formatAmountForInput(_filter.minAbsAmount!);
    }
    if (_filter.maxAbsAmount != null) {
      _maxController.text = fmt.formatAmountForInput(_filter.maxAbsAmount!);
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  /// The filter with the amount range from the text fields (absolute
  /// amounts in minor units; empty or unparseable means no bound).
  TransactionFilter _withAmountRange(TransactionFilter filter) {
    final fmt = ref.read(appFormatterProvider);
    final min = fmt.parseAmount(_minController.text)?.abs();
    final max = fmt.parseAmount(_maxController.text)?.abs();
    return TransactionFilter(
      ids: filter.ids,
      accountIds: filter.accountIds,
      categoryIds: filter.categoryIds,
      payeeIds: filter.payeeIds,
      startDate: filter.startDate,
      endDate: filter.endDate,
      minAmount: filter.minAmount,
      maxAmount: filter.maxAmount,
      minAbsAmount: min,
      maxAbsAmount: max,
      memoSearch: filter.memoSearch,
      clearedStatuses: filter.clearedStatuses,
    );
  }

  Widget _chips(
    Map<String, String> items,
    List<String>? selected,
    ValueChanged<List<String>> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      children: items.entries.map((entry) {
        final isSelected = selected?.contains(entry.key) ?? false;
        return FilterChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (value) {
            final current = selected?.toList() ?? [];
            value ? current.add(entry.key) : current.remove(entry.key);
            setState(() => onChanged(current));
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountMapProvider).valueOrNull ?? {};
    final categories = ref.watch(categoryMapProvider).valueOrNull ?? {};
    final payees = ref.watch(payeeMapProvider).valueOrNull ?? {};
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Text(
                l10n.filters,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // Status Filter
              _buildSectionTitle(l10n.status),
              Wrap(
                spacing: 8,
                children: TransactionClearStatus.values.map((status) {
                  final isSelected =
                      _filter.clearedStatuses?.contains(status) ?? false;
                  return FilterChip(
                    label: Text(status.label(l10n)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        final current = _filter.clearedStatuses?.toList() ?? [];
                        if (selected) {
                          current.add(status);
                        } else {
                          current.remove(status);
                        }
                        _filter = _filter.copyWith(clearedStatuses: current);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Date Range Filter
              _buildSectionTitle(l10n.dateRange),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_getDateRangeLabel(_filter, l10n)),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDateRange:
                              _filter.startDate != null &&
                                  _filter.endDate != null
                              ? DateTimeRange(
                                  start: CalendarDate.toLocalDay(
                                    _filter.startDate!,
                                  ),
                                  end: CalendarDate.toLocalDay(
                                    _filter.endDate!,
                                  ),
                                )
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            // Inclusive calendar days (UTC midnight).
                            _filter = _filter.copyWith(
                              startDate: CalendarDate.fromLocalPick(
                                picked.start,
                              ),
                              endDate: CalendarDate.fromLocalPick(picked.end),
                            );
                          });
                        }
                      },
                    ),
                  ),
                  if (_filter.startDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.clear,
                      onPressed: () {
                        setState(() {
                          // Reconstruct filter clearing dates
                          _filter = TransactionFilter(
                            ids: _filter.ids,
                            accountIds: _filter.accountIds,
                            categoryIds: _filter.categoryIds,
                            payeeIds: _filter.payeeIds,
                            startDate: null,
                            endDate: null,
                            minAmount: _filter.minAmount,
                            maxAmount: _filter.maxAmount,
                            minAbsAmount: _filter.minAbsAmount,
                            maxAbsAmount: _filter.maxAbsAmount,
                            memoSearch: _filter.memoSearch,
                            clearedStatuses: _filter.clearedStatuses,
                          );
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Accounts Filter
              _buildSectionTitle(l10n.accounts),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noAccountsFound),
                )
              else
                Wrap(
                  spacing: 8,
                  children: accounts.entries.map((entry) {
                    final isSelected =
                        _filter.accountIds?.contains(entry.key) ?? false;
                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          final current = _filter.accountIds?.toList() ?? [];
                          if (selected) {
                            current.add(entry.key);
                          } else {
                            current.remove(entry.key);
                          }
                          _filter = _filter.copyWith(accountIds: current);
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // Categories Filter
              _buildSectionTitle(l10n.categories),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noCategoriesFound),
                )
              else
                Wrap(
                  spacing: 8,
                  children: categories.entries.map((entry) {
                    final isSelected =
                        _filter.categoryIds?.contains(entry.key) ?? false;
                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          final current = _filter.categoryIds?.toList() ?? [];
                          if (selected) {
                            current.add(entry.key);
                          } else {
                            current.remove(entry.key);
                          }
                          _filter = _filter.copyWith(categoryIds: current);
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Payees Filter
              _buildSectionTitle(l10n.txFilterPayees),
              if (payees.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noPayees),
                )
              else
                _chips(
                  payees,
                  _filter.payeeIds,
                  (ids) => _filter = _filter.copyWith(payeeIds: ids),
                ),
              const SizedBox(height: 16),

              // Amount range (absolute amounts)
              _buildSectionTitle(l10n.amount),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('filter_amount_min'),
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.txFilterAmountFrom,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      key: const Key('filter_amount_max'),
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.txFilterAmountTo,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filter = const TransactionFilter();
                          _minController.clear();
                          _maxController.clear();
                        });
                      },
                      child: Text(l10n.reset),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_withAmountRange(_filter));
                        Navigator.pop(context);
                      },
                      child: Text(l10n.apply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  String _getDateRangeLabel(TransactionFilter filter, AppLocalizations l10n) {
    if (filter.startDate == null || filter.endDate == null) {
      return l10n.selectDateRange;
    }
    final fmt = ref.watch(appFormatterProvider);
    return l10n.dateRangeValue(
      fmt.formatDate(filter.startDate!),
      fmt.formatDate(filter.endDate!),
    );
  }
}
