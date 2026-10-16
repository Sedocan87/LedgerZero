import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/l10n/app_localizations_en.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../widget_test_helpers.dart';

const _payees = [
  Payee(id: 'p1', name: 'Employer'),
  Payee(id: 'p2', name: 'Landlord'),
  Payee(id: 'p3', name: 'Tenant'),
];

class _PayeeRepository extends Fake implements PayeeRepository {
  @override
  Future<List<Payee>> getAllPayees() async => _payees;

  @override
  Future<Payee?> getPayeeById(String id) async =>
      _payees.where((p) => p.id == id).firstOrNull;
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

class _ScheduledRepository extends Fake
    implements ScheduledTransactionRepository {
  final updated = <ScheduledTransaction>[];

  @override
  Future<void> updateScheduledTransaction(ScheduledTransaction t) async =>
      updated.add(t);
}

class _Transactions extends Fake implements TransactionRepository {}

void main() {
  final l10n = AppLocalizationsEn();
  late SharedPreferences prefs;
  late _ScheduledRepository scheduledRepo;

  final categorisedIncome = ScheduledTransaction(
    id: 'rent-in',
    accountId: 'acc1',
    payeeId: 'p3',
    categoryId: 'c1',
    amount: 80000,
    frequency: RecurrenceFrequency.monthly,
    interval: 1,
    nextDate: DateTime.utc(2024, 1, 1),
    anchorDay: 1,
    memo: 'Flat 2',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduledRepo = _ScheduledRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) => pumpTestWidget(
    tester,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      payeeRepositoryProvider.overrideWithValue(_PayeeRepository()),
      scheduledTransactionRepositoryProvider.overrideWithValue(scheduledRepo),
      // Saving goes through the service (amount validation + reminder).
      scheduledTransactionServiceProvider.overrideWithValue(
        ScheduledTransactionService(
          scheduledRepo,
          _Transactions(),
          _Notifications(),
          unitOfWork: const ImmediateUnitOfWork(),
        ),
      ),
      scheduledTransactionsProvider.overrideWith(
        (ref) => Stream.value([
          ScheduledTransaction(
            id: 'salary',
            accountId: 'acc1',
            payeeId: 'p1',
            amount: 300000,
            frequency: RecurrenceFrequency.monthly,
            interval: 1,
            nextDate: DateTime.utc(2024, 1, 25),
          ),
          categorisedIncome,
          ScheduledTransaction(
            id: 'rent-out',
            accountId: 'acc1',
            payeeId: 'p2',
            categoryId: 'c1',
            amount: -90000,
            frequency: RecurrenceFrequency.monthly,
            interval: 1,
            nextDate: DateTime.utc(2024, 1, 3),
          ),
        ]),
      ),
      accountsProvider.overrideWith(
        (ref) => Stream.value(const [
          Account(id: 'acc1', name: 'Checking', type: AccountType.checking),
        ]),
      ),
      payeesProvider.overrideWith((ref) => Stream.value(_payees)),
      categoriesProvider.overrideWith(
        (ref) => Stream.value(const [Category(id: 'c1', name: 'Housing')]),
      ),
    ],
    child: const IncomeSettingsScreen(),
  );

  testWidgets('lists every inflow schedule, with or without a category', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Employer'), findsOneWidget);
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.textContaining('Housing'), findsOneWidget);
    // Outflows are not income.
    expect(find.text('Landlord'), findsNothing);
    expect(find.text(l10n.incomeEmpty), findsNothing);
  });

  testWidgets('editing a categorised inflow keeps its category and memo', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Tenant'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.incomeEditTitle), findsOneWidget);
    expect(find.text('Tenant'), findsWidgets); // source name loaded
    await tester.ensureVisible(find.text(l10n.incomeSaveButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.incomeSaveButton));
    await tester.pumpAndSettle();

    expect(scheduledRepo.updated, hasLength(1));
    final saved = scheduledRepo.updated.single;
    expect(saved.id, 'rent-in');
    expect(saved.categoryId, 'c1');
    expect(saved.memo, 'Flat 2');
    expect(saved.payeeId, 'p3');
    expect(saved.amount, 80000);
    expect(saved.anchorDay, 1);
  });
}
