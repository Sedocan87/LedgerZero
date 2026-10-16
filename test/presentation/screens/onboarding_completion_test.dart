import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/presentation/screens/onboarding/completion_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(ProviderContainer, GoRouter)> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/onboarding/completion',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: '/onboarding/completion',
          builder: (context, state) => const CompletionScreen(),
        ),
        GoRoute(
          path: '/accounts/add',
          builder: (context, state) =>
              Text('add-account first=${state.uri.queryParameters['first']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // The app's router is rebuilt when onboarding finishes; the screen
        // navigates with whichever router is current.
        routerProvider.overrideWithValue(router),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, router);
  }

  testWidgets('finishing onboarding opens "create your first account"', (
    tester,
  ) async {
    final (container, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('onboarding.createFirstAccount')));
    await tester.pumpAndSettle();
    expect(container.read(authProvider).isOnboarded, isTrue);
    expect(find.text('add-account first=1'), findsOneWidget);
  });

  testWidgets('"Skip for now" goes to Home', (tester) async {
    final (container, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('onboarding.skipFirstAccount')));
    await tester.pumpAndSettle();
    expect(container.read(authProvider).isOnboarded, isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final state at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    final scale = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).first,
    );
    expect(scale.scale.value, 1.0);
  });
}
