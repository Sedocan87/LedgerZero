import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  group('CsvImportService', () {
    late CsvImportService service;

    setUp(() {
      service = CsvImportService();
    });

    const csvContentComma = 'Date,Amount,Payee\n2023-01-01,100.0,Store';
    test('parses comma-delimited CSV correctly', () async {
      final bytes = utf8.encode(csvContentComma);
      final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

      final data = await service.parseCsvFile(file);

      expect(data.delimiter, ',');
      expect(data.headers, ['Date', 'Amount', 'Payee']);
      expect(data.rows.length, 1);
      expect(data.rows.first, ['2023-01-01', '100.0', 'Store']);
    });

    const csvContentSemi = 'Date;Amount;Payee\n2023-01-01;100,0;Store';
    test('detects semicolon delimiter', () async {
      final bytes = utf8.encode(csvContentSemi);
      final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

      final data = await service.parseCsvFile(file);

      expect(data.delimiter, ';');
      expect(data.headers, ['Date', 'Amount', 'Payee']);
      expect(data.rows.length, 1);
    });

    test('throws exception on empty file', () async {
       const csvContent = '';
       final bytes = utf8.encode(csvContent);
       final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

       expect(() => service.parseCsvFile(file), throwsA(isA<ImportException>()));
    });

    test('validateCsvData detects missing columns', () {
      final data = CsvImportData(headers: ['A', 'B'], rows: [], delimiter: ',');
      final result = service.validateCsvData(
        data: data,
        columnMapping: {'Date': 'C', 'Amount': 'B'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
      );

      expect(result.isValid, false);
      expect(result.errors.first, contains('Mapped columns not found'));
    });

    test('validateCsvData detects invalid dates', () {
      final data = CsvImportData(
        headers: ['Date', 'Amount'],
        rows: [['invalid-date', '10.0']],
        delimiter: ',',
      );
      final result = service.validateCsvData(
        data: data,
        columnMapping: {'Date': 'Date', 'Amount': 'Amount'},
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
      );

      expect(result.isValid, false);
      expect(result.errors.first, contains('rows have invalid dates'));
    });
  });
}
