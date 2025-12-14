import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/extensions/account_extensions.dart';
import 'package:ledger_zero/domain/extensions/budget_extensions.dart';
import 'package:ledger_zero/domain/extensions/transaction_extensions.dart';

import '../fixtures/model_factories.dart';

void main() {
  group('Model Utilities', () {
    group('Factories', () {
      test('createTestAccount creates valid account', () {
        final account = createTestAccount(name: 'My Account');
        expect(account.name, 'My Account');
        expect(account.type, AccountType.checking);
      });
      // ... test others briefly
    });

    group('toString', () {
      test('Account.toString', () {
        final account = createTestAccount();
        expect(
          account.toString(),
          contains('Account(id: acc1, name: Test Account'),
        );
      });
      test('Transaction.toString', () {
        final tx = createTestTransaction();
        expect(tx.toString(), contains('Transaction(id: tx1'));
      });
    });

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

        final invalidTx = createTestTransaction(amount: 0.0);
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
        final income = createTestTransaction(amount: 100.0);
        expect(income.isIncome, true);
        expect(income.isExpense, false);

        final expense = createTestTransaction(amount: -100.0);
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
        final overspent = createTestBudget(available: -10.0);
        expect(overspent.isOverspent, true);

        final funded = createTestBudget(budgeted: 100.0);
        expect(funded.isFunded, true);
      });
    });
  });
}
