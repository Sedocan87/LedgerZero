import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_platform_file.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  group('CsvImportService Large File', () {
    late CsvImportService service;

    setUp(() {
      service = CsvImportService();
    });

    test('parses large CSV file (10,000 rows) efficiently', () async {
      final sb = StringBuffer();
      sb.writeln('Date,Amount,Payee,Memo');
      for (int i = 0; i < 10000; i++) {
        sb.writeln('2023-01-01,${(i + 1) * 1.0},Payee $i,Memo $i');
      }
      final csvContent = sb.toString();
      final bytes = utf8.encode(csvContent);
      final file = MemoryPlatformFile(
        name: 'large.csv',
        bytes: Uint8List.fromList(bytes),
      );

      final stopwatch = Stopwatch()..start();
      final data = await service.parseCsvFile(file);
      stopwatch.stop();

      // Ensure it's reasonably fast (e.g., under 2 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      expect(data.headers, ['Date', 'Amount', 'Payee', 'Memo']);
      expect(data.rows.length, 10000);
      expect(data.rows.last[2], 'Payee 9999');
    });
  });
}
