import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences with the Reduced Motion setting [reducedMotion].
Future<SharedPreferences> _prefs({bool reducedMotion = false}) async {
  SharedPreferences.setMockInitialValues({
    'reduced_motion_mode': reducedMotion,
  });
  return SharedPreferences.getInstance();
}

/// [child] in a localised app; [disableAnimations] sets the platform flag.
Widget _app(
  SharedPreferences prefs,
  Widget child, {
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appFormatterProvider.overrideWithValue(
        AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

List<TutorialStep> _steps() => [
  TutorialStep(title: 'First', description: 'One'),
  TutorialStep(title: 'Second', description: 'Two'),
];

void main() {
  group('Animations', () {
    for (final (name, reduced, platform) in [
      ('the Reduced Motion setting', true, false),
      ('the platform disableAnimations flag', false, true),
    ]) {
      testWidgets('TutorialOverlay does not animate with $name', (
        tester,
      ) async {
        final prefs = await _prefs(reducedMotion: reduced);
        await tester.pumpWidget(
          _app(
            prefs,
            TutorialOverlay(steps: _steps(), onComplete: () {}),
            disableAnimations: platform,
          ),
        );

        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byType(AnimatedSwitcher), findsNothing);
        expect(find.text('First'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('First'), findsNothing);
        expect(find.text('Finish'), findsOneWidget);
      });
    }

    testWidgets('TutorialOverlay fades in when animations are enabled', (
      tester,
    ) async {
      final prefs = await _prefs();
      var completed = false;
      await tester.pumpWidget(
        _app(
          prefs,
          TutorialOverlay(steps: _steps(), onComplete: () => completed = true),
        ),
      );

      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      expect(completed, isTrue);
    });

    testWidgets('animationsEnabledOf reads the setting without a WidgetRef', (
      tester,
    ) async {
      final results = <bool>[];
      for (final reduced in [false, true]) {
        final prefs = await _prefs(reducedMotion: reduced);
        await tester.pumpWidget(
          _app(
            prefs,
            Builder(
              builder: (context) {
                results.add(animationsEnabledOf(context));
                return const SizedBox();
              },
            ),
          ),
        );
        // A fresh ProviderScope per setting.
        await tester.pumpWidget(const SizedBox());
      }
      expect(results, [true, false]);
    });
  });
}
