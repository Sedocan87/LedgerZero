import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/services/budget_currency.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_currency_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/leave_budget_dialog.dart';
import 'package:ledger_zero/presentation/widgets/budget_currency_dialogs.dart';

/// Shown on the budget screen while the open accounts in the budget use
/// more than one currency (data from before the rule, an import, a sync
/// race). To Be Budgeted then adds up different currencies. Names the
/// currencies and the odd accounts and offers two fixes: relabel the odd
/// accounts to the budget currency (amounts are not converted, after the
/// same confirmation as Settings > Currency), or take them out of the
/// budget through the usual leave-budget dialog.
class BudgetCurrencyWarning extends ConsumerWidget {
  const BudgetCurrencyWarning({super.key});

  Future<void> _relabel(
    BuildContext context,
    WidgetRef ref,
    BudgetCurrency budget,
    List<Account> odd,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final from = ({for (final a in odd) a.currency}.toList()..sort());
    if (!await confirmBudgetCurrencyChange(
      context,
      from: from.join(', '),
      to: budget.currency,
    )) {
      return;
    }
    try {
      await changeBudgetCurrency(ref, budget.currency);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.budgetCurrencyChanged(budget.currency))),
      );
    } catch (e, st) {
      Logger.error('Relabelling the odd budget accounts failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    List<Account> odd,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final account = odd.length == 1
        ? odd.single
        : await showDialog<Account>(
            context: context,
            builder: (context) => SimpleDialog(
              key: const Key('budgetCurrency.pickAccount'),
              title: Text(l10n.budgetCurrencyMixedPickAccount),
              children: [
                for (final a in odd)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('${a.name} (${a.currency})'),
                    ),
                  ),
              ],
            ),
          );
    if (account == null || !context.mounted) {
      return;
    }
    final release = await showLeaveBudgetDialog(context, ref, account.id);
    if (release == null) {
      return;
    }
    try {
      await saveAccountWithRelease(
        ref,
        account.copyWith(onBudget: false),
        release,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountUpdated)));
    } catch (e, st) {
      Logger.error('Taking ${account.id} out of the budget failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetCurrencyProvider);
    if (!budget.isMixed) {
      return const SizedBox.shrink();
    }
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final odd = budget.oddAccounts(accounts);
    if (odd.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        key: const Key('budget.currencyWarning'),
        color: scheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.error.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.currency_exchange,
                    size: 20,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.budgetCurrencyMixedWarning(
                        budget.onBudgetCurrencies.join(', '),
                        budget.currency,
                        odd.map((a) => '${a.name} (${a.currency})').join(', '),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    key: const Key('budget.currencyWarning.leave'),
                    onPressed: () => _leave(context, ref, odd),
                    child: Text(l10n.budgetCurrencyMixedLeave),
                  ),
                  TextButton(
                    key: const Key('budget.currencyWarning.relabel'),
                    onPressed: () => _relabel(context, ref, budget, odd),
                    child: Text(
                      l10n.budgetCurrencyChangeConfirmAction(budget.currency),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
