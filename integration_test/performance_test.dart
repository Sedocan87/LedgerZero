import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('scrolling performance test', (WidgetTester tester) async {
    // Start the app
    await app.main();
    await tester.pumpAndSettle();

    // Scroll the first found ListView
    await binding.traceAction(() async {
      final listFinder = find.byType(ListView).first;
      if (listFinder.evaluate().isNotEmpty) {
        await tester.fling(listFinder, const Offset(0, -500), 1000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scrolling_timeline');
  });
}
