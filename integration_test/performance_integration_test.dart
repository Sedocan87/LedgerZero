import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/main.dart' as app;

// Task 804: Performance integration tests
// Tests dashboard scrolling performance.

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Performance: App startup and scrolling', (WidgetTester tester) async {
    // 1. Measure startup
    await app.main();
    await tester.pumpAndSettle();

    // 2. Measure scrolling if a list is present
    final listFinder = find.byType(ListView).first;
    if (listFinder.evaluate().isNotEmpty) {
      await binding.traceAction(
        () async {
          // Scroll down
          await tester.fling(listFinder, const Offset(0, -500), 1000);
          await tester.pumpAndSettle();
          // Scroll up
          await tester.fling(listFinder, const Offset(0, 500), 1000);
          await tester.pumpAndSettle();
        },
        reportKey: 'dashboard_scroll',
      );
    }
  });
}
