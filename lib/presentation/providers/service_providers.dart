import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

final budgetingServiceProvider = Provider<BudgetingService>((ref) {
  return BudgetingService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
  );
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(
    ref.watch(transactionRepositoryProvider),
  );
});
