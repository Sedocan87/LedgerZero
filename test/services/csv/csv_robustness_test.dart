// Blank lines, preambles, footers, tab delimiters and partly unreadable
// rows (I8/I11): the import skips what it cannot read instead of refusing
// the whole file, and only blocks when too much is unreadable.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

void main() {
  final service = CsvImportService();
  const mapping = {CsvField.date: 'Date', CsvField.amount: 'Amount'};

  CsvValidationResult validate(
    CsvImportData data, {
    String format = 'yyyy-MM-dd',
  }) => service.validateCsvData(
    data: data,
    columnMapping: {
      for (final e in mapping.entries)
        e.key: data.headers.contains(e.value) ? e.value : null,
      if (data.headers.contains('Datum')) CsvField.date: 'Datum',
      if (data.headers.contains('Betrag')) CsvField.amount: 'Betrag',
    },
    dateFormat: format,
    decimalSeparator: '.',
  );

  test('blank lines and a blank footer are dropped while parsing', () {
    final data = service.parseCsvContent(
      'Date,Amount\n\n2026-10-01,-1.00\n\n2026-10-02,-2.00\n\n\n',
    );
    expect(data.rows, hasLength(2));
    expect(validate(data).isValid, isTrue);
    expect(validate(data).warnings, isEmpty);
  });

  test('a preamble above the header is skipped and reported', () {
    final data = service.parseCsvContent(
      'Kontoauszug Girokonto\n'
      'Kunde: Erika Musterfrau\n'
      '\n'
      'Datum;Betrag;Text\n'
      '01.10.2026;-1,00;a\n'
      '02.10.2026;-2,00;b\n',
    );
    expect(data.headerLineIndex, 3);
    expect(data.headers, ['Datum', 'Betrag', 'Text']);
    expect(data.delimiter, ';');
    expect(data.rows, hasLength(2));
  });

  test('a balance footer line is skipped with a warning', () {
    final data = service.parseCsvContent(
      'Date,Amount\n'
      '2026-10-01,-1.00\n'
      '2026-10-02,-2.00\n'
      '2026-10-03,-3.00\n'
      'Closing balance,100.00\n',
    );
    final result = validate(data);
    expect(result.isValid, isTrue);
    expect(result.warnings.single.kind, CsvIssueKind.invalidDates);
    expect(result.warnings.single.count, 1);
    expect(result.skippedRows, 1);
    final rows = service.convertCsvToTransactions(
      data: data,
      columnMapping: mapping,
      dateFormat: 'yyyy-MM-dd',
      decimalSeparator: '.',
      outflowIsNegative: true,
    );
    expect(rows, hasLength(3));
  });

  test('unreadable amounts in a few rows are a warning, in many an error', () {
    CsvImportData file(int good, int bad) => CsvImportData(
      headers: ['Date', 'Amount'],
      rows: [
        for (var i = 0; i < good; i++) ['2026-10-01', '-1.00'],
        for (var i = 0; i < bad; i++) ['2026-10-01', 'n/a'],
      ],
      delimiter: ',',
    );
    final few = validate(file(20, 3));
    expect(few.isValid, isTrue);
    expect(few.warnings.single.kind, CsvIssueKind.invalidAmounts);

    final many = validate(file(20, 8));
    expect(many.isValid, isFalse);
    expect(many.errors.single.kind, CsvIssueKind.invalidAmounts);

    // All rows unreadable is always an error, however few.
    final all = validate(file(0, 2));
    expect(all.isValid, isFalse);
  });

  test('invalid dates follow the same rule as invalid amounts (I11)', () {
    CsvImportData file(int good, int bad) => CsvImportData(
      headers: ['Date', 'Amount'],
      rows: [
        for (var i = 0; i < good; i++) ['2026-10-01', '-1.00'],
        for (var i = 0; i < bad; i++) ['Kontostand', '-1.00'],
      ],
      delimiter: ',',
    );
    expect(validate(file(10, 2)).isValid, isTrue);
    expect(
      validate(file(10, 2)).warnings.single.kind,
      CsvIssueKind.invalidDates,
    );
    expect(validate(file(10, 5)).isValid, isFalse);
  });

  test('tab-delimited files are read', () {
    final data = service.parseCsvContent(
      'Date\tPayee\tAmount\n2026-10-01\tShop\t-1.00\n',
    );
    expect(data.delimiter, '\t');
    expect(data.headers, ['Date', 'Payee', 'Amount']);
    expect(data.rows.single, ['2026-10-01', 'Shop', '-1.00']);
  });

  test('duplicate and empty header names are made unique', () {
    final data = service.parseCsvContent(
      'Buchung;Betrag;Währung;Saldo;Währung;\n01.10.2026;-1,00;EUR;5,00;EUR;\n',
    );
    expect(data.headers, [
      'Buchung',
      'Betrag',
      'Währung',
      'Saldo',
      'Währung (2)',
      '#6',
    ]);
  });

  test('a file without data rows is an error, not an empty review', () {
    final data = service.parseCsvContent('Date,Amount\n');
    final result = validate(data);
    expect(result.isValid, isFalse);
    expect(result.errors.single.kind, CsvIssueKind.noRows);
  });

  test('the outlier warning fires for dates a year away, not for a long '
      'export', () {
    CsvImportData file(List<String> dates) => CsvImportData(
      headers: ['Date', 'Amount'],
      rows: [
        for (final d in dates) [d, '-1.00'],
      ],
      delimiter: ',',
    );
    final sixMonths = validate(
      file([
        '2026-01-05',
        '2026-02-05',
        '2026-03-05',
        '2026-04-05',
        '2026-05-05',
        '2026-06-05',
      ]),
    );
    expect(sixMonths.warnings, isEmpty);

    final typo = validate(
      file([
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
        '2026-10-04',
        '2016-10-05',
      ]),
    );
    expect(typo.warnings.single.kind, CsvIssueKind.dateOutliers);
  });

  test('an ambiguous day/month order is reported as a warning', () {
    final data = CsvImportData(
      headers: ['Date', 'Amount'],
      rows: [
        ['01/02/2026', '-1.00'],
        ['03/04/2026', '-1.00'],
      ],
      delimiter: ',',
    );
    final result = validate(data, format: 'dd/MM/yyyy');
    expect(result.isValid, isTrue);
    final warning = result.warnings.single;
    expect(warning.kind, CsvIssueKind.ambiguousDateFormat);
    expect(warning.dateFormat, 'dd/MM/yyyy');
    expect(warning.otherFormat, 'MM/dd/yyyy');
  });
}
