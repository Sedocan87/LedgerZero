import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/extensions/account_extensions.dart';
import 'package:ledger_zero/domain/extensions/budget_extensions.dart';
import 'package:ledger_zero/domain/extensions/transaction_extensions.dart';

import '../fixtures/model_factories.dart';

void main() {
  group('Model Utilities', () {
    group('Validation', () {
      test('Account validation', () {
        final validAccount = createTestAccount();
        expect(validAccount.validate(), isEmpty);

        final invalidAccount = createTestAccount(name: '', currency: 'US');
        final errors = invalidAccount.validate();
        expect(errors, contains('Account name cannot be empty'));
        expect(errors, contains('Currency code must be 3 characters'));
      });

      test('Transaction validation', () {
        final validTx = createTestTransaction();
        expect(validTx.validate(), isEmpty);

        final invalidTx = createTestTransaction(amount: 0);
        final errors = invalidTx.validate();
        expect(errors, contains('Transaction amount cannot be zero'));
      });

      test('Budget validation', () {
        final validBudget = createTestBudget();
        expect(validBudget.validate(), isEmpty);

        final invalidBudget = createTestBudget(month: '2023/10');
        final errors = invalidBudget.validate();
        expect(errors, contains('Month must be in YYYY-MM format'));
      });
    });

    group('Extensions', () {
      test('AccountExtensions', () {
        final checking = createTestAccount(type: AccountType.checking);
        expect(checking.isLiability, false);
        expect(checking.isAsset, true);

        final credit = createTestAccount(type: AccountType.credit);
        expect(credit.isLiability, true);
        expect(credit.isAsset, false);
      });

      test('TransactionExtensions', () {
        final income = createTestTransaction(amount: 10000);
        expect(income.isIncome, true);
        expect(income.isExpense, false);

        final expense = createTestTransaction(amount: -10000);
        expect(expense.isIncome, false);
        expect(expense.isExpense, true);

        final transfer = createTestTransaction(transferAccountId: 'acc2');
        expect(transfer.isTransfer, true);

        final cleared = createTestTransaction(
          cleared: TransactionClearStatus.cleared,
        );
        expect(cleared.isCleared, true);
      });

      test('BudgetExtensions', () {
        final funded = createTestBudget(budgeted: 10000);
        expect(funded.isFunded, true);
      });
    });
  });
}
