import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/l10n/app_localizations_en.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/scheduled_transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../widget_test_helpers.dart';

class _RecordingRepository extends Fake
    implements ScheduledTransactionRepository {
  final deleted = <String>[];
  bool fail = false;

  @override
  Future<void> deleteScheduledTransaction(String id) async {
    if (fail) {
      throw StateError('disk full');
    }
    deleted.add(id);
  }
}

void main() {
  final l10n = AppLocalizationsEn();
  late SharedPreferences prefs;
  late _RecordingRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _RecordingRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) => pumpTestWidget(
    tester,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      scheduledTransactionRepositoryProvider.overrideWithValue(repo),
      scheduledTransactionsProvider.overrideWith(
        (ref) => Stream.value([
          ScheduledTransaction(
            id: 's1',
            accountId: 'acc1',
            payeeId: 'p1',
            categoryId: 'c1',
            amount: -5000,
            frequency: RecurrenceFrequency.monthly,
            interval: 1,
            nextDate: DateTime.utc(2024, 1, 15),
          ),
        ]),
      ),
      accountsProvider.overrideWith(
        (ref) => Stream.value(const [
          Account(id: 'acc1', name: 'Checking', type: AccountType.checking),
        ]),
      ),
      payeesProvider.overrideWith(
        (ref) => Stream.value(const [Payee(id: 'p1', name: 'Landlord')]),
      ),
      categoriesProvider.overrideWith(
        (ref) => Stream.value(const [Category(id: 'c1', name: 'Rent')]),
      ),
    ],
    child: const ScheduledTransactionsScreen(),
  );

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the delete dialog has its own message and deletes on confirm', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Landlord'), findsWidgets);

    await openDelete(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.scheduledDeleteConfirmation), findsOneWidget);
    expect(find.text(l10n.deleteNoteConfirmationMessage), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, l10n.delete));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.deleted, ['s1']);
  });

  testWidgets('cancel keeps the schedule', (tester) async {
    await pumpScreen(tester);
    await openDelete(tester);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });

  testWidgets('a failed delete shows a friendly message', (tester) async {
    repo.fail = true;
    await pumpScreen(tester);
    await openDelete(tester);
    await tester.tap(find.widgetWithText(TextButton, l10n.delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.scheduledActionFailed), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
  });

  testWidgets('(L3) a schedule whose account is closed is marked', (
    tester,
  ) async {
    await pumpTestWidget(
      tester,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        scheduledTransactionRepositoryProvider.overrideWithValue(repo),
        scheduledTransactionsProvider.overrideWith(
          (ref) => Stream.value([
            ScheduledTransaction(
              id: 's1',
              accountId: 'acc1',
              amount: -5000,
              frequency: RecurrenceFrequency.monthly,
              interval: 1,
              nextDate: DateTime.utc(2024, 1, 15),
            ),
          ]),
        ),
        accountsProvider.overrideWith(
          (ref) => Stream.value(const [
            Account(
              id: 'acc1',
              name: 'Old',
              type: AccountType.checking,
              isClosed: true,
            ),
          ]),
        ),
        payeesProvider.overrideWith((ref) => Stream.value(const [])),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const ScheduledTransactionsScreen(),
    );
    expect(find.byKey(const Key('scheduled.accountClosed.s1')), findsOneWidget);
    expect(find.text(l10n.scheduledAccountClosed), findsOneWidget);
  });
}
