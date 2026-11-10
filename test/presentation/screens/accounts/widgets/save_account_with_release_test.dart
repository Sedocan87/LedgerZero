// saveAccountWithRelease is shared by the account form and the budget
// currency warning's "Take off budget". A credit card that leaves the
// budget gives its payment category's money back to To Be Budgeted in the
// same unit of work (docs/BUDGETING_RULES.md, "Credit cards").
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/leave_budget_dialog.dart';

import '../../../../helpers/test_database.dart';

void main() {
  testWidgets('a card taken off the budget releases its payment category', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final t = TestDatabase();
    addTearDown(() => tester.runAsync(t.close));
    final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
    final card = (await tester.runAsync(() async {
      await t.addAccount(name: 'Checking', startingBalance: 100000);
      final card = await t.addAccount(name: 'Visa', type: AccountType.credit);
      await t.budgeting.setCategoryBudgetedAmount(
        CardPayments.categoryId(card.id),
        15000,
        month,
      );
      return card;
    }))!;
    final tbbBefore = (await tester.runAsync(
      () => t.budgeting.calculateTBB(month),
    ))!;

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(t.db)],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    final released = (await tester.runAsync(
      () => saveAccountWithRelease(
        widgetRef,
        card.copyWith(onBudget: false),
        const {},
      ),
    ))!;
    expect(released, 15000);
    final tbbAfter = (await tester.runAsync(
      () => t.budgeting.calculateTBB(month),
    ))!;
    expect(tbbAfter, tbbBefore + 15000);
    final payment = (await tester.runAsync(
      () => t.categories.getCategoryById(CardPayments.categoryId(card.id)),
    ))!;
    expect(payment.isHidden, isTrue);
  });
}
