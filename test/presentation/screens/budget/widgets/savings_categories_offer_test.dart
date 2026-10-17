import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/savings_categories_offer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

/// testWidgets that disposes the widget tree (and with it the drift stream
/// subscriptions) before the end.
void dbTestWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  final groupId = DeterministicId.defaultGroup(DefaultCategories.savingsGroup);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  /// A budget from before the group existed.
  Future<void> removeSavingsGroup() async {
    for (final c in await t.categories.getAllCategories()) {
      if (c.categoryGroupId == groupId) {
        await t.categories.deleteCategory(c.id);
      }
    }
    await t.categories.deleteCategoryGroup(groupId);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: SavingsCategoriesOffer()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<bool> groupExists(WidgetTester tester) async =>
      (await tester.runAsync(
        () => t.categories.getCategoryGroupById(groupId),
      )) !=
      null;

  dbTestWidgets('hidden when the budget already has the group', (tester) async {
    await pump(tester);
    expect(find.text('Set money aside?'), findsNothing);
  });

  dbTestWidgets('adding creates the group and hides the card for good', (
    tester,
  ) async {
    await tester.runAsync(removeSavingsGroup);
    await pump(tester);
    expect(find.text('Set money aside?'), findsOneWidget);

    await tester.tap(find.text('Add categories'));
    await tester.pumpAndSettle();

    expect(find.text('Set money aside?'), findsNothing);
    expect(prefs.getBool(SavingsCategoriesOffer.handledKey), isTrue);
    expect(await groupExists(tester), isTrue);
  });

  dbTestWidgets('declining hides it without adding anything', (tester) async {
    await tester.runAsync(removeSavingsGroup);
    await pump(tester);

    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    expect(find.text('Set money aside?'), findsNothing);
    expect(prefs.getBool(SavingsCategoriesOffer.handledKey), isTrue);
    expect(await groupExists(tester), isFalse);
  });
}
