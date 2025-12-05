import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

class SampleDataGenerator {
  final Ref ref;

  SampleDataGenerator(this.ref);

  Future<void> generate() async {
    final accountRepository = ref.read(accountRepositoryProvider);
    final transactionRepository = ref.read(transactionRepositoryProvider);
    // Categories should already be seeded by database creation

    // 1. Create Accounts
    final checkingId = const Uuid().v4();
    await accountRepository.createAccount(
      Account(
        id: checkingId,
        name: 'Demo Checking',
        type: AccountType.checking,
        currentBalance: 1500.0,
        startingBalance: 0.0,
      ),
    );

    final savingsId = const Uuid().v4();
    await accountRepository.createAccount(
      Account(
        id: savingsId,
        name: 'Demo Savings',
        type: AccountType.savings,
        currentBalance: 5000.0,
        startingBalance: 0.0,
      ),
    );

    // 2. Create Initial Balances (Inflow Transactions)
    final now = DateTime.now();
    await transactionRepository.createTransaction(
      Transaction(
        id: const Uuid().v4(),
        accountId: checkingId,
        date: now.subtract(const Duration(days: 30)),
        amount: 3000.0, // Initial Paycheck
        memo: 'Starting Balance / Paycheck',
        cleared: TransactionClearStatus.cleared,
        approved: true,
      ),
    );

     await transactionRepository.createTransaction(
      Transaction(
        id: const Uuid().v4(),
        accountId: savingsId,
        date: now.subtract(const Duration(days: 30)),
        amount: 5000.0,
        memo: 'Emergency Fund',
        cleared: TransactionClearStatus.cleared,
        approved: true,
      ),
    );

    // 3. Create Expenses
    // We would need category IDs. Since we don't have them easily without querying,
    // we'll assume the user will categorize them or we skip detailed transactions for now.
    // Ideally we would fetch categories first.
  }
}

final sampleDataGeneratorProvider = Provider((ref) => SampleDataGenerator(ref));
