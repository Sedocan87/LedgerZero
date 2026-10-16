// Shared repository mocks for widget/provider tests that need a few canned
// answers. Prefer a real in-memory database (test/helpers/test_database.dart)
// whenever the behaviour under test touches data.
import 'package:mockito/annotations.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

@GenerateNiceMocks([
  MockSpec<AccountRepository>(),
  MockSpec<BudgetRepository>(),
  MockSpec<CategoryRepository>(),
  MockSpec<ParsingHistoryRepository>(),
  MockSpec<PayeeRepository>(),
  MockSpec<TransactionRepository>(),
])
void main() {}
