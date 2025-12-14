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

      // Verify empty state content
      // It usually prompts to add an account
      expect(find.text('Welcome to LedgerZero'), findsOneWidget);
      // It might be using FilledButton.icon which is still a FilledButton,
      // but maybe widget test needs to find by type specifically or maybe it's using another button type?
      // In the source code: FilledButton.icon.
      // Let's find by icon.
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
