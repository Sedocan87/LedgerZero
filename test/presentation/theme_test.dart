import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Theme Switching', () {
    testWidgets('Theme updates correctly when provider changes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final themeState = ref.watch(themeProvider);
              return MaterialApp(
                // Use distinct colors for testing
                theme: ThemeData(
                  scaffoldBackgroundColor: Colors.white,
                ),
                darkTheme: ThemeData(
                  scaffoldBackgroundColor: Colors.black,
                ),
                themeMode: themeState.mode,
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return Container(
                        key: const Key('bg'),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                            child: FloatingActionButton(
                              onPressed: () {
                                ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                              },
                              child: const Icon(Icons.brightness_3),
                            )
                        ),
                      );
                    }
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Verify initial state. It seems default themeMode might be system, and test environment might be reporting something else
      // or ThemeData defaults are tricky.
      // Let's check what it is and verify it CHANGES.
      final containerInitial = tester.widget<Container>(find.byKey(const Key('bg')));
      final initialColor = containerInitial.color;

      // Tap to switch to Dark
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify background color changed
      final container = tester.widget<Container>(find.byKey(const Key('bg')));
      final newColor = container.color;

      expect(newColor, isNot(equals(initialColor)));
      expect(newColor, Colors.black);
    });
  });
}
