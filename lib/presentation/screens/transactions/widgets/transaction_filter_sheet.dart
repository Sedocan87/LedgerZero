import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  late TransactionFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = ref.read(transactionsProvider).filter;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountMapProvider).value ?? {};
    final categories = ref.watch(categoryMapProvider).value ?? {};

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
              Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),

              // Status Filter
              _buildSectionTitle('Status'),
              Wrap(
                spacing: 8,
                children: TransactionClearStatus.values.map((status) {
                  final isSelected =
                      _filter.clearedStatuses?.contains(status) ?? false;
                  return FilterChip(
                    label: Text(status.name.toUpperCase()),
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
              _buildSectionTitle('Date Range'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_getDateRangeLabel(_filter)),
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
                                  start: _filter.startDate!,
                                  end: _filter.endDate!,
                                )
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _filter = _filter.copyWith(
                              startDate: picked.start,
                              endDate: picked.end,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  if (_filter.startDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
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
              _buildSectionTitle('Accounts'),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No accounts found'),
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
              _buildSectionTitle('Categories'),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No categories found'),
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

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filter = const TransactionFilter();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(transactionsProvider.notifier)
                            .updateFilter(_filter);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
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

  String _getDateRangeLabel(TransactionFilter filter) {
    if (filter.startDate == null || filter.endDate == null) {
      return 'Select Date Range';
    }
    final dateFormat = DateFormat.yMMMd();
    return '${dateFormat.format(filter.startDate!)} - ${dateFormat.format(filter.endDate!)}';
  }
}
