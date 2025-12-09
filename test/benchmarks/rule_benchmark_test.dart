import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/entities/payee.dart';

// Mock PayeeRepository
class MockPayeeRepository extends Mock implements PayeeRepository {
  @override
  Future<Payee?> getPayeeById(String id) async {
    return Payee(id: id, name: 'Payee $id', createdAt: DateTime.now());
  }
}

// Minimal mock using Mockito mixin and implementing the interface correctly
class MockTransactionRepository extends Mock implements TransactionRepository {
    // We don't need to implement methods for this test as we don't call them
    // unless applyRules calls them (which it doesn't, only applyRulesToAllTransactions does)
}

void main() {
  test('Rule Benchmark: 50,000 transactions', () async {
    final payeeRepo = MockPayeeRepository();
    final transactionRepo = MockTransactionRepository();

    final service = RuleMatchingService(payeeRepo, transactionRepo);

    // 1. Generate Rules (50 rules)
    final rules = List.generate(50, (index) {
       return Rule(
         id: 'rule_$index',
         name: 'Rule $index',
         priority: index,
         isActive: true,
         matchLogic: RuleMatchLogic.and,
         conditions: [
           RuleCondition(type: RuleConditionType.description, operator: RuleConditionOperator.contains, value: 'keyword_$index'),
         ],
         actions: [
           const RuleAction(type: RuleActionType.setMemo, value: 'Matched'),
         ],
       );
    });

    // 2. Generate Transactions (50,000)
    final transactions = List.generate(50000, (index) {
       return Transaction(
         id: 'tx_$index',
         accountId: 'acc_1',
         date: DateTime.now(),
         amount: 10.0,
         // Every 100th transaction matches a rule
         memo: index % 100 == 0 ? 'Transaction with keyword_${index % 50}' : 'Generic transaction',
         createdAt: DateTime.now(),
         updatedAt: DateTime.now(),
       );
    });

    // print('Starting benchmark with 50,000 transactions and 50 rules...');
    final stopwatch = Stopwatch()..start();

    final result = await service.applyRules(transactions, rules);

    stopwatch.stop();
    // print('Benchmark complete in ${stopwatch.elapsedMilliseconds}ms');

    // Simple assertion to ensure it actually ran
    expect(result.length, 50000);
    // Verify some matched
    final matchedCount = result.where((t) => t.memo == 'Matched').length;
    // print('Matched transactions: $matchedCount');
    expect(matchedCount, greaterThan(0));
  });
}
