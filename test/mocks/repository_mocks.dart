import 'package:mockito/annotations.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

@GenerateMocks([
  AccountRepository,
  BudgetRepository,
  CategoryRepository,
  PayeeRepository,
  TransactionRepository,
])
void main() {}
