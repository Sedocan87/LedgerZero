import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/categories/categories_screen.dart';

import '../../../domain/services/ledger_test_helpers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late String groceries;
  late String dining;
  final month = DateTime.utc(2026, 2);

  setUp(() async {
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    dining = await t.categoryId('Dining Out');
    await t.addAccount(id: 'acc', startingBalance: 100000);
    // A budget row: the old screen failed here with a foreign key error.
    await t.budgeting.setCategoryBudgetedAmount(groceries, 25000, month);
    await t.addTransaction(
      id: 'tx',
      accountId: 'acc',
      amount: -4000,
      date: DateTime.utc(2026, 2, 5),
      categoryId: groceries,
    );
  });

  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openCategoryMenu(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
  }

  Future<void> openGroupMenu(WidgetTester tester, String name) async {
    final header = find.ancestor(
      of: find.text(name),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: header.first, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
  }

  Future<int> budgeted(String categoryId) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        categoryId,
        CalendarDate.monthKey(month),
      ))?.budgeted ??
      0;

  testWidgets('delete without target returns the money to To Be Budgeted', (
    tester,
  ) async {
    await pumpScreen(tester);
    final tbb = await t.budgeting.calculateTBB(month);
    await openCategoryMenu(tester, 'Groceries');

    expect(find.text('Delete "Groceries"?'), findsOneWidget);
    expect(find.text('This category has 1 transaction.'), findsOneWidget);

    await tester.tap(find.text('Delete without replacement'));
    await tester.pumpAndSettle();
    expect(find.textContaining('goes back to To Be Budgeted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deleteCategory.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Category deleted'), findsOneWidget);
    expect(await t.categories.getCategoryById(groceries), isNull);
    expect(await column(t, 'transactions', 'tx', 'category_id'), isNull);
    expect(await t.budgeting.calculateTBB(month), tbb + 25000 - 4000);
    await expectLedgerInvariant(t, month);
    await expectNoForeignKeyViolations(t);

    await unmount(tester);
  });

  testWidgets('delete with target moves budgets and transactions', (
    tester,
  ) async {
    await pumpScreen(tester);
    final tbb = await t.budgeting.calculateTBB(month);
    await openCategoryMenu(tester, 'Groceries');

    // A target is required for the default option.
    final confirm = find.byKey(const Key('deleteCategory.confirm'));
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const Key('deleteCategory.target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quality of Life: Dining Out').last);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(await t.categories.getCategoryById(groceries), isNull);
    expect(await column(t, 'transactions', 'tx', 'category_id'), dining);
    expect(await budgeted(dining), 25000);
    expect(await t.budgeting.calculateTBB(month), tbb);
    await expectLedgerInvariant(t, month);

    await unmount(tester);
  });

  testWidgets('deleting a non-empty group moves its categories', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openGroupMenu(tester, 'Just for Fun');

    expect(find.textContaining('contains 3 categories'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deleteGroup.target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quality of Life').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteGroup.confirm')));
    await tester.pumpAndSettle();

    final groups = await t.categories.getAllCategoryGroups();
    expect(groups.map((g) => g.name), isNot(contains('Just for Fun')));
    final quality = groups.firstWhere((g) => g.name == 'Quality of Life');
    final gaming = await t.categories.getCategoryById(
      await t.categoryId('Gaming'),
    );
    expect(gaming!.categoryGroupId, quality.id);

    await unmount(tester);
  });

  testWidgets('an empty group is deleted after a group confirmation', (
    tester,
  ) async {
    await pumpScreen(tester);
    // Empty the group first.
    final group = (await t.categories.getAllCategoryGroups()).firstWhere(
      (g) => g.name == 'Just for Fun',
    );
    final target = (await t.categories.getAllCategoryGroups()).firstWhere(
      (g) => g.name == 'Quality of Life',
    );
    await t.maintenance.moveCategoriesToGroup(group.id, target.id);
    await tester.pumpAndSettle();

    await openGroupMenu(tester, 'Just for Fun');
    expect(
      find.text('This group contains no categories. Delete it?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(await t.categories.getCategoryGroupById(group.id), isNull);

    await unmount(tester);
  });
}
