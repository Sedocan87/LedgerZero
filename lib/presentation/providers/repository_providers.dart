import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/payee_repository_impl.dart';
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

/// Provides the [AccountRepository].
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(ref.watch(accountsDaoProvider));
});

/// Provides the [BudgetRepository].
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl(ref.watch(budgetsDaoProvider));
});

/// Provides the [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoriesDaoProvider));
});

/// Provides the [PayeeRepository].
final payeeRepositoryProvider = Provider<PayeeRepository>((ref) {
  return PayeeRepositoryImpl(ref.watch(payeesDaoProvider));
});

/// Provides the [TransactionRepository].
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionsDaoProvider));
});
