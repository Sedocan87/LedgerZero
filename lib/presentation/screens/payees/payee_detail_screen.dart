import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

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

  @override
  Widget build(BuildContext context) {
    final payeeAsync = ref.watch(payeeProvider(widget.payeeId));
    final transactionsAsync = ref.watch(payeeTransactionsProvider(widget.payeeId));
    final l10n = AppLocalizations.of(context)!;

    final categories = ref.watch(categoryMapProvider).value ?? {};
    final accounts = ref.watch(accountMapProvider).value ?? {};

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
                      final updated = payee.copyWith(name: _nameController.text);
                      await ref.read(payeeControllerProvider).updatePayee(updated);
                      ref.invalidate(payeesProvider);
                      ref.invalidate(payeeProvider(widget.payeeId));
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
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.rename)),
                    PopupMenuItem(value: 'merge', child: Text(l10n.merge)),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
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
                          categoryName: categories[tx.categoryId],
                          accountName: accounts[tx.accountId],
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

  void _showMergeDialog(BuildContext context, Payee sourcePayee) {
    showDialog(
      context: context,
      builder: (context) => MergePayeeDialog(sourcePayee: sourcePayee),
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
