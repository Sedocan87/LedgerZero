import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:uuid/uuid.dart';

class ImportConfirmationScreen extends ConsumerStatefulWidget {
  final List<ImportTransaction> transactions;

  const ImportConfirmationScreen({
    super.key,
    required this.transactions,
  });

  @override
  ConsumerState<ImportConfirmationScreen> createState() => _ImportConfirmationScreenState();
}

class _ImportConfirmationScreenState extends ConsumerState<ImportConfirmationScreen> {
  late List<ImportTransaction> _transactions;
  final currencyFormat = NumberFormat.simpleCurrency();
  final dateFormat = DateFormat.yMMMd();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactions;
  }

  void _toggleSelection(int index) {
    setState(() {
      _transactions[index].isSelected = !_transactions[index].isSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _transactions.where((t) => t.isSelected).length;
    final duplicateCount = _transactions.where((t) => t.isDuplicate).length;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(l10n.confirmImport),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmImportDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (duplicateCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer),
                            const SizedBox(width: 8),
                            Text(
                              l10n.deduplicationComplete(duplicateCount),
                              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    return CheckboxListTile(
                      value: tx.isSelected,
                      onChanged: _isImporting ? null : (v) => _toggleSelection(index),
                      tileColor: tx.isDuplicate ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3) : null,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tx.payeeName ?? l10n.unknownPayee,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            currencyFormat.format(tx.amount),
                            style: TextStyle(
                              color: tx.amount < 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateFormat.format(tx.date)),
                          if (tx.isDuplicate)
                            Text(
                              l10n.duplicateWarning,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      secondary: tx.isDuplicate ? const Icon(Icons.warning, color: Colors.amber) : const Icon(Icons.receipt),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.total),
                        Text(
                          '$selectedCount transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _isImporting ? null : () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: selectedCount > 0 && !_isImporting
                          ? () => _showAccountSelectionDialog(_transactions.where((t) => t.isSelected).toList())
                          : null,
                      child: Text(l10n.import),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isImporting)
          const ModalBarrier(
            dismissible: false,
            color: Colors.black54,
          ),
        if (_isImporting)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _showAccountSelectionDialog(List<ImportTransaction> selectedTransactions) async {
    final l10n = AppLocalizations.of(context)!;
    // We need to pick an account to import these into.
    // Fetch accounts
    final accounts = await ref.read(accountRepositoryProvider).getAllAccounts();

    if (accounts.isEmpty) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.createFirstAccountMessage)),
            );
        }
        return;
    }

    String? selectedAccountId = accounts.first.id;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.selectAccount),
              content: DropdownButtonFormField<String>(
                value: selectedAccountId,
                items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => selectedAccountId = v),
                decoration: InputDecoration(labelText: l10n.account),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.import),
                ),
              ],
            );
          }
        );
      },
    );

    if (confirmed == true && selectedAccountId != null) {
       _performImport(selectedTransactions, selectedAccountId!);
    }
  }

  Future<void> _performImport(List<ImportTransaction> transactions, String accountId) async {
      final l10n = AppLocalizations.of(context)!;
      final repo = ref.read(transactionRepositoryProvider);

      setState(() => _isImporting = true);

      try {
        // Batch create
        final entities = transactions.map((t) => Transaction(
            id: const Uuid().v4(),
            accountId: accountId,
            date: t.date,
            amount: t.amount,
            payeeId: null,
            memo: t.payeeName != null ? '${t.payeeName} - ${t.memo ?? ""}' : t.memo,
            categoryId: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
        )).toList();

        await repo.batchCreateTransactions(entities);

        if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text(l10n.importSuccess),
                content: Text(l10n.importedTransactions(entities.length)),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      context.go('/transactions');
                    },
                    child: Text(l10n.transactions), // "Transactions"
                  ),
                ],
              ),
            );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
           );
        }
      } finally {
        if (mounted) {
           setState(() => _isImporting = false);
        }
      }
  }
}
