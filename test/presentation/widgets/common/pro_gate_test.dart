import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/pro_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/pro_gate.dart';
import 'package:ledger_zero/services/purchases/age_signals.dart';
import 'package:ledger_zero/services/purchases/pro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_age_signals.dart';
import '../../../helpers/fake_pro_store.dart';

void main() {
  late FakeProStore store;
  final results = <bool>[];

  setUp(() {
    store = FakeProStore();
    results.clear();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool unlocked = false,
    AgeSignalsStatus age = AgeSignalsStatus.unknown,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      if (unlocked) ProController.unlockedKey: true,
    });
    store.ownedAnswer = unlocked;
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  const ProBadge(feature: ProFeature.pdfReports),
                  TextButton(
                    onPressed: () async => results.add(
                      await ensureProFeature(
                        context,
                        ref,
                        ProFeature.pdfReports,
                      ),
                    ),
                    child: const Text('Export PDF'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/pro',
          builder: (context, state) => ProScreen(
            feature: ProFeature.values
                .where((f) => f.name == state.uri.queryParameters['feature'])
                .firstOrNull,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          proStoreProvider.overrideWithValue(store),
          ageSignalsGateProvider.overrideWithValue(
            AgeSignalsGate(FakeAgeSignals(age)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unlocked: the feature runs at once, no badge', (tester) async {
    await pump(tester, unlocked: true);
    expect(find.text('PRO'), findsNothing);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    expect(find.byType(ProScreen), findsNothing);
    expect(results, [true]);
  });

  testWidgets('locked: the Pro screen opens; back without buying does not '
      'run the feature', (tester) async {
    await pump(tester);
    expect(find.text('PRO'), findsOneWidget);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    expect(find.byType(ProScreen), findsOneWidget);
    expect(find.text('PDF reports is part of LedgerZero Pro.'), findsOneWidget);
    // Every gated feature is listed.
    for (final feature in ProFeatures.gated) {
      expect(find.byKey(Key('pro.feature.${feature.name}')), findsOneWidget);
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('locked: bought on the Pro screen, Continue runs the feature', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro.buy')));
    await tester.pump();
    store.push(ProPurchaseStatus.purchased);
    await tester.pumpAndSettle();
    expect(find.text('Pro is unlocked. Thank you!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pro.continue')));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.text('PRO'), findsNothing);
  });

  testWidgets('restore that finds nothing says so; one that finds the '
      'purchase unlocks', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pro.restore')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No purchase found for the Google account signed in to the Play '
        'Store.',
      ),
      findsOneWidget,
    );

    store.ownedAnswer = true;
    await tester.tap(find.byKey(const Key('pro.restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro.unlocked')), findsOneWidget);
  });

  testWidgets('without Google Play the screen says so', (tester) async {
    store.available = false;
    await pump(tester);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro.unavailable')), findsOneWidget);
    expect(find.text('Unlock Pro'), findsOneWidget);
  });

  testWidgets('a parent approval that is pending: Buy says so and buys '
      'nothing; Restore still works', (tester) async {
    await pump(tester, age: AgeSignalsStatus.supervisedApprovalPending);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro.buy')));
    await tester.pumpAndSettle();
    expect(store.buyCalls, 0);
    expect(
      find.text(
        "A parent or guardian hasn't approved purchases for this account.",
      ),
      findsOneWidget,
    );

    store.ownedAnswer = true;
    await tester.tap(find.byKey(const Key('pro.restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro.unlocked')), findsOneWidget);
  });

  testWidgets('under 18 (supervised): Buy goes to Google Play, which asks '
      'the parent', (tester) async {
    await pump(tester, age: AgeSignalsStatus.supervised);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro.buy')));
    // The purchase sheet is open: the button shows progress.
    await tester.pump();
    await tester.pump();
    expect(store.buyCalls, 1);
  });
}
