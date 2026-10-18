import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_date_formats.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  group('detectCsvDateFormat', () {
    test('German dd.MM.yyyy wins over the lenient yyyy.MM.dd (I1)', () {
      final d = detectCsvDateFormat(['18.10.2026', '03.10.2026']);
      expect(d.format, 'dd.MM.yyyy');
      expect(d.fitsAll, isTrue);
      expect(d.ambiguous, isFalse);
    });

    test('a day above 12 anywhere in the file decides dd/MM over MM/dd', () {
      // Only the second row tells the orders apart.
      final d = detectCsvDateFormat(['05/03/2026', '13/03/2026']);
      expect(d.format, 'dd/MM/yyyy');
      expect(d.ambiguous, isFalse);
      expect(
        detectCsvDateFormat(['03/05/2026', '03/13/2026']).format,
        'MM/dd/yyyy',
      );
    });

    test('an ambiguous file follows the locale preference and says so', () {
      final us = detectCsvDateFormat(['05/03/2026', '01/02/2026']);
      expect(us.format, 'MM/dd/yyyy');
      expect(us.ambiguous, isTrue);
      expect(us.candidates, containsAll(['dd/MM/yyyy', 'MM/dd/yyyy']));
      expect(us.alternative, 'dd/MM/yyyy');

      final de = detectCsvDateFormat([
        '05/03/2026',
        '01/02/2026',
      ], preferDayFirst: true);
      expect(de.format, 'dd/MM/yyyy');
      expect(de.ambiguous, isTrue);
    });

    test('two-digit years are read as dd.MM.yy within this century (I2)', () {
      final d = detectCsvDateFormat(['18.10.26', '02.10.26']);
      expect(d.format, 'dd.MM.yy');
      expect(parseCsvDate('18.10.26', 'dd.MM.yy'), DateTime(2026, 10, 18));
      // A yy format does not swallow four-digit years and vice versa.
      expect(parseCsvDate('18.10.2026', 'dd.MM.yy'), isNull);
      expect(parseCsvDate('18.10.26', 'dd.MM.yyyy'), isNull);
    });

    test('the best partial fit is returned when no format fits all', () {
      final d = detectCsvDateFormat(['18.10.2026', 'Kontostand', '19.10.2026']);
      expect(d.format, 'dd.MM.yyyy');
      expect(d.fitsAll, isFalse);
    });

    test('timestamps (Revolut) are recognised', () {
      expect(
        detectCsvDateFormat(['2026-10-17 09:12:33']).format,
        'yyyy-MM-dd HH:mm:ss',
      );
    });
  });

  group('parseCsvDate', () {
    test('rejects years outside 1900-2100 and lenient roll-over', () {
      expect(parseCsvDate('18.10.0026', 'dd.MM.yyyy'), isNull);
      expect(parseCsvDate('18.10.2101', 'dd.MM.yyyy'), isNull);
      expect(parseCsvDate('31.02.2026', 'dd.MM.yyyy'), isNull);
      expect(parseCsvDate('18/10/2026', 'MM/dd/yyyy'), isNull);
      expect(parseCsvDate('2026-10-18', 'yyyy-MM-dd'), DateTime(2026, 10, 18));
    });
  });

  group('CsvImportService with two-digit and odd years', () {
    final service = CsvImportService();

    test('validation rejects a year 26 instead of importing year 0026', () {
      final data = CsvImportData(
        headers: ['Buchungstag', 'Betrag'],
        rows: [
          ['18.10.26', '-12,50'],
        ],
        delimiter: ';',
      );
      final result = service.validateCsvData(
        data: data,
        columnMapping: {
          CsvField.date: 'Buchungstag',
          CsvField.amount: 'Betrag',
        },
        dateFormat: 'dd.MM.yyyy',
        decimalSeparator: ',',
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.kind, CsvIssueKind.invalidDates);

      final rows = service.convertCsvToTransactions(
        data: data,
        columnMapping: {
          CsvField.date: 'Buchungstag',
          CsvField.amount: 'Betrag',
        },
        dateFormat: 'dd.MM.yy',
        decimalSeparator: ',',
        outflowIsNegative: true,
      );
      expect(rows.single.date, DateTime.utc(2026, 10, 18));
      expect(rows.single.amount, -1250);
    });

    test('the service picks the format over all rows of the date column', () {
      final data = CsvImportData(
        headers: ['Datum', 'Betrag'],
        rows: [
          ['05.10.2026', '-1,00'],
          ['18.10.2026', '-2,00'],
        ],
        delimiter: ';',
      );
      final detection = service.detectDateFormat(data, {
        CsvField.date: 'Datum',
        CsvField.amount: 'Betrag',
      });
      expect(detection.format, 'dd.MM.yyyy');
      expect(detection.fitsAll, isTrue);
    });
  });
}
