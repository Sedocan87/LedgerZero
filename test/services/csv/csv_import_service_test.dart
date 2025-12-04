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

    test('parses comma-delimited CSV correctly', () async {
      final csvContent = 'Date,Amount,Payee\n2023-01-01,100.0,Store';
      final bytes = utf8.encode(csvContent);
      final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

      final data = await service.parseCsvFile(file);

      expect(data.delimiter, ',');
      expect(data.headers, ['Date', 'Amount', 'Payee']);
      expect(data.rows.length, 1);
      expect(data.rows.first, ['2023-01-01', '100.0', 'Store']);
    });

    test('detects semicolon delimiter', () async {
      final csvContent = 'Date;Amount;Payee\n2023-01-01;100,0;Store';
      final bytes = utf8.encode(csvContent);
      final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

      final data = await service.parseCsvFile(file);

      expect(data.delimiter, ';');
      expect(data.headers, ['Date', 'Amount', 'Payee']);
      expect(data.rows.length, 1);
    });

    test('throws exception on empty file', () async {
       final csvContent = '';
       final bytes = utf8.encode(csvContent);
       final file = PlatformFile(name: 'test.csv', size: bytes.length, bytes: Uint8List.fromList(bytes));

       expect(() => service.parseCsvFile(file), throwsA(isA<ImportException>()));
    });
  });
}
