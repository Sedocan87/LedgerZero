import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                Text('Filters',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
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
                          final current =
                              _filter.clearedStatuses?.toList() ?? [];
                          if (selected) {
                            current.add(status);
                          } else {
                            current.remove(status);
                          }
                          _filter =
                              _filter.copyWith(clearedStatuses: current);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Accounts'),
                if (accounts.isEmpty)
                   const Text('No accounts found')
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
                          final current =
                              _filter.accountIds?.toList() ?? [];
                          if (selected) {
                            current.add(entry.key);
                          } else {
                            current.remove(entry.key);
                          }
                          _filter =
                              _filter.copyWith(accountIds: current);
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
                    )),
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
                    )),
                  ],
                )
              ],
            ),
          );
        });
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}
