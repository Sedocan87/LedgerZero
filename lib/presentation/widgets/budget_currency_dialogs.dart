import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Confirms relabelling the accounts in the budget from [from] (one code,
/// or several joined with ", ") to [to]. Says plainly that amounts are not
/// converted. Used by Settings > Currency and the budget screen's
/// mixed-currency warning.
Future<bool> confirmBudgetCurrencyChange(
  BuildContext context, {
  required String from,
  required String to,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('budgetCurrency.confirm'),
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(l10n.budgetCurrencyChangeConfirmTitle(to)),
      content: SingleChildScrollView(
        child: Text(l10n.budgetCurrencyChangeConfirmBody(from, to)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('budgetCurrency.confirm.change'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.budgetCurrencyChangeConfirmAction(to)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// An account in [accountCurrency] would join (or rejoin) a budget in
/// [budgetCurrency]: refused, with the offer to relabel the account.
/// Returns true when the user chose to relabel it (amounts are not
/// converted), false to leave it as it is.
Future<bool> confirmJoinInBudgetCurrency(
  BuildContext context, {
  required String accountCurrency,
  required String budgetCurrency,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final relabel = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('account.currencyJoin'),
      title: Text(l10n.accountCurrencyJoinTitle),
      content: SingleChildScrollView(
        child: Text(
          l10n.accountCurrencyJoinBody(accountCurrency, budgetCurrency),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('account.currencyJoin.relabel'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.budgetCurrencyChangeConfirmAction(budgetCurrency)),
        ),
      ],
    ),
  );
  return relabel ?? false;
}
