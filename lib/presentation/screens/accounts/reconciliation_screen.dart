import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

final accountProvider = FutureProvider.family.autoDispose<Account?, String>((ref, id) {
   return ref.watch(accountRepositoryProvider).getAccountById(id);
});

class ReconciliationScreen extends ConsumerStatefulWidget {
  final String accountId;
  const ReconciliationScreen({super.key, required this.accountId});

  @override
  ConsumerState<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  final _balanceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountProvider(widget.accountId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reconcileAccount)),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return Center(child: Text(l10n.accountNotFound));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(l10n.currentBalance(account.currentBalance)),
                const SizedBox(height: 20),
                TextField(
                  controller: _balanceController,
                  decoration: InputDecoration(
                    labelText: l10n.enterActualBalance,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final actual = double.tryParse(_balanceController.text);
                    if (actual == null) {
                      return;
                    }

                    final diff = actual - account.currentBalance;
                    // Floating point comparison might be tricky, use epsilon
                    if (diff.abs() < 0.01) {
                      // Perfect match
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.accountReconciled)));
                        Navigator.pop(context);
                      }
                    } else {
                      final createAdj = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.discrepancyFound),
                          content: Text(
                              l10n.discrepancyMessage(diff.toStringAsFixed(2))),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(l10n.no)),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(l10n.yes)),
                          ],
                        ),
                      );

                      if (createAdj == true) {
                        final transaction = Transaction(
                          id: const Uuid().v4(),
                          accountId: account.id,
                          date: DateTime.now(),
                          amount: diff,
                          memo: 'Reconciliation Balance Adjustment',
                          cleared: TransactionClearStatus.reconciled,
                        );
                        await ref
                            .read(transactionRepositoryProvider)
                            .createTransaction(transaction);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.adjustmentCreated)));
                          Navigator.pop(context);
                        }
                      }
                    }
                  },
                  child: Text(l10n.reconcile),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (e, s) => ErrorView(title: l10n.error, message: e.toString()),
      ),
    );
  }
}
