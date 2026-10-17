import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late UndoService undo;
  late TransactionService service;
  late String checking;
  late String savings;
  final day = DateTime.utc(2024, 3, 15);

  setUp(() async {
    t = TestDatabase();
    undo = UndoService();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: undo,
      unitOfWork: t.unitOfWork,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
    );
    checking = (await t.addAccount(name: 'Checking')).id;
    savings = (await t.addAccount(name: 'Savings')).id;
  });

  tearDown(() => t.close());

  Future<Transaction> row(String id) async =>
      (await t.transactions.getTransactionByIdIncludingDeleted(id))!;

  Future<List<Transaction>> allRows() async {
    final ids = (await t.db.select(t.db.transactions).get())
        .map((r) => r.id)
        .toList();
    return t.transactions.getTransactionsByIdsIncludingDeleted(ids);
  }

  group('normal transactions', () {
    test(
      'creates, resolves the payee by name and learns its category',
      () async {
        final groceries = await t.categoryId('Groceries');
        final result = await service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -1250,
            newPayeeName: 'Corner Shop',
            categoryId: groceries,
          ),
        );
        final saved = await row(result.id);
        expect(saved.amount, -1250);
        expect(saved.categoryId, groceries);
        final payee = (await t.payees.getAllPayees()).single;
        expect(payee.name, 'Corner Shop');
        expect(saved.payeeId, payee.id);
        // Learning updates the payee default, it never creates rules.
        expect(payee.autoCategoryId, groceries);
        expect(await t.rules.getRules(), isEmpty);

        // The same name (any case) reuses the payee.
        await service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -100,
            newPayeeName: 'corner shop',
          ),
        );
        expect(await t.payees.getAllPayees(), hasLength(1));
      },
    );

    test('learning never rewrites other transactions', () async {
      final groceries = await t.categoryId('Groceries');
      final first = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -100,
          newPayeeName: 'Shop',
        ),
      );
      await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -200,
          newPayeeName: 'Shop',
          categoryId: groceries,
        ),
      );
      expect((await row(first.id)).categoryId, isNull);
    });

    test('rejects a zero amount', () async {
      expect(
        () => service.save(
          TransactionInput(accountId: checking, date: day, amount: 0),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a failing write leaves nothing behind (unit of work)', () async {
      // The counterpart account does not exist: the FK fails on the second
      // row, so the first row must be rolled back too.
      await expectLater(
        service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -500,
            transferAccountId: 'missing-account',
          ),
        ),
        throwsA(anything),
      );
      expect(await t.db.select(t.db.transactions).get(), isEmpty);
      expect(undo.canUndo, isFalse);
    });

    test('rules only suggest values the user left empty', () async {
      final groceries = await t.categoryId('Groceries');
      final dining = await t.categoryId('Dining Out');
      await t.rules.createRule(
        Rule(
          id: 'r1',
          name: 'Shop',
          priority: 0,
          isActive: true,
          matchLogic: RuleMatchLogic.and,
          conditions: const [
            RuleCondition(
              type: RuleConditionType.payee,
              operator: RuleConditionOperator.contains,
              value: 'shop',
            ),
          ],
          actions: [
            RuleAction(type: RuleActionType.setCategory, value: groceries),
            RuleAction(type: RuleActionType.setAccount, value: savings),
          ],
        ),
      );
      final draft = Transaction(
        id: 'draft',
        accountId: checking,
        date: day,
        amount: -100,
      );
      final suggested = await service.suggestWithRules(
        draft,
        payeeName: 'Corner Shop',
      );
      expect(suggested.categoryId, groceries);
      expect(suggested.accountId, checking, reason: 'never moves the account');

      final chosen = await service.suggestWithRules(
        draft.copyWith(categoryId: dining),
        payeeName: 'Corner Shop',
      );
      expect(chosen.categoryId, dining, reason: 'never overrides the user');
    });
  });

  group('transfers (D4)', () {
    test('creates two legs linked both ways without categories', () async {
      final result = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -50000,
          transferAccountId: savings,
          memo: 'Save',
        ),
      );
      final out = await row(result.id);
      final into = await row(out.transferTransactionId!);
      expect(out.amount, -50000);
      expect(into.amount, 50000);
      expect(out.transferAccountId, savings);
      expect(into.transferAccountId, checking);
      expect(into.transferTransactionId, out.id);
      expect(into.accountId, savings);
      expect(out.categoryId, isNull);
      expect(into.categoryId, isNull);
      expect(into.memo, 'Save');
    });

    test('editing the receiving leg keeps the direction', () async {
      final result = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -50000,
          transferAccountId: savings,
        ),
      );
      final outId = result.id;
      final inId = (await row(outId)).transferTransactionId!;

      // Edit the inflow leg (as the form does when it keeps the loaded
      // leg's sign): +600 into savings.
      await service.save(
        TransactionInput(
          id: inId,
          accountId: savings,
          date: day,
          amount: 60000,
          transferAccountId: checking,
        ),
      );
      expect((await row(inId)).amount, 60000);
      expect((await row(outId)).amount, -60000);
      expect(await t.accounts.getAccountBalance(checking), -60000);
      expect(await t.accounts.getAccountBalance(savings), 60000);
    });

    test('converting a normal transaction into a transfer creates the '
        'counterpart; changing the destination moves it; converting back '
        'deletes it', () async {
      final groceries = await t.categoryId('Groceries');
      final cash = (await t.addAccount(name: 'Cash')).id;
      final result = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -2000,
          categoryId: groceries,
          newPayeeName: 'Shop',
        ),
      );
      final id = result.id;

      await service.save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -2000,
          transferAccountId: savings,
        ),
      );
      var primary = await row(id);
      expect(primary.categoryId, isNull);
      expect(primary.payeeId, isNull);
      final counterpartId = primary.transferTransactionId!;
      var counterpart = await row(counterpartId);
      expect(counterpart.accountId, savings);
      expect(counterpart.amount, 2000);
      expect(counterpart.transferTransactionId, id);

      // New destination: the same counterpart row moves.
      await service.save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -2000,
          transferAccountId: cash,
        ),
      );
      counterpart = await row(counterpartId);
      expect(counterpart.accountId, cash);
      expect(counterpart.isDeleted, isFalse);
      expect(await t.accounts.getAccountBalance(savings), 0);
      expect(await t.accounts.getAccountBalance(cash), 2000);

      // Back to a normal transaction: the counterpart is deleted.
      await service.save(
        TransactionInput(
          id: id,
          accountId: checking,
          date: day,
          amount: -2000,
          categoryId: groceries,
        ),
      );
      primary = await row(id);
      expect(primary.transferAccountId, isNull);
      expect(primary.transferTransactionId, isNull);
      expect(primary.categoryId, groceries);
      expect((await row(counterpartId)).isDeleted, isTrue);
      expect(await t.accounts.getAccountBalance(cash), 0);
    });

    test('rejects a transfer to the same account', () async {
      expect(
        () => service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -1,
            transferAccountId: checking,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('splits', () {
    test('edit diffs children by id and keeps them', () async {
      final groceries = await t.categoryId('Groceries');
      final dining = await t.categoryId('Dining Out');
      final fun = await t.categoryId('Fun Money');
      final created = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -10000,
          splits: [
            SplitLineInput(amount: -6000, categoryId: groceries),
            SplitLineInput(amount: -4000, categoryId: dining),
          ],
        ),
      );
      final children = await t.transactions.getSplitTransactions(created.id);
      final groceriesChild = children.firstWhere(
        (c) => c.categoryId == groceries,
      );
      final diningChild = children.firstWhere((c) => c.categoryId == dining);

      await service.save(
        TransactionInput(
          id: created.id,
          accountId: checking,
          date: day,
          amount: -10000,
          cleared: TransactionClearStatus.cleared,
          splits: [
            SplitLineInput(
              id: groceriesChild.id,
              amount: -7000,
              categoryId: groceries,
            ),
            SplitLineInput(amount: -3000, categoryId: fun),
          ],
        ),
      );
      final after = await t.transactions.getSplitTransactions(created.id);
      expect(after, hasLength(2));
      final kept = after.firstWhere((c) => c.id == groceriesChild.id);
      expect(kept.amount, -7000);
      expect(kept.cleared, TransactionClearStatus.cleared);
      expect((await row(diningChild.id)).isDeleted, isTrue);
      // Exactly one soft-deleted child: no pile-up of re-inserted rows.
      final deleted = (await allRows()).where((r) => r.isDeleted).toList();
      expect(deleted.map((r) => r.id), [diningChild.id]);
      expect((await row(created.id)).categoryId, isNull);
    });

    test('split amounts must add up', () async {
      expect(
        () => service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -10000,
            splits: const [
              SplitLineInput(amount: -6000),
              SplitLineInput(amount: -3000),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'turning a split into a normal transaction deletes the children',
      () async {
        final groceries = await t.categoryId('Groceries');
        final created = await service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -1000,
            splits: [
              SplitLineInput(amount: -500, categoryId: groceries),
              SplitLineInput(amount: -500, categoryId: groceries),
            ],
          ),
        );
        await service.save(
          TransactionInput(
            id: created.id,
            accountId: checking,
            date: day,
            amount: -1000,
            categoryId: groceries,
          ),
        );
        expect(await t.transactions.getSplitTransactions(created.id), isEmpty);
        expect((await row(created.id)).categoryId, groceries);
      },
    );
  });

  group('delete and undo', () {
    test(
      'deleting either transfer leg deletes both; undo restores both',
      () async {
        final created = await service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -500,
            transferAccountId: savings,
          ),
        );
        final inId = (await row(created.id)).transferTransactionId!;

        final action = await service.deleteTransaction(inId);
        expect((await row(created.id)).isDeleted, isTrue);
        expect((await row(inId)).isDeleted, isTrue);

        await undo.undo(action);
        expect((await row(created.id)).isDeleted, isFalse);
        expect((await row(inId)).isDeleted, isFalse);

        await undo.redo();
        expect((await row(created.id)).isDeleted, isTrue);
        expect((await row(inId)).isDeleted, isTrue);
      },
    );

    test('deleting a split line deletes the whole split', () async {
      final groceries = await t.categoryId('Groceries');
      final created = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -1000,
          splits: [
            SplitLineInput(amount: -600, categoryId: groceries),
            SplitLineInput(amount: -400, categoryId: groceries),
          ],
        ),
      );
      final child = (await t.transactions.getSplitTransactions(
        created.id,
      )).first;

      final preview = await service.previewDeletion([child.id]);
      expect(preview.rowCount, 3);
      expect(preview.includesSplit, isTrue);

      await service.deleteTransaction(child.id);
      expect((await row(created.id)).isDeleted, isTrue);
      expect(
        (await allRows()).where((r) => !r.isDeleted),
        isEmpty,
        reason: 'parent and every child are deleted together',
      );
      expect(await t.accounts.getAccountBalance(checking), 0);

      await undo.undo();
      expect(
        await t.transactions.getSplitTransactions(created.id),
        hasLength(2),
      );
      expect(await t.accounts.getAccountBalance(checking), -1000);
    });

    test('bulk delete deletes linked rows and undoes as one action', () async {
      final a = await service.save(
        TransactionInput(accountId: checking, date: day, amount: -100),
      );
      final transfer = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -200,
          transferAccountId: savings,
        ),
      );
      final undoBefore = undo.undoCount;
      await service.deleteMany([a.id, transfer.id]);
      expect(undo.undoCount, undoBefore + 1);
      expect((await allRows()).where((r) => !r.isDeleted), isEmpty);

      await undo.undo();
      expect((await allRows()).where((r) => r.isDeleted), isEmpty);
    });

    test(
      'redo after undoing a create restores the row (no PK conflict)',
      () async {
        final created = await service.save(
          TransactionInput(accountId: checking, date: day, amount: -100),
        );
        await undo.undo();
        expect((await row(created.id)).isDeleted, isTrue);
        await undo.redo();
        expect((await row(created.id)).isDeleted, isFalse);
        expect(await t.accounts.getAccountBalance(checking), -100);
      },
    );

    test('undo of an edit restores the counterpart exactly', () async {
      final created = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -500,
          transferAccountId: savings,
        ),
      );
      final inId = (await row(created.id)).transferTransactionId!;
      await service.save(
        TransactionInput(
          id: created.id,
          accountId: checking,
          date: day,
          amount: -500,
        ),
      );
      expect((await row(inId)).isDeleted, isTrue);

      await undo.undo();
      final restored = await row(created.id);
      expect(restored.transferTransactionId, inId);
      expect((await row(inId)).isDeleted, isFalse);
      expect(await t.accounts.getAccountBalance(savings), 500);
    });
  });

  group('reconciled transactions', () {
    test('editing or deleting needs confirmation', () async {
      final created = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -100,
          cleared: TransactionClearStatus.reconciled,
        ),
      );
      final edit = TransactionInput(
        id: created.id,
        accountId: checking,
        date: day,
        amount: -200,
        cleared: TransactionClearStatus.reconciled,
      );
      await expectLater(
        service.save(edit),
        throwsA(isA<ReconciledTransactionException>()),
      );
      expect((await row(created.id)).amount, -100);
      await service.save(edit, allowReconciledChange: true);
      expect((await row(created.id)).amount, -200);

      await expectLater(
        service.deleteTransaction(created.id),
        throwsA(isA<ReconciledTransactionException>()),
      );
      expect(await service.isReconciled(created.id), isTrue);
      await service.deleteTransaction(created.id, allowReconciledChange: true);
      expect((await row(created.id)).isDeleted, isTrue);
    });

    test('reconcile marks cleared rows up to the statement date and adds an '
        'adjustment only for a difference', () async {
      await t.db.customStatement(
        "UPDATE accounts SET starting_balance = 10000 WHERE id = '$checking'",
      );
      final early = await service.save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 3, 1),
          amount: -1000,
          cleared: TransactionClearStatus.cleared,
        ),
      );
      final late = await service.save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 3, 20),
          amount: -500,
          cleared: TransactionClearStatus.cleared,
        ),
      );
      final uncleared = await service.save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 3, 2),
          amount: -300,
        ),
      );

      Future<int> cleared(String id, DateTime upTo) =>
          t.accounts.getClearedBalance(id, upTo: upTo);

      // Statement matches: 100.00 - 10.00 = 90.00.
      final match = await service.reconcile(
        accountId: checking,
        statementDate: DateTime.utc(2024, 3, 10),
        statementBalance: 9000,
        adjustmentMemo: 'Adjustment',
        clearedBalanceUpTo: cleared,
      );
      expect(match.reconciledCount, 1);
      expect(match.difference, 0);
      expect(match.adjustmentId, isNull);
      expect((await row(early.id)).cleared, TransactionClearStatus.reconciled);
      expect((await row(late.id)).cleared, TransactionClearStatus.cleared);
      expect(
        (await row(uncleared.id)).cleared,
        TransactionClearStatus.uncleared,
      );

      // Statement says 85.00 on Mar 25: 90.00 - 5.00 = 85.00 matches again;
      // 80.00 leaves a -5.00 difference.
      final diff = await service.reconcile(
        accountId: checking,
        statementDate: DateTime.utc(2024, 3, 25),
        statementBalance: 8000,
        adjustmentMemo: 'Adjustment',
        clearedBalanceUpTo: cleared,
      );
      expect(diff.reconciledCount, 1);
      expect(diff.difference, -500);
      final adjustment = await row(diff.adjustmentId!);
      expect(adjustment.amount, -500);
      expect(adjustment.categoryId, isNull);
      expect(adjustment.cleared, TransactionClearStatus.reconciled);
      expect(adjustment.memo, 'Adjustment');
      expect(
        await t.accounts.getClearedBalance(
          checking,
          upTo: DateTime.utc(2024, 3, 25),
        ),
        8000,
      );

      // Undo removes the adjustment and the reconciled marks.
      await undo.undo(diff.action);
      expect((await row(diff.adjustmentId!)).isDeleted, isTrue);
      expect((await row(late.id)).cleared, TransactionClearStatus.cleared);
    });
  });

  group('bulk updates', () {
    test('categorize skips transfer legs and split parents', () async {
      final groceries = await t.categoryId('Groceries');
      final normal = await service.save(
        TransactionInput(accountId: checking, date: day, amount: -100),
      );
      final transfer = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -100,
          transferAccountId: savings,
        ),
      );
      final split = await service.save(
        TransactionInput(
          accountId: checking,
          date: day,
          amount: -100,
          splits: const [
            SplitLineInput(amount: -50),
            SplitLineInput(amount: -50),
          ],
        ),
      );
      await service.bulkCategorize([
        normal.id,
        transfer.id,
        split.id,
      ], groceries);
      expect((await row(normal.id)).categoryId, groceries);
      expect((await row(transfer.id)).categoryId, isNull);
      expect((await row(split.id)).categoryId, isNull);
    });

    test(
      'leaving reconciled through the cleared toggle needs confirmation',
      () async {
        final created = await service.save(
          TransactionInput(
            accountId: checking,
            date: day,
            amount: -100,
            cleared: TransactionClearStatus.reconciled,
          ),
        );
        await expectLater(
          service.updateClearingStatus(
            created.id,
            TransactionClearStatus.cleared,
          ),
          throwsA(isA<ReconciledTransactionException>()),
        );
        await service.updateClearingStatus(
          created.id,
          TransactionClearStatus.cleared,
          allowReconciledChange: true,
        );
        expect((await row(created.id)).cleared, TransactionClearStatus.cleared);
      },
    );
  });

  test('"apply rules to all" never categorises split parents or moves '
      'transfer legs', () async {
    final groceries = await t.categoryId('Groceries');
    final split = await service.save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -100,
        memo: 'match',
        splits: const [
          SplitLineInput(amount: -60, memo: 'match'),
          SplitLineInput(amount: -40, memo: 'match'),
        ],
      ),
    );
    final transfer = await service.save(
      TransactionInput(
        accountId: checking,
        date: day,
        amount: -500,
        memo: 'match',
        transferAccountId: savings,
      ),
    );
    final rule = Rule(
      id: 'r',
      name: 'All',
      priority: 0,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: const [
        RuleCondition(
          type: RuleConditionType.description,
          operator: RuleConditionOperator.equals,
          value: 'match',
        ),
      ],
      actions: [
        RuleAction(type: RuleActionType.setCategory, value: groceries),
        RuleAction(type: RuleActionType.setAccount, value: savings),
      ],
    );
    await RuleMatchingService(
      t.payees,
      t.transactions,
      t.rules,
    ).applyRulesToAllTransactions([rule]);

    final parent = await row(split.id);
    expect(parent.categoryId, isNull);
    expect(parent.accountId, checking);
    for (final child in await t.transactions.getSplitTransactions(split.id)) {
      expect(child.categoryId, groceries);
      expect(child.accountId, checking);
    }
    final leg = await row(transfer.id);
    expect(leg.categoryId, isNull);
    expect(leg.accountId, checking);
  });
}
