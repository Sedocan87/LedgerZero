import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_platform_file.dart';
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

      final file = MemoryPlatformFile(
        name: 'latin1.csv',
        bytes: Uint8List.fromList(latin1Bytes),
      );

      final data = await service.parseCsvFile(file);

      expect(data.rows.first[2], 'Café');
    });

    test('decodes Windows-1252 bytes 0x80-0x9F (euro sign, quotes)', () async {
      final bytes = [
        ...utf8.encode('Date;Amount;Payee\n2023-01-01;-10,00 '),
        0x80, // €
        0x3B, // ;
        0x93, 0x4D, 0xFC, 0x6C, 0x6C, 0x65, 0x72, 0x94, // “Müller”
      ];
      final data = await service.parseCsvFile(
        MemoryPlatformFile(name: 'cp1252.csv', bytes: bytes),
      );
      expect(data.rows.first[1], '-10,00 €');
      expect(data.rows.first[2], '“Müller”');
    });

    test('drops a UTF-8 byte order mark before the header', () async {
      final bytes = [
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('Date,Amount\n2023-01-01,1 €'),
      ];
      final data = await service.parseCsvFile(
        MemoryPlatformFile(name: 'bom.csv', bytes: bytes),
      );
      expect(data.headers, ['Date', 'Amount']);
      expect(data.rows.first[1], '1 €');
    });
  });
}
