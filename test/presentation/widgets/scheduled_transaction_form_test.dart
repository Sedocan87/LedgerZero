import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/widgets/recurrence/recurrence_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widget_test_helpers.dart';

/// In-memory repository (drift's timers do not mix with fake async).
class _MemoryScheduledRepository extends Fake
    implements ScheduledTransactionRepository {
  final rows = <String, ScheduledTransaction>{};

  @override
  Future<ScheduledTransaction?> getScheduledTransactionById(String id) async =>
      rows[id];

  @override
  Future<void> createScheduledTransaction(ScheduledTransaction t) async =>
      rows[t.id] = t;

  @override
  Future<void> updateScheduledTransaction(ScheduledTransaction t) async =>
      rows[t.id] = t;
}

/// Reminders are not under test here.
class _Notifications extends Fake implements NotificationService {
  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {}
}

class _Transactions extends Fake implements TransactionRepository {}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('RecurrenceSelector', () {
    testWidgets('"on date" defaults to one calendar month after next date', (
      tester,
    ) async {
      DateTime? endDate;
      await pumpTestWidget(
        tester,
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: SingleChildScrollView(
          child: RecurrenceSelector(
            frequency: RecurrenceFrequency.monthly,
            onFrequencyChanged: (_) {},
            interval: 1,
            onIntervalChanged: (_) {},
            endDate: null,
            onEndDateChanged: (value) => endDate = value,
            occurrenceCount: null,
            onOccurrenceCountChanged: (_) {},
            nextDate: DateTime.utc(2024, 1, 31),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<EndCondition>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('On Date').last);
      await tester.pumpAndSettle();

      expect(endDate, DateTime.utc(2024, 2, 29));
    });
  });

  group('AddEditScheduledTransactionScreen', () {
    late _MemoryScheduledRepository repo;

    setUp(() => repo = _MemoryScheduledRepository());

    Future<void> pumpScreen(WidgetTester tester, String? id) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) =>
                    AddEditScheduledTransactionScreen(transactionId: id),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            scheduledTransactionRepositoryProvider.overrideWithValue(repo),
            // Saving goes through the service (validation + reminder).
            scheduledTransactionServiceProvider.overrideWithValue(
              ScheduledTransactionService(
                repo,
                _Transactions(),
                _Notifications(),
                unitOfWork: const ImmediateUnitOfWork(),
              ),
            ),
            accountsProvider.overrideWith(
              (ref) => Stream.value(const [
                Account(
                  id: 'acc1',
                  name: 'Checking',
                  type: AccountType.checking,
                ),
                Account(id: 'acc2', name: 'Savings', type: AccountType.savings),
              ]),
            ),
            payeesProvider.overrideWith(
              (ref) => Stream.value(const [
                Payee(id: 'p1', name: 'Landlord'),
                Payee(id: 'p2', name: 'Gym'),
                Payee(id: 'p3', name: 'Grocer'),
              ]),
            ),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(const [
                Category(id: 'c1', name: 'Rent', categoryGroupId: 'g1'),
                Category(id: 'c2', name: 'Fitness', categoryGroupId: 'g2'),
                Category(id: 'c3', name: 'Food', categoryGroupId: 'g2'),
              ]),
            ),
            categoryGroupsProvider.overrideWith(
              (ref) => Stream.value(const [
                CategoryGroup(id: 'g1', name: 'Bills', sortOrder: 0),
                CategoryGroup(id: 'g2', name: 'Everyday', sortOrder: 1),
              ]),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      unawaited(router.push<void>('/edit'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byIcon(AppIcons.save));
      await tester.pumpAndSettle();
    }

    testWidgets('saves the memo and keeps the loaded anchor day', (
      tester,
    ) async {
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2024, 2, 29),
        anchorDay: 31,
        memo: 'Old memo',
      );
      await pumpScreen(tester, 's1');

      final memoField = find.widgetWithText(TextFormField, 'Memo');
      expect(memoField, findsOneWidget);
      expect(find.text('Old memo'), findsOneWidget);
      await tester.enterText(memoField, '  Rent  ');
      await save(tester);

      final saved = repo.rows['s1']!;
      expect(saved.memo, 'Rent');
      expect(saved.anchorDay, 31);
      expect(saved.nextDate, DateTime.utc(2024, 2, 29));
    });

    testWidgets('an empty memo is saved as null and the anchor defaults to '
        'the day of the next date', (tester) async {
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2024, 1, 30),
        memo: 'x',
      );
      await pumpScreen(tester, 's1');

      await tester.enterText(find.widgetWithText(TextFormField, 'Memo'), ' ');
      await save(tester);

      final saved = repo.rows['s1']!;
      expect(saved.memo, isNull);
      expect(saved.anchorDay, 30);
    });

    Future<void> pickWithSearch(
      WidgetTester tester, {
      required Key field,
      required String query,
      required String pick,
      required List<String> hidden,
    }) async {
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      expect(find.byKey(pickerSearchFieldKey), findsOneWidget);
      await tester.enterText(find.byKey(pickerSearchFieldKey), query);
      await tester.pumpAndSettle();
      for (final name in hidden) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(name),
          ),
          findsNothing,
        );
      }
      // .first: the account picker also shows the localised account type
      // ("Savings") under an account that has the same name.
      await tester.tap(
        find
            .descendant(of: find.byType(BottomSheet), matching: find.text(pick))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    }

    testWidgets('payee, category and account use the searchable pickers', (
      tester,
    ) async {
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2024, 1, 15),
      );
      await pumpScreen(tester, 's1');
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      await pickWithSearch(
        tester,
        field: scheduledPayeeFieldKey,
        query: 'gy',
        pick: 'Gym',
        hidden: ['Landlord', 'Grocer'],
      );
      await pickWithSearch(
        tester,
        field: scheduledCategoryFieldKey,
        query: 'fit',
        pick: 'Fitness',
        hidden: ['Rent', 'Food'],
      );
      await pickWithSearch(
        tester,
        field: scheduledAccountFieldKey,
        query: 'sav',
        pick: 'Savings',
        hidden: ['Checking'],
      );

      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      await save(tester);

      final saved = repo.rows['s1']!;
      expect(saved.payeeId, 'p2');
      expect(saved.categoryId, 'c2');
      expect(saved.accountId, 'acc2');
    });

    group('Outflow | Inflow', () {
      Future<void> createNew(WidgetTester tester, {bool inflow = false}) async {
        await pumpScreen(tester, null);
        expect(find.text('Outflow'), findsOneWidget);
        expect(find.text('Inflow'), findsOneWidget);
        if (inflow) {
          await tester.tap(find.text('Inflow'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byKey(scheduledAmountFieldKey), '800');
        await tester.tap(find.byKey(scheduledAccountFieldKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.text('Checking'),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await save(tester);
      }

      testWidgets('a new schedule is an outflow by default', (tester) async {
        await createNew(tester);
        expect(repo.rows.values.single.amount, -80000);
      });

      testWidgets('an inflow schedule is saved positive', (tester) async {
        await createNew(tester, inflow: true);
        expect(repo.rows.values.single.amount, 80000);
      });

      testWidgets('a typed minus sign does not flip the direction', (
        tester,
      ) async {
        repo.rows['s1'] = ScheduledTransaction(
          id: 's1',
          accountId: 'acc1',
          amount: 5000,
          nextDate: DateTime.utc(2024, 1, 15),
        );
        await pumpScreen(tester, 's1');
        await tester.enterText(find.byKey(scheduledAmountFieldKey), '-20');
        await save(tester);
        expect(repo.rows['s1']!.amount, 2000);
      });

      testWidgets('editing a negative schedule shows Outflow and the '
          'absolute amount', (tester) async {
        repo.rows['s1'] = ScheduledTransaction(
          id: 's1',
          accountId: 'acc1',
          amount: -80000,
          nextDate: DateTime.utc(2024, 1, 15),
        );
        await pumpScreen(tester, 's1');

        final segments = tester.widget<SegmentedButton<bool>>(
          find.byKey(scheduledDirectionKey),
        );
        expect(segments.selected, {false});
        final amount = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(scheduledAmountFieldKey),
            matching: find.byType(TextField),
          ),
        );
        expect(amount.controller!.text, '800.00');

        // Switching to Inflow keeps the amount and flips the sign.
        await tester.tap(find.text('Inflow'));
        await tester.pumpAndSettle();
        await save(tester);
        expect(repo.rows['s1']!.amount, 80000);
      });

      testWidgets('editing a positive schedule shows Inflow', (tester) async {
        repo.rows['s1'] = ScheduledTransaction(
          id: 's1',
          accountId: 'acc1',
          amount: 1250,
          nextDate: DateTime.utc(2024, 1, 15),
        );
        await pumpScreen(tester, 's1');
        expect(
          tester
              .widget<SegmentedButton<bool>>(find.byKey(scheduledDirectionKey))
              .selected,
          {true},
        );
        await save(tester);
        expect(repo.rows['s1']!.amount, 1250);
      });
    });

    testWidgets('a search without matches says so', (tester) async {
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        nextDate: DateTime.utc(2024, 1, 15),
      );
      await pumpScreen(tester, 's1');

      await tester.tap(find.byKey(scheduledPayeeFieldKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(pickerSearchFieldKey), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('a picked category can be cleared', (tester) async {
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        categoryId: 'c1',
        amount: -5000,
        nextDate: DateTime.utc(2024, 1, 15),
      );
      await pumpScreen(tester, 's1');
      expect(find.text('Rent'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(scheduledCategoryFieldKey),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      await save(tester);

      expect(repo.rows['s1']!.categoryId, isNull);
    });

    testWidgets('picking a new next date resets the anchor day', (
      tester,
    ) async {
      // A month inside the picker's range (it starts a year before today).
      final year = DateTime.now().year + 1;
      repo.rows['s1'] = ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(year, 1, 31),
        anchorDay: 31,
      );
      await pumpScreen(tester, 's1');

      await tester.dragUntilVisible(
        find.text('Next Date'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      final saved = repo.rows['s1']!;
      expect(saved.nextDate, DateTime.utc(year, 1, 15));
      expect(saved.anchorDay, 15);
    });

    group('a finished schedule (ledger improvement 4)', () {
      ScheduledTransaction finished() => const ScheduledTransaction(
        id: 's1',
        accountId: 'acc1',
        amount: -5000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        anchorDay: 31,
        memo: 'Old memo',
      );

      Future<void> showNextDate(WidgetTester tester) async {
        await tester.dragUntilVisible(
          find.text('Next Date'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('says so and stays finished when saved', (tester) async {
        repo.rows['s1'] = finished();
        await pumpScreen(tester, 's1');
        await showNextDate(tester);
        expect(
          find.text(
            'Finished: nothing more is booked. Pick a next date to restart it.',
          ),
          findsOneWidget,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Memo'),
          'New memo',
        );
        await save(tester);
        final saved = repo.rows['s1']!;
        expect(saved.memo, 'New memo');
        expect(saved.nextDate, isNull);
        expect(saved.anchorDay, 31);
      });

      testWidgets('a picked next date restarts it', (tester) async {
        final year = DateTime.now().year + 1;
        repo.rows['s1'] = finished();
        await pumpScreen(tester, 's1');
        await showNextDate(tester);
        await tester.tap(find.text('Next Date'));
        await tester.pumpAndSettle();
        // The picker opens on today; move to a month of next year.
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '01/15/$year');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Finished'), findsNothing);
        await save(tester);
        expect(repo.rows['s1']!.nextDate, DateTime.utc(year, 1, 15));
      });
    });
  });
}
