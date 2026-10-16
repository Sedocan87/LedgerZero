import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';
import '../../../widget_test_helpers.dart';

void main() {
  testWidgets('an amount of zero is rejected by the form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);

    await pumpTestWidget(
      tester,
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AddEditScheduledTransactionScreen(),
    );

    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('The amount cannot be zero.'), findsOneWidget);
    expect(
      await t.scheduledTransactions.getAllScheduledTransactions(),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
