import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/common/animated_count_text.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Animations', () {
    testWidgets('AnimatedCountText shows final value immediately in tests', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(
              body: AnimatedCountText(
                value: 100.0,
                duration: Duration(seconds: 1),
              ),
            ),
          ),
        ),
      );

      // In tests, duration is zero, so it should show 100.00 immediately
      expect(find.text('100.00'), findsOneWidget);
    });

    testWidgets('AnimatedCountText updates when value changes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(body: AnimatedCountText(value: 100.0)),
          ),
        ),
      );

      expect(find.text('100.00'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(body: AnimatedCountText(value: 200.0)),
          ),
        ),
      );

      // Need to pump to let the tween update
      await tester.pumpAndSettle();

      expect(find.text('200.00'), findsOneWidget);
    });
  });
}
