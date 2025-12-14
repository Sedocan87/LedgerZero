import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
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

  Widget createWidget() {
    return ProviderScope(
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
    );
  }

  testWidgets('Validation: Shows error when amount is invalid', (tester) async {
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

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Find save button (check icon in app bar)
    final saveButton = find.widgetWithIcon(IconButton, Icons.check);
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pump();

    // Verify error message
    // Note: Invalid amount validator might return "Please enter a valid amount"
    expect(find.text('Please enter a valid amount'), findsOneWidget);
  });

  testWidgets('Validation: Shows error when account is missing', (
    tester,
  ) async {
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

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Enter valid amount
    await tester.enterText(find.widgetWithText(AppTextField, 'Amount'), '100');
    await tester.pump();

    // Tap save
    final saveButton = find.widgetWithIcon(IconButton, Icons.check);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify snackbar for missing account
    expect(find.text('Please select an account'), findsOneWidget);
  });

  testWidgets('UI: Switches to Transfer form', (tester) async {
    when(mockAccountRepo.watchAllAccounts()).thenAnswer(
      (_) => Stream.value([
        const Account(
          id: '1',
          name: 'Checking',
          type: AccountType.checking,
          startingBalance: 0,
          currentBalance: 0,
        ),
        const Account(
          id: '2',
          name: 'Savings',
          type: AccountType.savings,
          startingBalance: 0,
          currentBalance: 0,
        ),
      ]),
    );
    when(mockPayeeRepo.watchAllPayees()).thenAnswer((_) => Stream.value([]));
    when(
      mockCategoryRepo.watchAllCategories(),
    ).thenAnswer((_) => Stream.value([]));
    when(
      mockCategoryRepo.watchAllCategoryGroups(),
    ).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Find SegmentedButton
    expect(find.text('Transfer'), findsOneWidget);
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    // Should see "To Account" field
    expect(find.text('To Account'), findsOneWidget);

    // Should NOT see Payee
    expect(find.text('Payee'), findsNothing);
  });
}
