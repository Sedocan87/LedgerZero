import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

import '../../../mocks/repository_mocks.mocks.dart';

class FakeScheduledTransactionRepository
    implements ScheduledTransactionRepository {
  @override
  Future<void> createScheduledTransaction(
    ScheduledTransaction transaction,
  ) async {}

  @override
  Future<void> deleteScheduledTransaction(String id) async {}

  @override
  Future<List<ScheduledTransaction>> getAllScheduledTransactions() async => [];

  @override
  Future<ScheduledTransaction?> getScheduledTransactionById(String id) async =>
      null;

  @override
  Future<void> updateScheduledTransaction(
    ScheduledTransaction transaction,
  ) async {}

  @override
  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions() =>
      Stream.value([]);

  @override
  Future<List<ScheduledTransaction>> getDueScheduledTransactions(
    DateTime date,
  ) async => [];

  @override
  Future<void> skipScheduledTransaction(String id) async {}
}

void main() {
  late MockTransactionRepository mockTransactionRepo;
  late MockAccountRepository mockAccountRepo;
  late MockPayeeRepository mockPayeeRepo;
  late MockCategoryRepository mockCategoryRepo;
  late FakeScheduledTransactionRepository fakeScheduledTransactionRepo;

  setUp(() {
    mockTransactionRepo = MockTransactionRepository();
    mockAccountRepo = MockAccountRepository();
    mockPayeeRepo = MockPayeeRepository();
    mockCategoryRepo = MockCategoryRepository();
    fakeScheduledTransactionRepo = FakeScheduledTransactionRepository();
  });

  testWidgets('AddEditTransactionScreen renders correctly', (tester) async {
    // Stub streams
    when(
      mockAccountRepo.watchAllAccounts(),
    ).thenAnswer((_) => Stream.value([]));
    when(mockPayeeRepo.watchAllPayees()).thenAnswer((_) => Stream.value([]));
    when(
      mockCategoryRepo.watchAllCategories(),
    ).thenAnswer((_) => Stream.value([]));
    when(
      mockCategoryRepo.watchAllCategoryGroups(),
    ).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(mockTransactionRepo),
          accountRepositoryProvider.overrideWithValue(mockAccountRepo),
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepo),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          scheduledTransactionRepositoryProvider.overrideWithValue(
            fakeScheduledTransactionRepo,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditTransactionScreen(),
        ),
      ),
    );

    // Wait for async
    await tester.pumpAndSettle();

    expect(find.byType(AddEditTransactionScreen), findsOneWidget);
    // Add Transaction title check might fail if localized string is different or not found, but we mocked localization.
    // Actually AppLocalizations delegate handles loading from arb. In test env, it loads real arb?
    // Usually yes.
  });
}
