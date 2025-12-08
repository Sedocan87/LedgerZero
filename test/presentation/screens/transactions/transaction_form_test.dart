import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/repository_mocks.mocks.dart';
import '../../../widget_test_helpers.dart';

void main() {
  group('Transaction Form Tests', () {
    late MockTransactionRepository mockTransactionRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockPayeeRepository mockPayeeRepository;
    late MockAccountRepository mockAccountRepository;
    late MockScheduledTransactionRepository mockScheduledTransactionRepository;

    setUp(() {
      mockTransactionRepository = MockTransactionRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockPayeeRepository = MockPayeeRepository();
      mockAccountRepository = MockAccountRepository();
      mockScheduledTransactionRepository = MockScheduledTransactionRepository();

      when(mockAccountRepository.watchAllAccounts())
          .thenAnswer((_) => Stream.value([]));
      when(mockCategoryRepository.watchAllCategories())
          .thenAnswer((_) => Stream.value([]));
      when(mockPayeeRepository.watchAllPayees())
          .thenAnswer((_) => Stream.value([]));
    });

    testWidgets('AddEditTransactionScreen renders form fields', (tester) async {
      await pumpTestWidget(
        tester,
        child: const AddEditTransactionScreen(),
        overrides: [
          transactionRepositoryProvider
              .overrideWithValue(mockTransactionRepository),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
          accountRepositoryProvider.overrideWithValue(mockAccountRepository),
          scheduledTransactionRepositoryProvider
              .overrideWithValue(mockScheduledTransactionRepository),
        ],
      );

      // Verify basic fields are present
      expect(find.byType(TextFormField), findsWidgets);
      // We expect Amount field
      expect(find.text('Amount'), findsOneWidget);
      // Note: label text might be localized. 'Amount' is likely in English arb.
    });
  });
}
