import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/services/budget_currency.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

/// The budget currency derived from the accounts ([BudgetCurrency]); the
/// stored setting until the accounts have loaded or while none is in the
/// budget.
final budgetCurrencyProvider = Provider<BudgetCurrency>((ref) {
  final setting = ref.watch(settingsProvider.select((s) => s.currency));
  final accounts = ref.watch(accountsProvider).valueOrNull;
  return accounts == null
      ? BudgetCurrency(currency: setting)
      : BudgetCurrency.of(accounts, setting: setting);
});

/// Keeps the stored setting (Settings > Currency, per phone) equal to the
/// currency of the accounts in the budget, so both phones of a household
/// agree and the formatter, the reports and the imports use it. Runs when
/// the accounts load (start-up, a restore) and whenever they change,
/// which includes a sync run that applied the partner's changes (the
/// accounts stream emits then). Kept alive by `MyApp`.
final budgetCurrencyGuardProvider = Provider<void>((ref) {
  final setting = ref.watch(settingsProvider.select((s) => s.currency));
  final accounts = ref.watch(accountsProvider).valueOrNull;
  if (accounts == null) {
    return;
  }
  final budget = BudgetCurrency.of(accounts, setting: setting);
  if (budget.isFixed && budget.currency != setting) {
    unawaited(
      Future.microtask(
        () => ref.read(settingsProvider.notifier).setCurrency(budget.currency),
      ),
    );
  }
});

/// Relabels the accounts in the budget to [currency] (amounts are not
/// converted; [AccountService.relabelBudgetCurrency]) and stores it as the
/// budget currency. Returns the number of accounts relabelled.
Future<int> changeBudgetCurrency(WidgetRef ref, String currency) async {
  final count = await ref
      .read(accountServiceProvider)
      .relabelBudgetCurrency(currency);
  await ref.read(settingsProvider.notifier).setCurrency(currency);
  return count;
}
