import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';

@GenerateNiceMocks([MockSpec<PayeeRepository>(), MockSpec<CategoryRepository>()])
import 'transaction_parser_test.mocks.dart';

void main() {
  late TransactionParser parser;
  late MockPayeeRepository mockPayeeRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
    mockCategoryRepository = MockCategoryRepository();
    parser = TransactionParser(mockPayeeRepository, mockCategoryRepository);
  });

  group('TransactionParser - Amount Extraction', () {
    test('extracts simple amount', () {
      expect(parser.extractAmount('Lunch 45.50 at Mario'), 45.50);
    });

    test('extracts amount with dollar sign', () {
      expect(parser.extractAmount(r'Dinner $120.00'), 120.00);
    });

    test('extracts amount with commas', () {
      expect(parser.extractAmount('Laptop 1,200.50'), 1200.50);
    });

    test('extracts amount without integer part', () {
      expect(parser.extractAmount('Candy .99'), 0.99);
    });

    test('extracts integer amount', () {
      expect(parser.extractAmount('Coffee 5'), 5.0);
    });

    test('ignores year in date as amount', () {
      // 2023 should not be extracted, 50 should be
      expect(parser.extractAmount('2023-10-15 Groceries 50'), 50.0);
    });

    test('extracts amount with suffix currency', () {
      expect(parser.extractAmount('Lunch 45€'), 45.0);
    });
  });

  group('TransactionParser - Currency Detection', () {
    test('extracts dollar sign', () {
      expect(parser.extractCurrency('Lunch \$45.50'), '\$');
    });

    test('extracts euro sign', () {
      expect(parser.extractCurrency('Dinner 45€'), '€');
    });

    test('extracts pound sign', () {
      expect(parser.extractCurrency('£50.00 Groceries'), '£');
    });

    test('returns null when no currency found', () {
      expect(parser.extractCurrency('Lunch 45.50'), null);
    });
  });

  group('TransactionParser - Date Parsing', () {
    test('extracts relative date "tomorrow"', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final result = parser.extractDate('Dinner tomorrow');

      expect(result, isNotNull);
      // We only check YMD because time might vary depending on implementation defaults
      expect(result!.year, tomorrow.year);
      expect(result.month, tomorrow.month);
      expect(result.day, tomorrow.day);
    });

    test('extracts absolute date "2023-10-25"', () {
      final result = parser.extractDate('Bill due 2023-10-25');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 10);
      expect(result.day, 25);
    });

    // chrono_dart might parse "friday" relative to now.
    // We can't easily test "next friday" without mocking "now" if the library allows it.
    // Assuming chrono_dart uses system time.

    test('returns null when no date found', () {
      expect(parser.extractDate('Groceries 50'), null);
    });
  });

  group('TransactionParser - Payee Extraction', () {
    test('finds payee with exact name match', () async {
      final payees = [
        const Payee(id: 'p1', name: 'Mario'),
        const Payee(id: 'p2', name: 'Shell'),
      ];
      when(mockPayeeRepository.getAllPayees()).thenAnswer((_) async => payees);

      final result = await parser.extractPayee('Lunch at Mario tomorrow');
      expect(result, isNotNull);
      expect(result!.id, 'p1');
    });

    test('finds payee with partial case-insensitive match', () async {
      final payees = [
        const Payee(id: 'p1', name: 'Mario\'s Pizza'),
      ];
      when(mockPayeeRepository.getAllPayees()).thenAnswer((_) async => payees);

      final result = await parser.extractPayee('dinner at mario\'s pizza 50');
      expect(result, isNotNull);
      expect(result!.name, 'Mario\'s Pizza');
    });

    test('prefers longer match', () async {
      final payees = [
        const Payee(id: 'p1', name: 'Amazon'),
        const Payee(id: 'p2', name: 'Amazon Web Services'),
      ];
      when(mockPayeeRepository.getAllPayees()).thenAnswer((_) async => payees);

      final result = await parser.extractPayee('Bill for Amazon Web Services');
      expect(result, isNotNull);
      expect(result!.name, 'Amazon Web Services');
    });

    test('returns null if no payee found', () async {
      when(mockPayeeRepository.getAllPayees()).thenAnswer((_) async => []);
      final result = await parser.extractPayee('Unknown store 50');
      expect(result, isNull);
    });
  });

  group('TransactionParser - Category Extraction', () {
    const categoryGroceries = Category(
      id: 'c1',
      name: 'Groceries',
      color: 0,
      icon: 'icon',
      createdAt: null,
      targetAmount: 0.0,
      goalType: null,
      targetDate: null,
    );
    const categoryDining = Category(
      id: 'c2',
      name: 'Dining Out',
      color: 0,
      icon: 'icon',
      createdAt: null,
      targetAmount: 0.0,
      goalType: null,
      targetDate: null,
    );

    test('extracts category from payee auto-assign', () async {
      final payee = Payee(id: 'p1', name: 'Walmart', autoCategoryId: 'c1');
      when(mockCategoryRepository.getCategoryById('c1'))
          .thenAnswer((_) async => categoryGroceries);

      final result = await parser.extractCategory('Walmart 50', payee);
      expect(result, isNotNull);
      expect(result!.name, 'Groceries');
    });

    test('extracts category from keywords', () async {
      when(mockCategoryRepository.getAllCategories())
          .thenAnswer((_) async => [categoryGroceries, categoryDining]);

      final result = await parser.extractCategory('Lunch 20', null);
      expect(result, isNotNull);
      expect(result!.name, 'Dining Out'); // "Lunch" maps to Dining Out
    });

    test('extracts category from direct name match', () async {
      when(mockCategoryRepository.getAllCategories())
          .thenAnswer((_) async => [categoryGroceries]);

      final result = await parser.extractCategory('Groceries 100', null);
      expect(result, isNotNull);
      expect(result!.name, 'Groceries');
    });

    test('extracts category with fuzzy match', () async {
      when(mockCategoryRepository.getAllCategories())
          .thenAnswer((_) async => [categoryGroceries]);

      // "Groceris" is misspelt
      final result = await parser.extractCategory('Groceris 50', null);
      expect(result, isNotNull);
      expect(result!.name, 'Groceries');
    });
  });

  group('TransactionParser - Income Detection', () {
    test('detects income from "deposit"', () {
      expect(parser.detectIncome('Bank Deposit 500'), isTrue);
    });

    test('detects income from "refund"', () {
      expect(parser.detectIncome('Refund from store'), isTrue);
    });

    test('detects income from "salary"', () {
      expect(parser.detectIncome('Monthly Salary'), isTrue);
    });

    test('returns false for expense', () {
      expect(parser.detectIncome('Lunch at Mario'), isFalse);
    });
  });

  group('TransactionParser - Confidence Scoring', () {
    test('calculates perfect score for full info', () {
      final score = parser.calculateConfidence(
        50.0,
        DateTime.now(),
        const Payee(id: 'p1', name: 'P'),
        const Category(id: 'c1', name: 'C', color: 0, icon: 'i', createdAt: null, targetAmount: 0, goalType: null, targetDate: null),
      );
      // 0.4 + 0.3 + 0.2 + 0.1 = 1.0
      expect(score, closeTo(1.0, 0.001));
    });

    test('calculates score for amount only', () {
      final score = parser.calculateConfidence(50.0, null, null, null);
      // 0.4
      expect(score, closeTo(0.4, 0.001));
    });

    test('calculates score for amount and payee', () {
      final score = parser.calculateConfidence(
        50.0,
        null,
        const Payee(id: 'p1', name: 'P'),
        null,
      );
      // 0.4 + 0.3 = 0.7
      expect(score, closeTo(0.7, 0.001));
    });
  });
}
