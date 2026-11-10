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
  final mapping = CsvImportService.initialMapping(data);
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

  test('Commerzbank: the own account number is not the payee of inflows '
      '(F10)', () async {
    final result = await _import('commerzbank.csv');
    expect(result.mapping[CsvField.payee], 'Buchungstext');
    expect(result.mapping[CsvField.inflowPayee], isNull);
    expect(result.mapping[CsvField.amount], 'Betrag');
    expect(result.validation.isValid, isTrue);
    expect(result.rows.map((r) => r.amount), [-8000, 250000, -2345]);
    expect(result.rows.map((r) => r.payeeName), [
      'Stadtwerke Köln Abschlag Strom',
      'Beispiel AG Gehalt 10/2026',
      'REWE Markt GmbH Köln',
    ]);
  });

  test('Consorsbank: the name column beats "Buchungstext" as the payee '
      '(F10)', () async {
    final result = await _import('consorsbank.csv');
    expect(result.mapping[CsvField.payee], 'Sender / Empfänger');
    expect(result.mapping[CsvField.memo], 'Verwendungszweck');
    expect(result.mapping[CsvField.amount], 'Betrag in EUR');
    expect(result.mapping[CsvField.date], 'Buchung');
    expect(result.validation.isValid, isTrue);
    expect(result.rows.map((r) => r.amount), [-8000, 250000, -450]);
    expect(result.rows.map((r) => r.payeeName), [
      'Stadtwerke München',
      'Beispiel AG',
      'Bäckerei Schmidt',
    ]);
  });

  test('PayPal (German): the amount is "Netto", not "Versicherungsbetrag" '
      'or "Umsatzsteuer" (F10)', () async {
    final result = await _import('paypal_de.csv');
    expect(result.mapping[CsvField.amount], 'Netto');
    expect(result.mapping[CsvField.payee], 'Name');
    expect(result.mapping[CsvField.date], 'Datum');
    expect(result.validation.isValid, isTrue);
    expect(result.validation.warnings, isEmpty);
    expect(result.rows.map((r) => r.amount), [-1299, 4840, -3990]);
    expect(result.rows.map((r) => r.payeeName), [
      'Spotify AB',
      'Erika Musterfrau',
      'Buchhandlung Beispiel',
    ]);
  });

  test('Amex Germany: "Beschreibung" is the payee, "Konto #" is not an '
      'account name, and the positive charges are flagged (F10)', () async {
    final result = await _import('amex_de.csv');
    expect(result.mapping[CsvField.payee], 'Beschreibung');
    expect(result.mapping[CsvField.account], isNull);
    expect(result.mapping[CsvField.amount], 'Betrag');
    expect(
      result.validation.warnings.map((w) => w.kind),
      contains(CsvIssueKind.allInflows),
    );
    final flipped = await _import('amex_de.csv', outflowIsNegative: false);
    expect(flipped.validation.warnings, isEmpty);
    expect(flipped.rows.map((r) => r.amount), [-2345, -4990, -1999]);
    expect(flipped.rows.first.payeeName, 'REWE MARKT GMBH KOELN');
  });

  test('compound headers that merely contain an amount keyword are not '
      'the amount', () {
    for (final header in [
      'Versicherungsbetrag',
      'Umsatzsteuer',
      'Steuerbetrag',
      'Versandkosten',
      'Gebührenbetrag',
    ]) {
      final mapping = CsvImportService.autoMapColumns(['Datum', header]);
      expect(mapping[CsvField.amount], isNull, reason: header);
    }
    // A compound that is an amount still matches.
    expect(
      CsvImportService.autoMapColumns([
        'Datum',
        'Buchungsbetrag',
      ])[CsvField.amount],
      'Buchungsbetrag',
    );
  });

  test('an empty sender cell keeps the payee of the row (F10)', () {
    final data = _service.parseCsvContent(
      'Datum;Empfänger;Zahlungspflichtige*r;Betrag\n'
      '01.10.2026;Erstattung Versand;;12,00\n'
      '02.10.2026;Mein Konto;Beispiel AG;2500,00\n',
    );
    final mapping = CsvImportService.autoMapColumns(data.headers);
    expect(mapping[CsvField.inflowPayee], 'Zahlungspflichtige*r');
    final rows = _service.convertCsvToTransactions(
      data: data,
      columnMapping: mapping,
      dateFormat: 'dd.MM.yyyy',
      decimalSeparator: ',',
      outflowIsNegative: true,
    );
    expect(rows.map((r) => r.payeeName), ['Beispiel AG', 'Erstattung Versand']);
  });

  group('a file without header row (Targobank)', () {
    test('is recognised: the first transaction is a row, not the header, '
        'and the columns are guessed from their values', () async {
      final result = await _import('targobank_headerless.csv');
      expect(result.data.hasHeader, isFalse);
      expect(result.data.headers, ['#1', '#2', '#3', '#4', '#5']);
      expect(result.data.rows, hasLength(3));
      expect(result.mapping[CsvField.date], '#1');
      expect(result.mapping[CsvField.amount], '#4');
      expect(result.mapping[CsvField.payee], '#3');
      expect(result.validation.isValid, isTrue);
      expect(result.validation.warnings, isEmpty);
      expect(result.rows.map((r) => r.amount), [-8000, 250000, -2345]);
      expect(result.rows.last.payeeName, 'REWE SAGT DANKE 4711 KOELN');
    });

    test('the user can say so either way', () {
      const content =
          '01.10.2026;Bakery;-2,50\n'
          '02.10.2026;Market;-20,00\n';
      final forcedHeader = _service.parseCsvContent(content, hasHeader: true);
      expect(forcedHeader.hasHeader, isTrue);
      expect(forcedHeader.headers, ['01.10.2026', 'Bakery', '-2,50']);
      expect(forcedHeader.rows, hasLength(1));

      // A header the keywords do not know, switched off by hand.
      final unknown = _service.parseCsvContent(
        'Wann;Wer;Wieviel\n01.10.2026;Bakery;-2,50\n',
      );
      expect(unknown.hasHeader, isTrue);
      expect(unknown.rows, hasLength(1));
      final noHeader = _service.parseCsvContent(
        'Wann;Wer;Wieviel\n01.10.2026;Bakery;-2,50\n',
        hasHeader: false,
      );
      expect(noHeader.headers, ['#1', '#2', '#3']);
      expect(noHeader.rows, hasLength(2));
    });

    test('a file with a header row is not taken for one without', () async {
      for (final name in ['lloyds.csv', 'amex_de.csv', 'paypal_de.csv']) {
        expect((await _import(name)).data.hasHeader, isTrue, reason: name);
      }
    });
  });

  group('off the UI thread (Improvement 4)', () {
    test(
      'analyzeColumns detects formats and counts the amount signs',
      () async {
        final data = await _service.parseCsvFile(
          MemoryPlatformFile(
            name: 'amex_de.csv',
            bytes: File(
              'test/fixtures/bank_csv_generic/amex_de.csv',
            ).readAsBytesSync(),
          ),
        );
        final mapping = CsvImportService.initialMapping(data);
        final analysis = await _service.analyzeColumns(
          data,
          mapping,
          preferDayFirst: true,
          fallbackSeparator: '.',
        );
        expect(analysis.dateDetection.format, 'dd/MM/yyyy');
        expect(analysis.decimalSeparator, ',');
        expect(analysis.positiveAmounts, 3);
        expect(analysis.negativeAmounts, 0);
        expect(analysis.allInflows(outflowIsNegative: true), isTrue);
        expect(analysis.inflowCount(outflowIsNegative: true), 3);
        expect(analysis.allInflows(outflowIsNegative: false), isFalse);
      },
    );

    test(
      'prepareImport validates and converts like the direct calls',
      () async {
        final direct = await _import('lloyds.csv');
        final prepared = await _service.prepareImport(
          data: direct.data,
          columnMapping: direct.mapping,
          dateFormat: 'dd/MM/yyyy',
          decimalSeparator: '.',
          outflowIsNegative: true,
        );
        expect(prepared.validation.isValid, isTrue);
        expect(
          prepared.transactions.map(
            (r) => '${r.date}|${r.amount}|${r.payeeName}',
          ),
          direct.rows.map((r) => '${r.date}|${r.amount}|${r.payeeName}'),
        );

        final invalid = await _service.prepareImport(
          data: direct.data,
          columnMapping: {...direct.mapping, CsvField.date: null},
          dateFormat: 'dd/MM/yyyy',
          decimalSeparator: '.',
          outflowIsNegative: true,
        );
        expect(invalid.validation.isValid, isFalse);
        expect(invalid.transactions, isEmpty);
      },
    );
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
