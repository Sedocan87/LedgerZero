import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_platform_file.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'dart:convert';

// parseCsvFile runs its parser through compute(), which runs inline in
// flutter_test.

void main() {
  late CsvImportService service;

  setUp(() {
    service = CsvImportService();
  });

  group('CsvImportService', () {
    test('parseCsvFile parses valid CSV correctly', () async {
      const csvContent = 'Date,Payee,Amount\n2023-01-01,Test Payee,-50.00';
      final file = MemoryPlatformFile(
        name: 'test.csv',
        bytes: utf8.encode(csvContent),
      );

      final result = await service.parseCsvFile(file);

      expect(result.headers, equals(['Date', 'Payee', 'Amount']));
      expect(result.rows.length, equals(1));
      // Numbers are not parsed: cells stay strings.
      expect(result.rows[0], equals(['2023-01-01', 'Test Payee', '-50.00']));
      expect(result.delimiter, equals(','));
    });

    test('parseCsvFile handles semicolons', () async {
      const csvContent = 'Date;Payee;Amount\n2023-01-01;Test Payee;-50,00';
      final file = MemoryPlatformFile(
        name: 'test_semicolon.csv',
        bytes: utf8.encode(csvContent),
      );

      final result = await service.parseCsvFile(file);

      expect(result.headers, equals(['Date', 'Payee', 'Amount']));
      expect(result.delimiter, equals(';'));
    });

    test('validateCsvData returns valid for correct mapping', () {
      final data = CsvImportData(
        headers: ['Date', 'Amount'],
        rows: [
          ['2023-01-01', '-50.00'],
          ['2023-01-02', '100.00'],
        ],
        delimiter: ',',
      );

      final result = service.validateCsvData(
        data: data,
        columnMapping: {'Date': 'Date', 'Amount': 'Amount'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
      );

      expect(result.isValid, isTrue);
    });

    test('validateCsvData detects invalid dates', () {
      final data = CsvImportData(
        headers: ['Date', 'Amount'],
        rows: [
          ['invalid-date', '-50.00'],
        ],
        delimiter: ',',
      );

      final result = service.validateCsvData(
        data: data,
        columnMapping: {'Date': 'Date', 'Amount': 'Amount'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first.kind, CsvIssueKind.invalidDates);
      expect(result.errors.first.count, 1);
    });

    test('convertCsvToTransactions converts correctly', () {
      final data = CsvImportData(
        headers: ['Date', 'Desc', 'Value'],
        rows: [
          ['2023-01-01', 'Store A', '-50.00'],
          ['2023-01-02', 'Job', '1000.00'],
        ],
        delimiter: ',',
      );

      final transactions = service.convertCsvToTransactions(
        data: data,
        columnMapping: {'Date': 'Date', 'Amount': 'Value', 'Payee': 'Desc'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
        outflowIsNegative: true, // Standard: negative is outflow
      );

      expect(transactions.length, equals(2));
      expect(transactions[0].amount, equals(100000)); // Sorted desc date
      expect(transactions[1].amount, equals(-5000));
      expect(transactions[1].payeeName, equals('Store A'));
    });

    test('convertCsvToTransactions parses both decimal styles exactly', () {
      for (final (separator, rows) in [
        (
          ',',
          [
            ['01.02.2023', '-1.234,56'],
            ['02.02.2023', '0,10'],
            ['03.02.2023', '12,50 €'],
          ],
        ),
        (
          '.',
          [
            ['01.02.2023', '-1,234.56'],
            ['02.02.2023', '0.10'],
            ['03.02.2023', r'$12.50'],
          ],
        ),
      ]) {
        final transactions = service.convertCsvToTransactions(
          data: CsvImportData(
            headers: ['Date', 'Amount'],
            rows: rows,
            delimiter: ';',
          ),
          columnMapping: {'Date': 'Date', 'Amount': 'Amount'},
          dateFormat: 'dd.MM.yyyy',
          decimalSeparator: separator,
          outflowIsNegative: true,
        );
        expect(transactions.map((t) => t.amount).toList()..sort(), [
          -123456,
          10,
          1250,
        ], reason: 'decimal separator "$separator"');
        expect(transactions.last.date, DateTime.utc(2023, 2, 1));
      }
    });

    test('checkForDuplicates marks duplicates', () {
      final imported = service.convertCsvToTransactions(
        data: CsvImportData(
          headers: ['Date', 'Payee', 'Amount'],
          rows: [
            ['2023-01-01', 'Store', '-50.00'],
          ],
          delimiter: ',',
        ),
        columnMapping: {'Date': 'Date', 'Amount': 'Amount', 'Payee': 'Payee'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
        outflowIsNegative: true,
      );

      final existing = [
        Transaction(
          id: '1',
          accountId: 'a1',
          date: DateTime(2023, 1, 1),
          amount: -5000,
          payeeId: 'p1', // mapped to 'Store' below
        ),
      ];

      service.checkForDuplicates(
        imported: imported,
        existing: existing,
        payeeMap: {'p1': 'Store'},
      );

      expect(imported[0].isDuplicate, isTrue);
    });

    test('outflowIsNegative off flips the sign of every amount', () {
      // Credit card style: charges positive, refunds/payments negative.
      final transactions = service.convertCsvToTransactions(
        data: CsvImportData(
          headers: ['Date', 'Amount'],
          rows: [
            ['2023-01-01', '50.00'],
            ['2023-01-02', '-20.00'],
          ],
          delimiter: ',',
        ),
        columnMapping: {'Date': 'Date', 'Amount': 'Amount'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
        outflowIsNegative: false,
      );
      expect(transactions.map((t) => t.amount), [2000, -5000]);
    });

    test('the Category column is read and matched to existing categories '
        '(case/whitespace-insensitive, "Group: Category"), never created', () {
      final rows = service.convertCsvToTransactions(
        data: CsvImportData(
          headers: ['Date', 'Amount', 'Category'],
          rows: [
            ['2023-01-06', '-1', '  groceries '],
            ['2023-01-05', '-2', 'food :  Dining   Out'],
            ['2023-01-04', '-3', 'Fun:Other'],
            ['2023-01-03', '-4', 'Other'],
            ['2023-01-02', '-5', 'Unknown'],
            ['2023-01-01', '-6', ''],
          ],
          delimiter: ',',
        ),
        columnMapping: {
          'Date': 'Date',
          'Amount': 'Amount',
          'Category': 'Category',
        },
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
        outflowIsNegative: true,
      );
      expect(rows.first.categoryName, 'groceries');
      expect(rows.last.categoryName, isNull);

      service.assignCategories(
        imported: rows,
        groups: const [
          CategoryGroup(id: 'g-food', name: 'Food'),
          CategoryGroup(id: 'g-fun', name: 'Fun'),
          CategoryGroup(id: 'g-home', name: 'Home'),
        ],
        categories: const [
          Category(id: 'c-groc', name: 'Groceries', categoryGroupId: 'g-food'),
          Category(id: 'c-dine', name: 'Dining Out', categoryGroupId: 'g-food'),
          // "Other" exists twice: only the qualified form is unambiguous.
          Category(id: 'c-fun-other', name: 'Other', categoryGroupId: 'g-fun'),
          Category(
            id: 'c-home-other',
            name: 'Other',
            categoryGroupId: 'g-home',
          ),
        ],
      );

      expect(rows.map((r) => r.categoryId), [
        'c-groc',
        'c-dine',
        'c-fun-other',
        null,
        null,
        null,
      ]);
      expect(rows.map((r) => r.hasUnmatchedCategory), [
        false,
        false,
        false,
        true,
        true,
        false,
      ]);
    });
  });
}
