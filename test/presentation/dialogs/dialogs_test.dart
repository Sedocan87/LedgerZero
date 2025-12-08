import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Dialogs and Common Widgets Tests', () {
    testWidgets('ErrorView displays message', (tester) async {
      const message = 'Something went wrong';
      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: ErrorView(
            title: 'Error',
            message: message,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text(message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('ErrorView triggers retry', (tester) async {
      bool retried = false;
      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: ErrorView(
            title: 'Error Title',
            message: 'Error',
            onRetry: () => retried = true,
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
