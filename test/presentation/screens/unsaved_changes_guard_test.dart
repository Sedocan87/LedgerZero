// The shared unsaved-changes prompt (fourth audit, UI F7) on the editors
// that use it besides the transaction form: schedule, category and rule.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/presentation/screens/rules/add_edit_rule_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/unsaved_changes_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });
  tearDown(() => t.close());

  Finder prompt() => find.byKey(const Key('unsavedChanges.dialog'));
  Finder home() => find.byKey(const Key('home'));

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Opens [screen] on top of a home route.
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('home'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(home());
    await settle(tester);
    expect(home(), findsNothing);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  /// Back asks; Cancel stays on the form; Discard leaves it.
  Future<void> expectAsksBeforeLeaving(WidgetTester tester) async {
    await back(tester);
    expect(prompt(), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);
    expect(prompt(), findsNothing);
    expect(home(), findsNothing);

    await back(tester);
    await tester.tap(find.byKey(const Key('unsavedChanges.discard')));
    await settle(tester);
    expect(home(), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, screen) in <(String, Widget)>[
    ('scheduled transaction', const AddEditScheduledTransactionScreen()),
    ('category', const AddEditCategoryScreen()),
    ('rule', const AddEditRuleScreen()),
  ]) {
    testWidgets('$name editor: back without a change leaves at once', (
      tester,
    ) async {
      await open(tester, screen);
      await back(tester);
      expect(prompt(), findsNothing);
      expect(home(), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('$name editor: back with typed text asks first', (
      tester,
    ) async {
      await open(tester, screen);
      await tester.enterText(find.byType(TextFormField).first, '12');
      await settle(tester);
      await expectAsksBeforeLeaving(tester);
      await unmount(tester);
    });
  }

  testWidgets('scheduled transaction editor: a changed switch counts', (
    tester,
  ) async {
    await open(tester, const AddEditScheduledTransactionScreen());
    await tester.tap(find.text('Inflow'));
    await settle(tester);
    await expectAsksBeforeLeaving(tester);
    await unmount(tester);
  });

  testWidgets('rule editor: an added action counts', (tester) async {
    await open(tester, const AddEditRuleScreen());
    await tester.tap(find.text('Add action'));
    await settle(tester);
    await tester.tap(find.text('Set category').last);
    await settle(tester);
    await tester.tap(find.text('Mark as cleared').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await settle(tester);
    await expectAsksBeforeLeaving(tester);
    await unmount(tester);
  });

  testWidgets('the guard runs onDiscard before it leaves, and passes a '
      'clean form through', (tester) async {
    var discarded = 0;
    var dirty = true;
    await open(
      tester,
      StatefulBuilder(
        builder: (context, setState) => UnsavedChangesGuard(
          dirty: dirty,
          onDiscard: () => discarded++,
          child: Scaffold(
            body: TextButton(
              onPressed: () => setState(() => dirty = false),
              child: const Text('clean'),
            ),
          ),
        ),
      ),
    );
    await back(tester);
    await tester.tap(find.byKey(const Key('unsavedChanges.discard')));
    await settle(tester);
    expect(discarded, 1);
    expect(home(), findsOneWidget);

    dirty = true;
    await tester.tap(home());
    await settle(tester);
    await tester.tap(find.text('clean'));
    await settle(tester);
    await back(tester);
    expect(prompt(), findsNothing);
    expect(discarded, 1);
    expect(home(), findsOneWidget);
  });
}
