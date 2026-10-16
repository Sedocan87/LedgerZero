import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/home/home_empty_state.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Empty States Tests', () {
    testWidgets('HomeEmptyState displays correctly', (tester) async {
      await pumpTestWidget(
        tester,
        child: const Scaffold(body: HomeEmptyState()),
      );

      // The empty state prompts to add an account.
      expect(find.text('Welcome to LedgerZero'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
