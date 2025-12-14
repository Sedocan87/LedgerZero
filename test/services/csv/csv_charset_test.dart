import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  group('CsvImportService Charset', () {
    late CsvImportService service;

    setUp(() {
      service = CsvImportService();
    });

    test('parses Latin-1 encoded file correctly', () async {
      // 'Café' in Latin-1 is [0x43, 0x61, 0x66, 0xE9]
      // 0xE9 in Latin-1 is 'é'. In UTF-8 'é' is [0xC3, 0xA9].
      // So 0xE9 alone is invalid UTF-8.
      final latin1Bytes = [
        ...utf8.encode('Date,Amount,Payee\n2023-01-01,-10.00,'),
        0x43, 0x61, 0x66, 0xE9, // Café
      ];

      final file = PlatformFile(
        name: 'latin1.csv',
        size: latin1Bytes.length,
        bytes: Uint8List.fromList(latin1Bytes),
      );

      final data = await service.parseCsvFile(file);

      expect(data.rows.first[2], 'Café');
    });
  });
}
