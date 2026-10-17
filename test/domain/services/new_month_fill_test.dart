import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

import '../../helpers/sync_simulation.dart';
import '../../helpers/test_database.dart';

/// Filling a new month from the month before or a template: only empty
/// categories, and an automatic fill never beats an edit made by hand.
void main() {
  final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
  final previous = DateTime.utc(month.year, month.month - 1, 1);

  group('on one phone', () {
    late TestDatabase t;
    late BudgetingService budgeting;
    late String groceries;
    late String rent;

    setUp(() async {
      t = TestDatabase();
      budgeting = t.budgeting;
      groceries = await t.categoryId('Groceries');
      rent = await t.categoryId('Rent/Mortgage');
    });

    tearDown(() => t.close());

    Future<int> budgeted(String categoryId, [DateTime? m]) async =>
        (await t.budgets.getBudgetByCategoryAndMonth(
          categoryId,
          CalendarDate.monthKey(m ?? month),
        ))?.budgeted ??
        0;

    test('the month before: positive amounts only', () async {
      await budgeting.setCategoryBudgetedAmount(groceries, 30000, previous);
      await budgeting.setCategoryBudgetedAmount(rent, 0, previous);
      expect(await budgeting.budgetsOfPreviousMonth(month), {groceries: 30000});
    });

    test('a month is empty while every category is zero', () async {
      expect(await budgeting.isMonthEmpty(month), isTrue);
      await budgeting.setCategoryBudgetedAmount(rent, 0, month);
      expect(await budgeting.isMonthEmpty(month), isTrue);
      await budgeting.setCategoryBudgetedAmount(rent, 100000, month);
      expect(await budgeting.isMonthEmpty(month), isFalse);
    });

    test(
      'fills only empty, visible categories and reports what it wrote',
      () async {
        await budgeting.setCategoryBudgetedAmount(rent, 95000, month);
        final hidden = await t.categoryId('Electric');
        final electric = (await t.categories.getCategoryById(hidden))!;
        await t.categories.updateCategory(electric.copyWith(isHidden: true));

        final filled = await budgeting.fillEmptyCategories(month, {
          groceries: 30000,
          rent: 100000,
          hidden: 5000,
          'deleted-category': 1000,
          await t.categoryId('Water'): 0,
        });

        expect(filled, {groceries: 30000});
        expect(await budgeted(groceries), 30000);
        expect(await budgeted(rent), 95000);
        expect(await budgeted(hidden), 0);
      },
    );

    test('an automatic fill is stamped with the start of the month and '
        'leaves categories set this month alone', () async {
      // Set to zero on purpose during the month.
      await budgeting.setCategoryBudgetedAmount(rent, 0, month);
      final stamp = BudgetingService.automaticFillStamp(month);

      final filled = await budgeting.fillEmptyCategories(month, {
        groceries: 30000,
        rent: 100000,
      }, stampedAt: stamp);

      expect(filled, {groceries: 30000});
      final row = await t.budgets.getBudgetByCategoryAndMonth(
        groceries,
        CalendarDate.monthKey(month),
      );
      expect(row!.updatedAt, stamp);
      expect(await budgeted(rent), 0);
    });

    test(
      'undo resets the filled categories, except ones changed since',
      () async {
        final filled = await budgeting.fillEmptyCategories(month, {
          groceries: 30000,
          rent: 100000,
        });
        await budgeting.setCategoryBudgetedAmount(rent, 110000, month);

        await budgeting.undoFill(month, filled);

        expect(await budgeted(groceries), 0);
        expect(await budgeted(rent), 110000);
      },
    );
  });

  group('on two phones', () {
    late FakeSyncFolder folder;
    late SimDevice a;
    late SimDevice b;

    setUp(() async {
      folder = FakeSyncFolder();
      a = await SimDevice.create(folder);
      b = await SimDevice.create(folder);
      await a.engine.createSyncFolder('correct horse battery staple');
      await b.engine.joinSyncFolder('correct horse battery staple');
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    Future<int> budgeted(SimDevice d, String categoryId) async =>
        (await d.t!.budgets.getBudgetByCategoryAndMonth(
          categoryId,
          CalendarDate.monthKey(month),
        ))?.budgeted ??
        0;

    test('a hand edit on one phone beats the other phone\'s later automatic '
        'fill, without a conflict entry', () async {
      final groceries = await a.t!.categoryId('Groceries');
      final rent = await a.t!.categoryId('Rent/Mortgage');
      await a.t!.budgeting.setCategoryBudgetedAmount(
        groceries,
        30000,
        previous,
      );
      await a.t!.budgeting.setCategoryBudgetedAmount(rent, 100000, previous);
      await syncAll([a, b]);
      final stamp = BudgetingService.automaticFillStamp(month);

      // A opens the new month first, fills it and changes Groceries.
      await a.t!.budgeting.fillEmptyCategories(
        month,
        await a.t!.budgeting.budgetsOfPreviousMonth(month),
        stampedAt: stamp,
      );
      await a.t!.budgeting.setCategoryBudgetedAmount(groceries, 35000, month);
      await a.sync();

      // B opens it before it has synced: it fills the month too.
      await b.t!.budgeting.fillEmptyCategories(
        month,
        await b.t!.budgeting.budgetsOfPreviousMonth(month),
        stampedAt: stamp,
      );
      await syncAll([a, b]);

      for (final d in [a, b]) {
        expect(await budgeted(d, groceries), 35000);
        expect(await budgeted(d, rent), 100000);
        expect(await d.db.syncDao.getConflicts(), isEmpty);
      }
    });
  });
}
