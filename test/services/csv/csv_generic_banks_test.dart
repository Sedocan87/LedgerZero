// Bank exports without a preset, mapped from the header keywords: each
// fixture under test/fixtures/bank_csv_generic/ is read like a picked
// file, mapped with autoMapColumns and converted with the detected date
// format and decimal separator.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

import '../../helpers/memory_platform_file.dart';

final _service = CsvImportService();

Future<
  ({
    CsvImportData data,
    Map<String, String?> mapping,
    CsvValidationResult validation,
    List<ImportTransaction> rows,
  })
>
_import(
  String name, {
  bool preferDayFirst = true,
  bool outflowIsNegative = true,
}) async {
  final bytes = File('test/fixtures/bank_csv_generic/$name').readAsBytesSync();
  final data = await _service.parseCsvFile(
    MemoryPlatformFile(name: name, bytes: bytes),
  );
  expect(data.preset, isNull, reason: 'these files have no preset');
  final mapping = CsvImportService.autoMapColumns(data.headers);
  final dateFormat = _service
      .detectDateFormat(data, mapping, preferDayFirst: preferDayFirst)
      .format;
  final separator = _service.detectDecimalSeparator(
    data,
    mapping,
    fallback: '.',
  );
  final validation = _service.validateCsvData(
    data: data,
    columnMapping: mapping,
    dateFormat: dateFormat,
    decimalSeparator: separator,
    outflowIsNegative: outflowIsNegative,
  );
  final rows = _service.convertCsvToTransactions(
    data: data,
    columnMapping: mapping,
    dateFormat: dateFormat,
    decimalSeparator: separator,
    outflowIsNegative: outflowIsNegative,
  );
  return (data: data, mapping: mapping, validation: validation, rows: rows);
}

void main() {
  test('Lloyds: "Debit Amount" and "Credit Amount" are mapped as a pair, '
      'so purchases are outflows and the salary is kept (F1)', () async {
    final result = await _import('lloyds.csv');
    expect(result.mapping[CsvField.amount], isNull);
    expect(result.mapping[CsvField.debit], 'Debit Amount');
    expect(result.mapping[CsvField.credit], 'Credit Amount');
    expect(result.mapping[CsvField.date], 'Transaction Date');
    expect(result.mapping[CsvField.payee], 'Transaction Description');
    expect(result.validation.isValid, isTrue);
    expect(result.validation.warnings, isEmpty);
    expect(result.rows.map((r) => r.amount), [-4510, -6000, 250000, -8240]);
    expect(result.rows.map((r) => r.payeeName), [
      'TESCO STORES 3012',
      'SHELL GARAGE',
      'ACME LTD SALARY',
      'BRITISH GAS',
    ]);
  });

  group('debit/credit pairs', () {
    for (final (debit, credit) in [
      ('Soll', 'Haben'),
      ('Paid out', 'Paid in'),
      ('Money Out', 'Money In'),
      ('Withdrawals', 'Deposits'),
      ('Debit', 'Credit'),
      ('Debit Amount', 'Credit Amount'),
      ('Belastung', 'Gutschrift'),
    ]) {
      test('$debit / $credit', () {
        final mapping = CsvImportService.autoMapColumns([
          'Date',
          'Description',
          debit,
          credit,
          'Balance',
        ]);
        expect(mapping[CsvField.amount], isNull);
        expect(mapping[CsvField.debit], debit);
        expect(mapping[CsvField.credit], credit);
      });
    }

    test('a signed amount column next to a debit/credit flag is still one '
        'amount', () {
      final mapping = CsvImportService.autoMapColumns([
        'Buchungstag',
        'Umsatz',
        'Soll/Haben',
        'Empfänger',
      ]);
      expect(mapping[CsvField.amount], 'Umsatz');
      expect(mapping[CsvField.debit], isNull);
      expect(mapping[CsvField.credit], isNull);
      expect(mapping[CsvField.debitCreditFlag], 'Soll/Haben');
    });

    test('a lone "Credit" column is not an amount source', () {
      final mapping = CsvImportService.autoMapColumns([
        'Date',
        'Amount',
        'Credit limit',
      ]);
      expect(mapping[CsvField.amount], 'Amount');
      expect(mapping[CsvField.debit], isNull);
      expect(mapping[CsvField.credit], isNull);
    });
  });

  group('every amount would be income (Improvement 1)', () {
    CsvImportData data(List<String> amounts) => _service.parseCsvContent(
      'Date,Description,Amount\n'
      '${[for (var i = 0; i < amounts.length; i++) '2026-10-0${i + 1},Shop $i,${amounts[i]}'].join('\n')}\n',
    );
    const mapping = {
      CsvField.date: 'Date',
      CsvField.amount: 'Amount',
      CsvField.payee: 'Description',
    };
    List<CsvIssueKind> warnings(
      List<String> amounts, {
      required bool outflowIsNegative,
    }) => [
      for (final w
          in _service
              .validateCsvData(
                data: data(amounts),
                columnMapping: mapping,
                dateFormat: 'yyyy-MM-dd',
                decimalSeparator: '.',
                outflowIsNegative: outflowIsNegative,
              )
              .warnings)
        w.kind,
    ];

    test('a card statement with positive charges is flagged', () {
      expect(
        warnings(['12.50', '8.00', '40.00'], outflowIsNegative: true),
        contains(CsvIssueKind.allInflows),
      );
    });

    test('the same file with the sign switch off is fine', () {
      expect(
        warnings(['12.50', '8.00', '40.00'], outflowIsNegative: false),
        isNot(contains(CsvIssueKind.allInflows)),
      );
    });

    test('negative amounts with the sign switch off are flagged', () {
      expect(
        warnings(['-12.50', '-8.00'], outflowIsNegative: false),
        contains(CsvIssueKind.allInflows),
      );
    });

    test('mixed signs, only outflows and a single row are not flagged', () {
      expect(
        warnings(['-12.50', '2500.00'], outflowIsNegative: true),
        isNot(contains(CsvIssueKind.allInflows)),
      );
      expect(
        warnings(['-12.50', '-8.00'], outflowIsNegative: true),
        isNot(contains(CsvIssueKind.allInflows)),
      );
      expect(
        warnings(['2500.00'], outflowIsNegative: true),
        isNot(contains(CsvIssueKind.allInflows)),
      );
    });
  });
}
