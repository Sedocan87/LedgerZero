// Credit-card payment categories: deterministic ids, lifecycle with the
// account, self-heal, protection (see docs/BUDGETING_RULES.md, "Credit
// cards").
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/services/category_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  Future<Map<String, Object?>?> paymentRow(String accountId) async {
    final c = await t.categories.getCategoryById(
      CardPayments.categoryId(accountId),
    );
    if (c == null) {
      return null;
    }
    return {'name': c.name, 'group': c.categoryGroupId, 'hidden': c.isHidden};
  }

  test('ids are derived from the account id', () {
    expect(
      DeterministicId.cardPayment('acc-1'),
      DeterministicId.cardPayment('acc-1'),
    );
    expect(
      DeterministicId.cardPayment('acc-1'),
      isNot(DeterministicId.cardPayment('acc-2')),
    );
    expect(CardPayments.groupId, DeterministicId.cardPaymentGroup);
    expect(
      DeterministicId.cardPaymentGroup,
      isNot(DeterministicId.defaultGroup('Credit Card Payments')),
    );
  });

  test('a budget credit card gets its payment category in the group, named '
      'like the card; other accounts get none', () async {
    final card = await t.addAccount(name: 'Visa', type: AccountType.credit);
    await t.addAccount(name: 'Checking');
    await t.addAccount(
      name: 'Tracked card',
      type: AccountType.credit,
      onBudget: false,
    );
    await t.addAccount(
      name: 'My card',
      type: AccountType.credit,
      owner: AccountOwner.me,
    );

    expect(await paymentRow(card.id), {
      'name': 'Visa',
      'group': CardPayments.groupId,
      'hidden': false,
    });
    final group = await t.categories.getCategoryGroupById(CardPayments.groupId);
    expect(group!.name, 'Credit Card Payments');
    final inGroup = (await t.categories.getAllCategories())
        .where((c) => c.categoryGroupId == CardPayments.groupId)
        .toList();
    expect(inGroup.map((c) => c.name), ['Visa']);
  });

  test('the group is named in the app language', () async {
    await t.close();
    t = TestDatabase(
      seedName: (english) =>
          english == 'Credit Card Payments' ? 'Kreditkartenzahlungen' : english,
    );
    await t.addAccount(name: 'Visa', type: AccountType.credit);
    final group = await t.categories.getCategoryGroupById(CardPayments.groupId);
    expect(group!.name, 'Kreditkartenzahlungen');
  });

  test('the category follows the account: rename, close, reopen, off '
      'budget, type change', () async {
    final card = await t.addAccount(name: 'Visa', type: AccountType.credit);
    Future<void> update(Account Function(Account) change) async {
      final current = (await t.accounts.getAccountById(card.id))!;
      await t.accounts.updateAccount(change(current));
    }

    await update((a) => a.copyWith(name: 'Visa Gold'));
    expect((await paymentRow(card.id))!['name'], 'Visa Gold');

    await update((a) => a.copyWith(isClosed: true));
    expect((await paymentRow(card.id))!['hidden'], isTrue);
    await update((a) => a.copyWith(isClosed: false));
    expect((await paymentRow(card.id))!['hidden'], isFalse);

    await update((a) => a.copyWith(onBudget: false));
    expect((await paymentRow(card.id))!['hidden'], isTrue);
    await update((a) => a.copyWith(onBudget: true));
    expect((await paymentRow(card.id))!['hidden'], isFalse);

    await update((a) => a.copyWith(type: AccountType.checking));
    expect((await paymentRow(card.id))!['hidden'], isTrue);
    await update((a) => a.copyWith(type: AccountType.credit));
    expect((await paymentRow(card.id))!['hidden'], isFalse);

    // An account that becomes a budget card later gets one then.
    final checking = await t.addAccount(name: 'Wallet');
    expect(await paymentRow(checking.id), isNull);
    await t.accounts.updateAccount(checking.copyWith(type: AccountType.credit));
    expect((await paymentRow(checking.id))!['name'], 'Wallet');
  });

  test('self-heal creates missing rows with the fixed old stamp, repairs '
      'moved or renamed ones and is idempotent', () async {
    final card = await t.addAccount(name: 'Visa', type: AccountType.credit);
    final id = CardPayments.categoryId(card.id);
    // As if the account arrived without its category (older data).
    await t.db.customStatement('DELETE FROM categories WHERE id = ?', [id]);

    await t.categories.syncCardPaymentCategories(
      stampedAt: cardPaymentHealStamp,
    );
    final row = await t.db
        .customSelect(
          'SELECT name, updated_at, created_at FROM categories WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    expect(row.read<String>('name'), 'Visa');
    expect(
      DateTime.parse(row.read<String>('updated_at')),
      cardPaymentHealStamp,
    );
    expect(
      DateTime.parse(row.read<String>('created_at')),
      cardPaymentHealStamp,
    );

    // Renamed by hand and moved to another group: healed back.
    final other = (await t.categories.getAllCategoryGroups()).first;
    final c = (await t.categories.getCategoryById(id))!;
    await t.categories.updateCategory(
      c.copyWith(name: 'Something', categoryGroupId: other.id),
    );
    expect(
      await t.db.categoriesDao.syncCardPaymentCategories(
        stampedAt: cardPaymentHealStamp,
      ),
      1,
    );
    expect(await paymentRow(card.id), {
      'name': 'Visa',
      'group': CardPayments.groupId,
      'hidden': false,
    });
    expect(
      await t.db.categoriesDao.syncCardPaymentCategories(
        stampedAt: cardPaymentHealStamp,
      ),
      0,
    );
  });

  group('protection', () {
    late String card;
    late TransactionService service;
    late CategoryService categories;

    setUp(() async {
      card = (await t.addAccount(name: 'Visa', type: AccountType.credit)).id;
      service = TransactionService(
        transactionRepository: t.transactions,
        payeeRepository: t.payees,
        accountRepository: t.accounts,
        undoService: UndoService(),
        unitOfWork: t.unitOfWork,
        ruleMatchingService: RuleMatchingService(
          t.payees,
          t.transactions,
          t.rules,
        ),
      );
      categories = CategoryService(
        categoryRepository: t.categories,
        maintenance: t.maintenance,
        ruleRepository: t.rules,
        unitOfWork: t.unitOfWork,
        accountRepository: t.accounts,
      );
    });

    test('a transaction cannot be categorised into a payment category, nor '
        'a split line', () async {
      final checking = (await t.addAccount(name: 'Checking')).id;
      final payment = CardPayments.categoryId(card);
      final groceries = await t.categoryId('Groceries');
      Future<void> save(TransactionInput input) => expectLater(
        service.save(input),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            TransactionValidationError.paymentCategory,
          ),
        ),
      );
      await save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 1, 5),
          amount: -1000,
          categoryId: payment,
        ),
      );
      await save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 1, 5),
          amount: -3000,
          splits: [
            SplitLineInput(amount: -1000, categoryId: groceries),
            SplitLineInput(amount: -2000, categoryId: payment),
          ],
        ),
      );
      expect(await t.transactions.getAllTransactions(), isEmpty);
    });

    test('the payment category of an open budget card and its group cannot '
        'be deleted; after closing the card it can', () async {
      final payment = CardPayments.categoryId(card);
      await expectLater(
        categories.deleteCategory(payment, reassignTo: null),
        throwsA(isA<PaymentCategoryProtectedException>()),
      );
      final groceries = await t.categoryId('Groceries');
      await expectLater(
        categories.deleteCategory(groceries, reassignTo: payment),
        throwsA(isA<PaymentCategoryProtectedException>()),
      );
      final other = (await t.categories.getAllCategoryGroups())
          .firstWhere((g) => g.id != CardPayments.groupId)
          .id;
      await expectLater(
        categories.deleteCategoryGroup(
          CardPayments.groupId,
          moveCategoriesTo: other,
        ),
        throwsA(isA<PaymentCategoryProtectedException>()),
      );
      await expectLater(
        categories.deleteCategoryGroup(
          other,
          moveCategoriesTo: CardPayments.groupId,
        ),
        throwsA(isA<PaymentCategoryProtectedException>()),
      );
      expect(await t.categories.getCategoryById(payment), isNotNull);

      final account = (await t.accounts.getAccountById(card))!;
      await t.accounts.updateAccount(account.copyWith(isClosed: true));
      await categories.deleteCategory(payment, reassignTo: null);
      expect(await t.categories.getCategoryById(payment), isNull);
    });
  });
}
