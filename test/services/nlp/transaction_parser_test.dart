import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/category.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late TransactionParser parser;
  late MockPayeeRepository mockPayeeRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockParsingHistoryRepository mockHistoryRepo;

  setUp(() {
    mockPayeeRepo = MockPayeeRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockHistoryRepo = MockParsingHistoryRepository();

    parser = TransactionParser(
      mockPayeeRepo,
      mockCategoryRepo,
      mockHistoryRepo,
    );
  });

  group('TransactionParser', () {
    test('extracts amount correctly', () async {
      // Setup minimal mocks to avoid null errors if called
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      final result = await parser.parse('Lunch \$15.50 at McDonalds');
      expect(result.amount, equals(1550)); // minor units
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
      final payee = Payee(
        id: '1',
        name: 'Starbucks',
        createdAt: DateTime.now(),
      );
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => [payee]);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      final result = await parser.parse('Coffee at Starbucks');
      expect(result.payeeName, equals('Starbucks'));
      expect(result.payeeId, equals('1'));
    });

    test('matches known category by name', () async {
      final category = Category(
        id: '1',
        name: 'Dining Out',
        createdAt: DateTime.now(),
      );
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(
        mockCategoryRepo.getAllCategories(),
      ).thenAnswer((_) async => [category]);

      final result = await parser.parse(
        'Dinner at restaurant',
      ); // 'restaurant' maps to 'Dining Out' in keyword map
      expect(result.categoryName, equals('Dining Out'));
      expect(result.categoryId, equals('1'));
    });

    test('detects income keywords', () async {
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);

      final result = await parser.parse('Salary deposit');
      expect(result.isIncome, isTrue);
    });

    group('German input', () {
      setUp(() {
        when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
        when(mockCategoryRepo.getAllCategories()).thenAnswer(
          (_) async => [
            Category(id: 'm', name: 'Mobilität', createdAt: DateTime.now()),
          ],
        );
      });

      test('relative days, amount with comma and category keyword', () async {
        final now = DateTime.now();
        final result = await parser.parse('Tanken 60,50 gestern');
        expect(result.amount, 6050);
        expect(result.categoryId, 'm');
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        expect(
          DateTime(result.date!.year, result.date!.month, result.date!.day),
          yesterday,
        );
      });

      test('"heute morgen" is today, "morgen" is tomorrow', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

        final thisMorning = await parser.parse('Bäcker 4 heute morgen');
        expect(day(thisMorning.date!), today);
        final tomorrow = await parser.parse('Miete 800 morgen');
        expect(day(tomorrow.date!), DateTime(now.year, now.month, now.day + 1));
      });

      test('income keywords', () async {
        expect((await parser.parse('Gehalt 3000')).isIncome, isTrue);
        expect((await parser.parse('Erstattung 20')).isIncome, isTrue);
        expect((await parser.parse('Einkauf 20')).isIncome, isFalse);
      });
    });
  });

  group('extractAmount (minor units)', () {
    test('handles both decimal styles and grouping', () {
      expect(parser.extractAmount(r'Coffee $4.50'), 450);
      expect(parser.extractAmount('Kaffee 12,50€'), 1250);
      expect(parser.extractAmount('Rent 1,200'), 120000);
      expect(parser.extractAmount('Miete 1.234,56'), 123456);
      expect(parser.extractAmount('Taxi 0.1'), 10);
      expect(parser.extractAmount('no amount here'), isNull);
    });
  });

  group('locale-aware amounts', () {
    TransactionParser withSeparator(String separator) => TransactionParser(
      mockPayeeRepo,
      mockCategoryRepo,
      mockHistoryRepo,
      amountParser: MoneyParser(decimalSeparator: separator),
    );

    test('a comma decimal separator reads "1.234" as thousands', () {
      final german = withSeparator(',');
      expect(german.extractAmount('Miete 1.234'), 123400);
      expect(german.extractAmount('Miete 1.234.567'), 123456700);
      expect(german.extractAmount('Kaffee 1,50'), 150);
      expect(german.extractAmount('Miete 1.234,56 €'), 123456);
    });

    test('English behaviour is unchanged', () {
      final english = withSeparator('.');
      expect(english.extractAmount('Rent 1,234'), 123400);
      expect(english.extractAmount(r'Coffee $4.50'), 450);
      expect(english.extractAmount('Rent 1,234.56'), 123456);
      expect(english.extractAmount('Miete 1.234'), 123);
      expect(english.extractAmount('Miete 1.234.567'), 123456700);
      expect(withSeparator(',').extractAmount('Rent 1,234'), 123);
    });
  });

  group('whole-word matching', () {
    test('containsWord respects Unicode word boundaries', () {
      expect(TransactionParser.containsWord('business lunch', 'bus'), isFalse);
      expect(TransactionParser.containsWord('bus ticket', 'bus'), isTrue);
      expect(TransactionParser.containsWord('BUS 2', 'bus'), isTrue);
      expect(TransactionParser.containsWord('Müller 5', 'Müll'), isFalse);
      expect(TransactionParser.containsWord('bei Müller, 5', 'müller'), isTrue);
      expect(TransactionParser.containsWord('Café 3', 'café'), isTrue);
      expect(
        TransactionParser.containsWord('Mario\'s Pizza 9', "mario's pizza"),
        isTrue,
      );
    });

    test('a keyword inside another word does not pick a category', () async {
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer(
        (_) async => [
          Category(id: 't', name: 'Transportation', createdAt: DateTime.now()),
          Category(id: 'd', name: 'Dining Out', createdAt: DateTime.now()),
        ],
      );
      expect((await parser.parse('business card 20')).categoryId, isNull);
      expect((await parser.parse('business lunch 20')).categoryId, 'd');
      expect((await parser.parse('bus 2.80')).categoryId, 't');
    });

    test('a payee name inside another word does not match', () async {
      when(mockPayeeRepo.getAllPayees()).thenAnswer(
        (_) async => [Payee(id: 'p', name: 'Bus', createdAt: DateTime.now())],
      );
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);
      expect((await parser.parse('busy day 5')).payeeId, isNot('p'));
      expect((await parser.parse('Bus 5')).payeeId, 'p');
    });
  });

  group('dates near midnight and amounts next to dates (L1, L6)', () {
    // 01:00 local on 18 Oct: in a UTC+ zone, the UTC day is still 17 Oct.
    final oneAmLocal = DateTime(2025, 10, 18, 1, 0);
    TransactionParser at(DateTime now, {String separator = '.'}) =>
        TransactionParser(
          mockPayeeRepo,
          mockCategoryRepo,
          mockHistoryRepo,
          amountParser: MoneyParser(decimalSeparator: separator),
          now: () => now,
        );

    setUp(() {
      when(mockPayeeRepo.getAllPayees()).thenAnswer((_) async => []);
      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => []);
    });

    test('"yesterday" at 01:00 local is the previous local day', () async {
      final result = await at(oneAmLocal).parse('Taxi yesterday');
      expect(result.date, isNotNull);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2025, 10, 17),
      );
    });

    test('"in 3 days" counts local days and keeps the amount', () async {
      final result = await at(oneAmLocal).parse('in 3 days taxi 12');
      expect(result.amount, 1200);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2025, 10, 21),
      );
    });

    test('a bare number before a day word is the amount, not a time', () async {
      final result = await at(oneAmLocal).parse('Taxi 20 yesterday');
      expect(result.amount, 2000);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2025, 10, 17),
      );
    });

    test('German "gestern" uses the injected clock', () async {
      final result = await at(oneAmLocal).parse('Taxi 20 gestern');
      expect(result.amount, 2000);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2025, 10, 17),
      );
    });

    test('a German date is not the amount (dd.MM.yyyy)', () async {
      final result = await at(
        oneAmLocal,
        separator: ',',
      ).parse('15.10.2023 Essen 12,50');
      expect(result.amount, 1250);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2023, 10, 15),
      );
    });

    test('"15.10." is a date of the current year, "15.10" an amount', () async {
      final parser = at(oneAmLocal, separator: ',');
      final dated = await parser.parse('Essen 15.10. 12,50');
      expect(dated.amount, 1250);
      expect(
        CalendarDate.fromLocalPick(dated.date!),
        DateTime.utc(2025, 10, 15),
      );
      final amountOnly = await parser.parse('Essen 15.10');
      expect(amountOnly.amount, 1510);
    });

    test('a US date is not the amount (MM/dd)', () async {
      final result = await at(oneAmLocal).parse('10/15 lunch 12.50');
      expect(result.amount, 1250);
      expect(
        CalendarDate.fromLocalPick(result.date!),
        DateTime.utc(2025, 10, 15),
      );
    });

    test('a number with decimals beats a bare quantity', () async {
      final result = await at(
        oneAmLocal,
        separator: ',',
      ).parse('2 Kaffee 7,50');
      expect(result.amount, 750);
    });

    test('a currency symbol beats a bare quantity', () async {
      final result = await at(oneAmLocal).parse('3 beers 12€');
      expect(result.amount, 1200);
      expect(result.currency, '€');
    });

    test(
      'a leading minus is accepted; the direction comes from the words',
      () async {
        final refund = await at(oneAmLocal).parse('refund -12.50');
        expect(refund.amount, 1250);
        expect(refund.isIncome, isTrue);
        final coffee = await at(oneAmLocal).parse('coffee -4.50');
        expect(coffee.amount, 450);
        expect(coffee.isIncome, isFalse);
      },
    );

    test('times and ordinals are not amounts', () async {
      expect((await at(oneAmLocal).parse('oct 15th 4')).amount, 400);
      expect((await at(oneAmLocal).parse('dinner at 7pm 32')).amount, 3200);
    });
  });
}
