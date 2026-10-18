import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/startup_error_app.dart';

void main() {
  testWidgets('explains the failure and retries on request', (tester) async {
    var retries = 0;
    await tester.pumpWidget(StartupErrorApp(onRetry: () => retries++));
    await tester.pumpAndSettle();
    expect(find.text('LedgerZero could not start'), findsOneWidget);
    await tester.tap(find.byKey(const Key('startup.retry')));
    expect(retries, 1);
  });
}
