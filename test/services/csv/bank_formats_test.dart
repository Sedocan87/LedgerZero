import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  group('CsvImportService Bank Formats', () {
    late CsvImportService service;

    setUp(() {
      service = CsvImportService();
    });

    const chaseCsv =
        'Details,Posting Date,Description,Amount,Type,Balance,Check or Slip #\nDEBIT,01/05/2023,"GAS STATION",-45.00,Sale,,';
    test('parses Chase format (Date,Description,Amount,Type)', () async {
      final file = PlatformFile(
        name: 'chase.csv',
        size: chaseCsv.length,
        bytes: Uint8List.fromList(utf8.encode(chaseCsv)),
      );

      final data = await service.parseCsvFile(file);
      final txs = service.convertCsvToTransactions(
        data: data,
        columnMapping: {
          'Date': 'Posting Date',
          'Amount': 'Amount',
          'Payee': 'Description',
        },
        dateFormat: 'MM/dd/yyyy',
        decimalSeparator: '.',
        outflowIsNegative: true,
      );

      expect(txs.length, 1);
      expect(txs.first.date, DateTime(2023, 1, 5));
      expect(txs.first.amount, -45.00);
      expect(txs.first.payeeName, 'GAS STATION');
    });

    test('parses Wells Fargo format (Date,Amount,*,*,Description)', () async {
      const csv =
          '01/05/2023,-45.00,*,,"GAS STATION"\n'; // Headerless or with headers
      // Adding headers for generic parser compatibility (parser expects headers)
      const csvWithHeaders = 'Date,Amount,X,Y,Description\n$csv';

      final file = PlatformFile(
        name: 'wf.csv',
        size: csvWithHeaders.length,
        bytes: Uint8List.fromList(utf8.encode(csvWithHeaders)),
      );

      final data = await service.parseCsvFile(file);
      final txs = service.convertCsvToTransactions(
        data: data,
        columnMapping: {
          'Date': 'Date',
          'Amount': 'Amount',
          'Payee': 'Description',
        },
        dateFormat: 'MM/dd/yyyy',
        decimalSeparator: '.',
        outflowIsNegative: true,
      );

      expect(txs.length, 1);
      expect(txs.first.amount, -45.00);
    });

    test(
      'parses European format (dd.MM.yyyy, semicolon, comma decimal)',
      () async {
        const csv =
            'Buchungstag;Verwendungszweck;Betrag\n31.12.2023;Supermarkt;-50,00';
        final file = PlatformFile(
          name: 'euro.csv',
          size: csv.length,
          bytes: Uint8List.fromList(utf8.encode(csv)),
        );

        final data = await service.parseCsvFile(file);

        expect(data.delimiter, ';');

        final txs = service.convertCsvToTransactions(
          data: data,
          columnMapping: {
            'Date': 'Buchungstag',
            'Amount': 'Betrag',
            'Payee': 'Verwendungszweck',
          },
          dateFormat: 'dd.MM.yyyy',
          decimalSeparator: ',',
          outflowIsNegative: true,
        );

        expect(txs.length, 1);
        expect(txs.first.date, DateTime(2023, 12, 31));
        expect(txs.first.amount, -50.00);
        expect(txs.first.payeeName, 'Supermarkt');
      },
    );
  });
}
