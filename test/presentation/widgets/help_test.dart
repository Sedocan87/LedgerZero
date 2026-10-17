import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:ledger_zero/presentation/screens/settings/faq_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/user_guide_screen.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ⓘ help sheets, one-time hints, the user guide and the FAQ.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// [home] inside the app's guide route structure, so help sheets can
  /// open the guide.
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Locale locale = const Locale('en'),
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: home),
        ),
        GoRoute(
          path: '/settings/help/user-guide',
          builder: (_, state) => UserGuideScreen(
            initialChapter: GuideChapter.tryParse(
              state.uri.queryParameters['chapter'],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('every topic opens its sheet (${locale.languageCode}, '
        '360 dp)', (tester) async {
      await pump(
        tester,
        ListView(children: [for (final t in HelpTopic.values) InfoButton(t)]),
        locale: locale,
      );
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final topic in HelpTopic.values) {
        final button = find.byKey(Key('info.${topic.name}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byKey(Key('help.${topic.name}')), findsOneWidget);
        expect(find.text(topic.title(l10n)), findsOneWidget);
        for (final step in topic.steps(l10n)) {
          expect(find.text(step), findsOneWidget);
        }
        await tester.ensureVisible(find.text(l10n.gotIt));
        await tester.tap(find.text(l10n.gotIt));
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('a sheet opens the guide at its chapter', (tester) async {
    await pump(tester, const InfoButton(HelpTopic.sync));
    await tester.tap(find.byKey(const Key('info.sync')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open the user guide'));
    await tester.tap(find.text('Open the user guide'));
    await tester.pumpAndSettle();

    final title = find.text('9. Using LedgerZero with a partner');
    expect(title, findsOneWidget);
    // Scrolled to: the chapter's title is on screen.
    expect(tester.getTopLeft(title).dy, lessThan(800));
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(0));
  });

  testWidgets('the guide has every chapter, numbered', (tester) async {
    await pump(tester, const UserGuideScreen(), size: const Size(800, 6000));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final (i, chapter) in GuideChapter.values.indexed) {
      expect(find.text('${i + 1}. ${chapter.title(l10n)}'), findsOneWidget);
    }
  });

  testWidgets('the FAQ no longer mentions a master password', (tester) async {
    await pump(tester, const FaqScreen(), size: const Size(800, 2000));
    expect(find.textContaining('master password'), findsNothing);
    expect(find.text('Can I keep an account to myself?'), findsOneWidget);
    expect(
      find.text('How do I put money into savings or investments?'),
      findsOneWidget,
    );
  });

  group('one-time hint', () {
    Widget hint() => const OneTimeHintCard(
      prefsKey: 'hint_test',
      text: 'A hint',
      topic: HelpTopic.saving,
    );

    testWidgets('"Show me" opens the topic; "Got it" hides it for good', (
      tester,
    ) async {
      await pump(tester, hint());
      await tester.tap(find.text('Show me'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help.saving')), findsOneWidget);
      final sheetGotIt = find.descendant(
        of: find.byKey(const Key('help.saving')),
        matching: find.text('Got it'),
      );
      await tester.ensureVisible(sheetGotIt);
      await tester.tap(sheetGotIt);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('A hint'), findsNothing);
      expect(prefs.getBool('hint_test'), isTrue);

      await pump(tester, hint());
      expect(find.text('A hint'), findsNothing);
    });
  });

  testWidgets('only the Savings & Investments group has an info button', (
    tester,
  ) async {
    CategoryGroup group(String id) =>
        CategoryGroup(id: id, name: 'Group $id', sortOrder: 0);
    await pump(
      tester,
      Column(
        children: [
          BudgetGroupRow(group: group(savingsGroupId)),
          BudgetGroupRow(group: group('other')),
        ],
      ),
    );
    expect(find.byKey(const Key('info.saving')), findsOneWidget);
  });
}
