import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/categories_provider.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

// Local provider for accounts
final _accountsStreamProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

class PayeeDetailScreen extends ConsumerStatefulWidget {
  final String payeeId;

  const PayeeDetailScreen({super.key, required this.payeeId});

  @override
  ConsumerState<PayeeDetailScreen> createState() => _PayeeDetailScreenState();
}

class _PayeeDetailScreenState extends ConsumerState<PayeeDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updatePayee(Payee payee) async {
    await ref.read(payeeControllerProvider).updatePayee(payee);
    ref.invalidate(payeeProvider(widget.payeeId));
  }

  void _deletePayee(BuildContext context, int transactionCount) {
    final l10n = AppLocalizations.of(context)!;

    // Always show dialog for safety
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePayeeConfirmation),
        content: Text(l10n.deletePayeeWarning(ref.read(payeeProvider(widget.payeeId)).value!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(payeeControllerProvider).deletePayee(widget.payeeId);
              if (context.mounted) {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Screen
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, Payee sourcePayee) {
    showDialog(
      context: context,
      builder: (context) => MergePayeeDialog(sourcePayee: sourcePayee),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payeeAsync = ref.watch(payeeProvider(widget.payeeId));
    final transactionsAsync = ref.watch(payeeTransactionsProvider(widget.payeeId));
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final accountsAsync = ref.watch(_accountsStreamProvider);
    final l10n = AppLocalizations.of(context)!;

    final categoriesMap = ref.watch(categoryMapProvider).value ?? {};
    final accountsMap = ref.watch(accountMapProvider).value ?? {};

    return payeeAsync.when(
      data: (payee) {
        if (payee == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.unknownPayee)),
            body: Center(child: Text(l10n.unknownPayee)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: _isEditing
                ? TextField(
                    controller: _nameController..text = payee.name,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                    autofocus: true,
                  )
                : Text(payee.name),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    if (_nameController.text.isNotEmpty) {
                      await _updatePayee(payee.copyWith(name: _nameController.text));
                      setState(() {
                        _isEditing = false;
                      });
                    }
                  },
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      setState(() {
                        _isEditing = true;
                      });
                    } else if (value == 'merge') {
                      _showMergeDialog(context, payee);
                    } else if (value == 'delete') {
                      transactionsAsync.whenData((txs) {
                        _deletePayee(context, txs.length);
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.rename)),
                    PopupMenuItem(value: 'merge', child: Text(l10n.merge)),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
               // Stats & Settings
               transactionsAsync.when(
                 data: (transactions) {
                    final count = transactions.length;
                    final totalSpent = transactions.fold<double>(0.0, (sum, t) => sum + (t.amount < 0 ? t.amount.abs() : 0));
                    final lastUsed = transactions.isNotEmpty ? transactions.first.date : null;

                    return Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text(l10n.usageStats, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatItem(label: l10n.timesUsed, value: count.toString()),
                                  _StatItem(label: l10n.totalSpent, value: NumberFormat.simpleCurrency().format(totalSpent)),
                                  _StatItem(label: l10n.lastUsed, value: lastUsed != null ? DateFormat.yMMMd().format(lastUsed) : '-'),
                                ],
                              ),
                              const Divider(height: 32),

                              // Auto Category
                              categoriesAsync.when(
                                data: (categories) => DropdownButtonFormField<String>(
                                  key: ValueKey('cat_${payee.autoCategoryId}'),
                                  decoration: InputDecoration(labelText: l10n.autoCategory),
                                  initialValue: payee.autoCategoryId,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('None')), // TODO l10n
                                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                  ],
                                  onChanged: (value) {
                                    if (value != payee.autoCategoryId) {
                                      _updatePayee(payee.copyWith(autoCategoryId: value));
                                    }
                                  },
                                ),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => const SizedBox(),
                              ),
                              const SizedBox(height: 16),

                              // Default Account
                              accountsAsync.when(
                                data: (accounts) => DropdownButtonFormField<String>(
                                  key: ValueKey('acc_${payee.defaultAccountId}'),
                                  decoration: InputDecoration(labelText: l10n.defaultAccount),
                                  initialValue: payee.defaultAccountId,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('None')), // TODO l10n
                                    ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
                                  ],
                                  onChanged: (value) {
                                    if (value != payee.defaultAccountId) {
                                      _updatePayee(payee.copyWith(defaultAccountId: value));
                                    }
                                  },
                                ),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => const SizedBox(),
                              ),
                           ],
                        ),
                      ),
                    );
                 },
                 loading: () => const LinearProgressIndicator(),
                 error: (_, __) => const SizedBox(),
               ),

              Expanded(
                child: transactionsAsync.when(
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Center(child: Text(l10n.noTransactions));
                    }
                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return TransactionListItem(
                          transaction: tx,
                          payeeName: payee.name,
                          categoryName: categoriesMap[tx.categoryId],
                          accountName: accountsMap[tx.accountId],
                          onTap: () {
                            context.push('/edit-transaction/${tx.id}');
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => ErrorView(title: l10n.error, message: e.toString()),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: ErrorView(title: l10n.error, message: err.toString())),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class MergePayeeDialog extends ConsumerStatefulWidget {
  final Payee sourcePayee;
  const MergePayeeDialog({super.key, required this.sourcePayee});

  @override
  ConsumerState<MergePayeeDialog> createState() => _MergePayeeDialogState();
}

class _MergePayeeDialogState extends ConsumerState<MergePayeeDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final payeesAsync = ref.watch(payeesProvider);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.mergePayee),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mergePayeeInto(widget.sourcePayee.name)),
          const SizedBox(height: 16),
          payeesAsync.when(
            data: (payees) {
              final candidates = payees
                  .where((p) => p.id != widget.sourcePayee.id)
                  .toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (candidates.isEmpty) {
                return Text(l10n.noPayees);
              }
              return DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l10n.payee),
                items: candidates
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTargetId = value;
                  });
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text(e.toString()),
          ),
          const SizedBox(height: 8),
          if (_selectedTargetId != null)
            payeesAsync.maybeWhen(
              data: (payees) {
                 final targetName = payees.firstWhere((p) => p.id == _selectedTargetId).name;
                 return Text(
                    l10n.mergeWarning(targetName),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                 );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          onPressed: _selectedTargetId == null
              ? null
              : () async {
                  await ref.read(payeeControllerProvider).mergePayees(widget.sourcePayee.id, _selectedTargetId!);
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close detail screen
                  }
                },
          child: Text(l10n.merge),
        ),
      ],
    );
  }
}
