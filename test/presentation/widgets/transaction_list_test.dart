import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/repository_mocks.mocks.dart';
import '../../widget_test_helpers.dart';

void main() {
  group('TransactionsScreen Widget Tests', () {
    late MockTransactionRepository mockTransactionRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockPayeeRepository mockPayeeRepository;
    late MockAccountRepository mockAccountRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockTransactionRepository = MockTransactionRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockPayeeRepository = MockPayeeRepository();
      mockAccountRepository = MockAccountRepository();

      // Default stubs for empty responses
      when(mockTransactionRepository.watchTransactions(
        filter: anyNamed('filter'),
        sort: anyNamed('sort'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) => Stream.value([]));

      when(mockCategoryRepository.watchAllCategories())
          .thenAnswer((_) => Stream.value([]));
      when(mockPayeeRepository.watchAllPayees())
          .thenAnswer((_) => Stream.value([]));
      when(mockAccountRepository.watchAllAccounts())
          .thenAnswer((_) => Stream.value([]));
    });

    testWidgets('Shows empty state when no transactions', (tester) async {
      final sharedPreferences = await SharedPreferences.getInstance();

      await pumpTestWidget(
        tester,
        child: const TransactionsScreen(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          transactionRepositoryProvider
              .overrideWithValue(mockTransactionRepository),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
          accountRepositoryProvider.overrideWithValue(mockAccountRepository),
        ],
      );

      // Verify empty state is shown
      expect(find.text('No transactions found'), findsOneWidget);
    });
  });
}
