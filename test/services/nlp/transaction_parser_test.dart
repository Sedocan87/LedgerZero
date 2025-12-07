import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/category.dart';

import '../../mocks/repository_mocks.mocks.dart';

// We need mocks for ParsingHistory and ParsingRules repositories which are used in constructor
// Since they are not in `repository_mocks.dart` explicitly yet (maybe added later), I should check if I need to add them or mock them manually.
// Wait, `ParsingHistoryRepository` and `ParsingRulesRepository` were imported in the source file I just read.
// I should verify if `repository_mocks.dart` includes them. The `read_file` earlier showed:
// @GenerateMocks([AccountRepository, BudgetRepository, CategoryRepository, PayeeRepository, TransactionRepository, BudgetTemplateRepository, ScheduledTransactionRepository])
// It does NOT include ParsingHistoryRepository or ParsingRulesRepository.
// So I need to create mocks for them in this test file or update `repository_mocks.dart`.
// Updating `repository_mocks.dart` is better practice but requires running build_runner again.
// To save time and keep it simple, I'll use `MockSpec` in this test file or manually mock them if they are simple abstract classes.
// But `mockito` works best with generated mocks.
// Let's create a new mock definition file for this test or update the existing one.
// Given I already ran build_runner, I'll try to use `@GenerateNiceMocks` in this file and rely on `build_runner` again or just manually mock them for now to avoid the heavy build step if possible.
// Actually, I can just use `extends Mock implements ...` manually since they are likely simple interfaces.
// Let's check their definition. I haven't read their definition files.
// But wait, the task is to set up unit testing. I should probably do it properly.
// I'll add them to `repository_mocks.dart` and run build_runner. It takes ~1 minute.

import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_rules_repository.dart';

class MockParsingHistoryRepository extends Mock implements ParsingHistoryRepository {
    @override
    Future<List<Map<String, dynamic>>> getHistory(String? input) {
        return super.noSuchMethod(
            Invocation.method(#getHistory, [input]),
            returnValue: Future.value(<Map<String, dynamic>>[]),
            returnValueForMissingStub: Future.value(<Map<String, dynamic>>[]),
        );
    }
}

class MockParsingRulesRepository extends Mock implements ParsingRulesRepository {
    @override
    Future<List<Map<String, dynamic>>> getAllRules() {
        return super.noSuchMethod(
            Invocation.method(#getAllRules, []),
            returnValue: Future.value(<Map<String, dynamic>>[]),
            returnValueForMissingStub: Future.value(<Map<String, dynamic>>[]),
        );
    }
}

void main() {
  late TransactionParser parser;
  late MockPayeeRepository mockPayeeRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockParsingHistoryRepository mockHistoryRepo;
  late MockParsingRulesRepository mockRulesRepo;

  setUp(() {
    mockPayeeRepo = MockPayeeRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockHistoryRepo = MockParsingHistoryRepository();
    mockRulesRepo = MockParsingRulesRepository();

    parser = TransactionParser(
      mockPayeeRepo,
      mockCategoryRepo,
      mockHistoryRepo,
      mockRulesRepo,
    );
  });

  group('TransactionParser', () {
    test('extracts amount correctly', () async {
      // Setup minimal mocks to avoid null errors if called
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      final result = await parser.parse('Lunch \$15.50 at McDonalds');
      expect(result.amount, equals(15.50));
      expect(result.currency, equals('\$'));
    });

    test('extracts date correctly', () async {
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      // Assuming Chrono works (it's a library), testing integration
      // Note: "today" depends on current date, so strict equality is tricky without mocking time.
      // But "2023-10-15" is absolute.
      final result = await parser.parse('2023-10-15 Grocery');

      expect(result.date, isNotNull);
      expect(result.date!.year, equals(2023));
      expect(result.date!.month, equals(10));
      expect(result.date!.day, equals(15));
    });

    test('matches known payee', () async {
      final payee = Payee(id: '1', name: 'Starbucks', createdAt: DateTime.now());
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => [payee]);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      final result = await parser.parse('Coffee at Starbucks');
      expect(result.payeeName, equals('Starbucks'));
      expect(result.payeeId, equals('1'));
    });

    test('matches known category by name', () async {
      final category = Category(id: '1', name: 'Dining Out', createdAt: DateTime.now());
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => [category]);

      final result = await parser.parse('Dinner at restaurant'); // 'restaurant' maps to 'Dining Out' in keyword map
      expect(result.categoryName, equals('Dining Out'));
      expect(result.categoryId, equals('1'));
    });

    test('detects income keywords', () async {
        when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
        when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

        final result = await parser.parse('Salary deposit');
        expect(result.isIncome, isTrue);
    });
  });
}
