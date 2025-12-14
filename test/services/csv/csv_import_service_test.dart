import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

// Since compute needs a real isolate, testing CsvImportService.parseCsvFile might fail in standard flutter test environment unless we are careful.
// However, unit tests usually mock compute or it runs synchronously in some test setups.
// But `CsvImportService` calls `compute`.
// A standard way to test logic inside `compute` is to make the logic a static/top-level function (it is: `_parseCsvInternal`) and test that function directly if possible.
// `_parseCsvInternal` is private. We can test `parseCsvFile` and see if `compute` works in test.
// Flutter 2.5+ `flutter_test` supports `compute` running synchronously.
// Let's rely on that.

void main() {
  late CsvImportService service;

  setUp(() {
    service = CsvImportService();
  });

  group('CsvImportService', () {
    test('parseCsvFile parses valid CSV correctly', () async {
      const csvContent = 'Date,Payee,Amount\n2023-01-01,Test Payee,-50.00';
      final file = PlatformFile(
        name: 'test.csv',
        size: csvContent.length,
        bytes: utf8.encode(csvContent),
      );

      final result = await service.parseCsvFile(file);

      expect(result.headers, equals(['Date', 'Payee', 'Amount']));
      expect(result.rows.length, equals(1));
      // CsvToListConverter with shouldParseNumbers: false (default behavior unless we checked)
      // I should check CsvImportService source code.
      // The source code I read says: `shouldParseNumbers: false`
      // So numbers will be strings.
      expect(result.rows[0], equals(['2023-01-01', 'Test Payee', '-50.00']));
      expect(result.delimiter, equals(','));
    });

    test('parseCsvFile handles semicolons', () async {
      const csvContent = 'Date;Payee;Amount\n2023-01-01;Test Payee;-50,00';
      final file = PlatformFile(
        name: 'test_semicolon.csv',
        size: csvContent.length,
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
      expect(result.errors.first, contains('invalid dates'));
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
      expect(transactions[0].amount, equals(1000.00)); // Sorted desc date
      expect(transactions[1].amount, equals(-50.00));
      expect(transactions[1].payeeName, equals('Store A'));
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
          amount: -50.00,
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
  });
}
