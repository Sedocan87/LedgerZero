import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:ledger_zero/core/money/money_parser.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/csv/bank_csv_presets.dart';
import 'package:ledger_zero/services/csv/csv_date_formats.dart';
import 'package:ledger_zero/services/csv/csv_fields.dart';
import 'package:ledger_zero/services/csv/decimal_separator_inference.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';

export 'package:ledger_zero/services/csv/csv_fields.dart';

class CsvImportData {
  /// Header names as the file writes them (trimmed); duplicates are made
  /// unique (`Währung`, `Währung (2)`), empty ones become `#n`.
  final List<String> headers;

  /// Data rows (cells as strings). Rows whose cells are all empty are
  /// dropped while parsing.
  final List<List<dynamic>> rows;
  final String delimiter;

  /// 0-based line of the header in the file; lines above it (account
  /// details, balances) were skipped.
  final int headerLineIndex;

  /// The bank preset in use (recognised from the header fingerprint, or
  /// chosen by the user, see [withPreset]), or `null`.
  final BankCsvPreset? preset;

  /// `false` for a file without a header row (Targobank): [headers] are
  /// then `#1`, `#2`, ... and the first line is a data row.
  final bool hasHeader;

  CsvImportData({
    required this.headers,
    required this.rows,
    required this.delimiter,
    this.headerLineIndex = 0,
    this.preset,
    this.hasHeader = true,
  });

  /// The same file read with [preset] (the user's choice on the mapping
  /// screen; `null` for none), so its payee pattern applies.
  CsvImportData withPreset(BankCsvPreset? preset) => CsvImportData(
    headers: headers,
    rows: rows,
    delimiter: delimiter,
    headerLineIndex: headerLineIndex,
    preset: preset,
    hasHeader: hasHeader,
  );

  /// The values of the column [header] (rows too short for it skipped).
  Iterable<String> columnValues(String? header) sync* {
    final index = header == null ? -1 : headers.indexOf(header);
    if (index == -1) {
      return;
    }
    for (final row in rows) {
      if (row.length > index) {
        yield row[index].toString();
      }
    }
  }
}

/// A problem found while validating a CSV import. The UI turns it into a
/// localised message; [toString] is for logs.
enum CsvIssueKind {
  dateColumnNotMapped,
  amountColumnNotMapped,
  mappedColumnsMissing,

  /// The file has no data rows.
  noRows,

  /// [CsvIssue.count] rows have dates that do not match
  /// [CsvIssue.dateFormat]. A warning when the rows are few (they are
  /// skipped), an error when they are more than [CsvImportService.skipLimit]
  /// allows.
  invalidDates,

  /// [CsvIssue.count] rows have unreadable amounts; same rule as
  /// [invalidDates].
  invalidAmounts,

  /// [CsvIssue.count] dates are more than a year from the median date
  /// (a wrong date format or a typo in the file).
  dateOutliers,

  /// Both [CsvIssue.dateFormat] and [CsvIssue.otherFormat] fit every date
  /// (no day above 12): day and month may be swapped.
  ambiguousDateFormat,

  /// Every one of the [CsvIssue.count] readable amounts would be imported
  /// as an inflow: a card statement listing charges as positive numbers
  /// (the sign switch is wrong) or only one of two amount columns mapped.
  allInflows,

  /// [CsvIssue.count] rows are marked reverted, failed or declined in the
  /// mapped Cleared/Status column and are left out (they never changed
  /// the balance).
  voidRows,
}

class CsvIssue {
  final CsvIssueKind kind;
  final int count;
  final String? dateFormat;
  final String? otherFormat;

  const CsvIssue(
    this.kind, {
    this.count = 0,
    this.dateFormat,
    this.otherFormat,
  });

  @override
  String toString() =>
      'CsvIssue(${kind.name}, count: $count, dateFormat: $dateFormat, '
      'otherFormat: $otherFormat)';
}

class CsvValidationResult {
  final bool isValid;
  final List<CsvIssue> errors;
  final List<CsvIssue> warnings;

  /// Rows that will be skipped (unreadable date or amount).
  final int skippedRows;

  /// Rows left out because the file marks them as reverted, failed or
  /// declined (see [CsvImportService.isVoidStatusCell]).
  final int voidRows;

  CsvValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.skippedRows = 0,
    this.voidRows = 0,
  });
}

/// What [CsvImportService.analyzeColumns] found in the mapped columns.
class CsvColumnAnalysis {
  const CsvColumnAnalysis({
    required this.dateDetection,
    required this.decimalSeparator,
    required this.positiveAmounts,
    required this.negativeAmounts,
  });

  /// The date format of the mapped date column.
  final CsvDateDetection dateDetection;

  /// The decimal separator of the mapped amount column(s).
  final String decimalSeparator;

  /// Rows whose amount (as the file writes it) is above / below zero.
  final int positiveAmounts;
  final int negativeAmounts;

  /// Whether every amount would be imported as an inflow with the given
  /// sign setting (two or more rows, no outflow): a card statement read
  /// with the wrong sign, or one of two amount columns mapped.
  bool allInflows({required bool outflowIsNegative}) => outflowIsNegative
      ? negativeAmounts == 0 && positiveAmounts >= 2
      : positiveAmounts == 0 && negativeAmounts >= 2;

  /// The number of rows [allInflows] speaks about.
  int inflowCount({required bool outflowIsNegative}) =>
      outflowIsNegative ? positiveAmounts : negativeAmounts;
}

/// The outcome of [CsvImportService.prepareImport].
class CsvPreparedImport {
  const CsvPreparedImport(this.validation, this.transactions);

  final CsvValidationResult validation;

  /// The converted rows; empty when [validation] found errors.
  final List<ImportTransaction> transactions;
}

/// Why a CSV file could not be read; shown localised by the UI.
enum ImportFailure { unreadable, empty, malformed }

class ImportException implements Exception {
  final ImportFailure failure;

  /// Technical detail for logs (never shown to users).
  final String message;
  ImportException(this.failure, this.message);
  @override
  String toString() => 'ImportException(${failure.name}): $message';
}

/// Header keywords per field in order of preference (English and German
/// bank exports). A header equal to a keyword scores highest, one
/// containing it as a whole word next, one merely containing it lowest;
/// headers containing a word of [_headerPenalties] for the field never
/// match it.
const Map<String, List<String>> _headerKeywords = {
  CsvField.date: [
    'date',
    'datum',
    'buchungstag',
    'buchungsdatum',
    'buchung',
    'booking date',
    'posting date',
    'transaction date',
    'completed date',
    'started date',
    'valuta',
    'valutadatum',
    'wertstellung',
    'value date',
  ],
  CsvField.amount: [
    'amount',
    'betrag',
    'betrag (eur)',
    'betrag (€)',
    'amount (eur)',
    'umsatz in eur',
    'umsatz',
    'netto',
    'brutto',
    'value',
    'summe',
  ],
  CsvField.debit: [
    'soll',
    'debit',
    'ausgang',
    'belastung',
    'outflow',
    'paid out',
    'money out',
    'withdrawals',
    'withdrawal',
  ],
  CsvField.credit: [
    'haben',
    'credit',
    'eingang',
    'gutschrift',
    'inflow',
    'paid in',
    'money in',
    'deposits',
    'deposit',
  ],
  CsvField.debitCreditFlag: ['soll/haben', 's/h', 'debit/credit', 'dr/cr'],
  CsvField.payee: [
    'payee',
    'partner name',
    'beguenstigter/zahlungspflichtiger',
    'begünstigter/zahlungspflichtiger',
    'auftraggeber/empfänger',
    'name zahlungsbeteiligter',
    'zahlungsempfänger',
    'empfänger',
    'empfaenger',
    'begünstigter',
    'beguenstigter',
    'auftraggeber',
    'zahlungspflichtiger',
    'merchant',
  ],
  CsvField.inflowPayee: ['zahlungspflichtige', 'auftraggeber', 'sender'],
  CsvField.memo: [
    'memo',
    'verwendungszweck',
    'payment reference',
    'reference',
    'note',
    'notiz',
    'remark',
    'vermerk',
  ],
  CsvField.category: ['category', 'kategorie', 'cat'],
  CsvField.account: ['account', 'konto', 'account name', 'kontoname'],
  CsvField.transfer: ['transfer', 'umbuchung'],
  CsvField.cleared: ['cleared', 'status'],
  CsvField.approved: ['approved', 'bestätigt'],
  CsvField.fee: [],
};

/// Words that disqualify a header for a field (the Sparkasse export has
/// `Lastschrift Ursprungsbetrag` before `Betrag`).
const Map<String, List<String>> _headerPenalties = {
  CsvField.date: ['erstellt', 'created', 'export'],
  CsvField.amount: [
    'ursprungsbetrag',
    'auslagenersatz',
    'saldo',
    'kontostand',
    'balance',
    'währung',
    'waehrung',
    'currency',
    'gebühr',
    'fee',
    'anzahl',
    'original',
    'foreign',
    'fremd',
    'exchange',
    'kurs',
  ],
  // A column naming both sides is a debit/credit flag, not one side.
  CsvField.debit: ['ursprungsbetrag', 'soll/haben', 'debit/credit', 'dr/cr'],
  CsvField.credit: ['soll/haben', 'debit/credit', 'dr/cr'],
  CsvField.debitCreditFlag: [],
  CsvField.payee: ['iban', 'bic', 'kontonummer', 'account number', 'id'],
  CsvField.inflowPayee: ['iban', 'bic'],
  CsvField.memo: ['mandatsreferenz', 'kundenreferenz', 'gläubiger'],
  CsvField.category: [],
  CsvField.account: ['iban', 'number', 'nummer', 'nr', '#'],
  CsvField.transfer: [],
  CsvField.cleared: [],
  CsvField.approved: [],
  CsvField.fee: [],
};

/// Keywords that only count when no header matches a keyword of
/// [_headerKeywords] for the field: columns that hold the payee in files
/// without a name column ("Description", Amex's "Beschreibung") but only
/// the booking type ("Lastschrift") in files that have one (Consorsbank's
/// "Sender / Empfänger" next to "Buchungstext").
const Map<String, List<String>> _fallbackKeywords = {
  CsvField.payee: [
    'name',
    'description',
    'desc',
    'beschreibung',
    'buchungstext',
  ],
};

/// Word parts that disqualify a header for a field wherever they occur in
/// it: German compounds such as `Versicherungsbetrag`, `Umsatzsteuer` or
/// `Auftraggeberkonto` contain a keyword of the field without being it.
const Map<String, List<String>> _headerPenaltyParts = {
  CsvField.amount: [
    'versicherung',
    'steuer',
    'versand',
    'gebühr',
    'gebuehr',
    'entgelt',
    'trinkgeld',
  ],
  // The account (number) of the other party, not its name.
  CsvField.payee: ['auftraggeberkonto', 'empfängerkonto', 'empfaengerkonto'],
};

/// Fields whose header must equal a keyword or contain it as a whole word
/// (a substring is not enough: `Auftragskonto` is not an account column).
const Set<String> _wholeWordFields = {
  CsvField.account,
  CsvField.transfer,
  CsvField.cleared,
  CsvField.approved,
  CsvField.debitCreditFlag,
  CsvField.debit,
  CsvField.credit,
  // `Auftraggeberkonto` is the user's own account number, not a sender.
  CsvField.inflowPayee,
};

class CsvImportService {
  /// Unreadable rows (date or amount) up to this share of all rows, and at
  /// least this many, are skipped with a warning; more are an error (the
  /// settings are probably wrong). See [validateCsvData].
  static const double skipLimitShare = 0.2;
  static const int skipLimitMinimum = 3;

  /// The number of unreadable rows that is still skipped with a warning
  /// for a file of [rowCount] rows.
  static int skipLimit(int rowCount) {
    final share = (rowCount * skipLimitShare).floor();
    return share > skipLimitMinimum ? share : skipLimitMinimum;
  }

  /// Reads and parses [file] off the UI thread. [headerLineIndex] forces
  /// the header line instead of detecting it; [hasHeader] says whether the
  /// file has a header row at all (`null`: detected, see
  /// [CsvImportData.hasHeader]).
  Future<CsvImportData> parseCsvFile(
    PlatformFile file, {
    int? headerLineIndex,
    bool? hasHeader,
  }) async {
    String content;
    try {
      // Bank exports that are not UTF-8 are almost always Windows-1252
      // (a superset of Latin-1 with the euro sign at 0x80).
      content = await file.readAsText(windows1252Fallback: true);
    } catch (e) {
      throw ImportException(
        ImportFailure.unreadable,
        'Failed to read file: $e',
      );
    }

    return compute(
      _parseCsvInternal,
      _ParseRequest(content, headerLineIndex, hasHeader),
    );
  }

  /// Parses CSV text (see [parseCsvFile]).
  CsvImportData parseCsvContent(
    String content, {
    int? headerLineIndex,
    bool? hasHeader,
  }) => _parseCsvInternal(_ParseRequest(content, headerLineIndex, hasHeader));

  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

  static CsvImportData _parseCsvInternal(_ParseRequest request) {
    final content = request.content;
    if (content.trim().isEmpty) {
      throw ImportException(ImportFailure.empty, 'The CSV file is empty');
    }

    // Lines with their start offsets (quoted fields never span the
    // preamble, so splitting the first lines is safe).
    final lineStarts = <int>[0];
    final lines = <String>[];
    var previous = 0;
    for (final m in _lineBreak.allMatches(content)) {
      lines.add(content.substring(previous, m.start));
      previous = m.end;
      lineStarts.add(m.end);
    }
    lines.add(content.substring(previous));

    final detectedHeader = request.headerLineIndex == null
        ? _detectHeaderLine(lines)
        : null;
    var headerIndex = request.headerLineIndex ?? detectedHeader ?? 0;
    if (headerIndex >= lines.length) {
      headerIndex = 0;
    }
    final delimiter = _delimiterOf(lines[headerIndex]);
    final body = content.substring(lineStarts[headerIndex]);
    // No header row: said by the caller, or no line looks like a header
    // and the first line already is a transaction.
    final hasHeader =
        request.hasHeader ??
        !(request.headerLineIndex == null &&
            detectedHeader == null &&
            _looksLikeDataRow(_splitLine(lines[headerIndex], delimiter)));

    // The row separator is the line break that ends the first record. A
    // line break inside a quoted field (a memo) is not one: an LF file
    // with one CRLF inside a quoted memo must not be split at CRLF only.
    var eol = _recordEol(body);
    if (eol == null) {
      if (content.contains('\r\n')) {
        eol = '\r\n';
      } else if (content.contains('\n')) {
        eol = '\n';
      } else if (content.contains('\r')) {
        eol = '\r';
      }
    }

    // Convert CSV
    final List<List<dynamic>> rawRows;
    try {
      rawRows = const CsvToListConverter().convert(
        body,
        fieldDelimiter: delimiter,
        eol: eol,
        shouldParseNumbers: false,
      );
    } catch (e) {
      throw ImportException(
        ImportFailure.malformed,
        'Failed to parse CSV format: $e',
      );
    }

    if (rawRows.isEmpty) {
      throw ImportException(ImportFailure.empty, 'No rows in the CSV file');
    }

    var width = 0;
    for (final row in rawRows) {
      if (row.length > width) {
        width = row.length;
      }
    }
    final headers = hasHeader
        ? _uniqueHeaders(rawRows.first)
        : [for (var i = 1; i <= width; i++) '#$i'];
    // Blank lines (the csv package yields [''] for them) and footer lines
    // without content are dropped; other footer lines (balances) fail the
    // date check and are skipped there.
    final rows = [
      for (final row in rawRows.skip(hasHeader ? 1 : 0))
        if (row.any((cell) => cell.toString().trim().isNotEmpty)) row,
    ];

    return CsvImportData(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
      headerLineIndex: headerIndex,
      preset: hasHeader ? BankCsvPreset.detect(headers) : null,
      hasHeader: hasHeader,
    );
  }

  /// The line break that ends the first record of [text]: the first one
  /// outside a quoted field. `null` when there is none.
  static String? _recordEol(String text) {
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x22) {
        inQuotes = !inQuotes;
      } else if (!inQuotes && c == 0x0A) {
        return '\n';
      } else if (!inQuotes && c == 0x0D) {
        final crlf = i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A;
        return crlf ? '\r\n' : '\r';
      }
    }
    return null;
  }

  /// Whether [cells] are a transaction rather than column names: one cell
  /// is a date in a supported format and another one a number.
  static bool _looksLikeDataRow(List<String> cells) {
    final dateAt = cells.indexWhere(
      (cell) => csvDateFormats.any((f) => parseCsvDate(cell, f) != null),
    );
    if (dateAt == -1) {
      return false;
    }
    const parser = MoneyParser();
    for (var i = 0; i < cells.length; i++) {
      if (i != dateAt && parser.tryParse(cells[i]) != null) {
        return true;
      }
    }
    return false;
  }

  /// Header names made unique and non-empty.
  static List<String> _uniqueHeaders(List<dynamic> row) {
    final seen = <String>{};
    final headers = <String>[];
    for (var i = 0; i < row.length; i++) {
      var name = row[i].toString().trim();
      if (name.isEmpty) {
        name = '#${i + 1}';
      }
      var unique = name;
      var n = 2;
      while (!seen.add(unique)) {
        unique = '$name (${n++})';
      }
      headers.add(unique);
    }
    return headers;
  }

  /// The delimiter used most in [line] (`;`, `,` or tab); comma when none
  /// occurs.
  static String _delimiterOf(String line) {
    var best = ',';
    var bestCount = ','.allMatches(line).length;
    for (final candidate in [';', '\t']) {
      final count = candidate.allMatches(line).length;
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  /// Simple split of one line into trimmed, unquoted cells (for header
  /// detection only; the real parse uses the csv package).
  static List<String> _splitLine(String line, String delimiter) => [
    for (final cell in line.split(delimiter))
      cell.trim().replaceAll(RegExp('^"|"\$'), '').trim(),
  ];

  /// The first of the first 60 lines that looks like a header: a bank
  /// preset matches it, or it names a date column and an amount column
  /// (or debit and credit columns). `null` when none does.
  static int? _detectHeaderLine(List<String> lines) {
    final limit = lines.length < 60 ? lines.length : 60;
    for (var i = 0; i < limit; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        continue;
      }
      final cells = _splitLine(line, _delimiterOf(line));
      if (cells.length < 2) {
        continue;
      }
      if (BankCsvPreset.detect(cells) != null) {
        return i;
      }
      final mapping = autoMapColumns(cells);
      final hasAmount =
          mapping[CsvField.amount] != null ||
          (mapping[CsvField.debit] != null && mapping[CsvField.credit] != null);
      if (mapping[CsvField.date] != null && hasAmount) {
        return i;
      }
    }
    return null;
  }

  /// The column mapping to start with for [data]: [preset]'s, else by the
  /// header keywords ([autoMapColumns]), else, for a file without header
  /// row, guessed from the values ([guessColumnsFromValues]).
  static Map<String, String?> initialMapping(
    CsvImportData data, {
    BankCsvPreset? preset,
  }) {
    if (preset == null && !data.hasHeader) {
      return guessColumnsFromValues(data);
    }
    return autoMapColumns(data.headers, preset: preset);
  }

  /// A mapping for a file without header row, from what the columns hold:
  /// Date is the first column whose values all fit one date format, Amount
  /// the first other column of numbers with a decimal separator or a sign
  /// (an account number or bank code has neither), Payee the longest of
  /// the remaining columns that are mostly text (not the currency code).
  /// The user checks it against the preview.
  static Map<String, String?> guessColumnsFromValues(CsvImportData data) {
    final mapping = {for (final f in CsvField.all) f: null as String?};
    const parser = MoneyParser();
    final amountLike = RegExp(r'[.,+\-−()]');
    final letters = RegExp(r'\p{L}{2}', unicode: true);
    var payeeLength = 0;
    for (final header in data.headers) {
      final values = [
        for (final v in data.columnValues(header))
          if (v.trim().isNotEmpty) v.trim(),
      ];
      if (values.isEmpty) {
        continue;
      }
      if (mapping[CsvField.date] == null &&
          detectCsvDateFormat(values).fitsAll) {
        mapping[CsvField.date] = header;
      } else if (mapping[CsvField.amount] == null &&
          values.every((v) => parser.tryParse(v) != null) &&
          values.any(amountLike.hasMatch)) {
        mapping[CsvField.amount] = header;
      } else if (values.where(letters.hasMatch).length * 2 > values.length) {
        final length = values.fold(0, (sum, v) => sum + v.length);
        if (length > payeeLength) {
          payeeLength = length;
          mapping[CsvField.payee] = header;
        }
      }
    }
    return mapping;
  }

  /// Maps the fields of [CsvField.all] to [headers]: the bank [preset]'s
  /// mapping when one matches, otherwise by header keywords (exact match
  /// before whole word before substring; each header used once).
  static Map<String, String?> autoMapColumns(
    List<String> headers, {
    BankCsvPreset? preset,
  }) {
    if (preset != null) {
      return preset.mappingFor(headers);
    }
    final mapping = {for (final f in CsvField.all) f: null as String?};
    final used = <String>{};
    final normalized = [for (final h in headers) normalizeHeader(h)];

    // Separate outflow and inflow columns come as a pair ("Debit Amount" /
    // "Credit Amount", "Paid out" / "Paid in", Soll / Haben). The pair is
    // found first and its two headers are kept out of every other field:
    // "Debit Amount" contains the word "amount", but read as the one
    // signed amount column it would turn every purchase into income and
    // drop the rows whose debit cell is empty.
    final pairDebit = _bestHeader(CsvField.debit, headers, normalized, used);
    final pairCredit = pairDebit == null
        ? null
        : _bestHeader(CsvField.credit, headers, normalized, {pairDebit});
    final hasPair = pairDebit != null && pairCredit != null;
    if (hasPair) {
      used
        ..add(pairDebit)
        ..add(pairCredit);
    }

    for (final field in CsvField.all) {
      if (field == CsvField.debit || field == CsvField.credit) {
        // Separate debit/credit columns only when there is no amount.
        if (hasPair && mapping[CsvField.amount] == null) {
          mapping[field] = field == CsvField.debit ? pairDebit : pairCredit;
        }
        continue;
      }
      if (field == CsvField.debitCreditFlag &&
          mapping[CsvField.debit] != null &&
          mapping[CsvField.credit] != null) {
        continue;
      }
      if (field == CsvField.inflowPayee && mapping[CsvField.payee] == null) {
        continue;
      }
      final best = _bestHeader(field, headers, normalized, used);
      if (best != null) {
        mapping[field] = best;
        used.add(best);
      }
    }
    return mapping;
  }

  /// The header of [headers] (not in [used]) that fits [field] best by
  /// [_headerKeywords], else by [_fallbackKeywords], or `null`: a header
  /// equal to a keyword beats one containing it as a whole word, which
  /// beats a mere substring; among equals the keyword listed first wins.
  static String? _bestHeader(
    String field,
    List<String> headers,
    List<String> normalized,
    Set<String> used,
  ) {
    final penalties = _headerPenalties[field]!;
    final penaltyParts = _headerPenaltyParts[field] ?? const <String>[];
    final candidates = <int>[];
    for (var i = 0; i < headers.length; i++) {
      if (used.contains(headers[i])) {
        continue;
      }
      final h = normalized[i];
      if ((h == 'dt' && field == CsvField.date) ||
          (h == 'amt' && field == CsvField.amount)) {
        return headers[i];
      }
      if (penalties.any((p) => _containsWord(h, p)) ||
          penaltyParts.any(h.contains)) {
        continue;
      }
      candidates.add(i);
    }
    for (final keywords in [
      _headerKeywords[field]!,
      _fallbackKeywords[field] ?? const <String>[],
    ]) {
      String? best;
      var bestScore = 0;
      var bestKeyword = 1 << 20;
      for (final i in candidates) {
        final h = normalized[i];
        for (var k = 0; k < keywords.length; k++) {
          final keyword = keywords[k];
          var score = 0;
          if (h == keyword) {
            score = 3;
          } else if (_containsWord(h, keyword)) {
            score = 2;
          } else if (!_wholeWordFields.contains(field) && h.contains(keyword)) {
            score = 1;
          }
          if (score > 0 &&
              (score > bestScore || (score == bestScore && k < bestKeyword))) {
            best = headers[i];
            bestScore = score;
            bestKeyword = k;
          }
        }
      }
      if (best != null) {
        return best;
      }
    }
    return null;
  }

  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Whether [text] contains [word] bounded by non-letters (or the ends).
  static bool _containsWord(String text, String word) {
    var from = 0;
    while (true) {
      final at = text.indexOf(word, from);
      if (at == -1) {
        return false;
      }
      final end = at + word.length;
      final startOk = at == 0 || !_wordChar.hasMatch(text[at - 1]);
      final endOk = end == text.length || !_wordChar.hasMatch(text[end]);
      if (startOk && endOk) {
        return true;
      }
      from = at + 1;
    }
  }

  /// Chooses the date format for the mapped date column of [data] (see
  /// [detectCsvDateFormat]); [preset]'s format when one is in use.
  CsvDateDetection detectDateFormat(
    CsvImportData data,
    Map<String, String?> columnMapping, {
    bool preferDayFirst = false,
    BankCsvPreset? preset,
  }) {
    if (preset != null) {
      return CsvDateDetection(
        format: preset.dateFormat,
        fitsAll: true,
        ambiguous: false,
        candidates: [preset.dateFormat],
      );
    }
    return detectCsvDateFormat(
      data.columnValues(columnMapping[CsvField.date]),
      preferDayFirst: preferDayFirst,
    );
  }

  /// The decimal separator of the mapped amount column(s) (see
  /// [inferDecimalSeparator]); [preset]'s when one is in use; [fallback]
  /// (the app locale's) when the values give no hint.
  String detectDecimalSeparator(
    CsvImportData data,
    Map<String, String?> columnMapping, {
    required String fallback,
    BankCsvPreset? preset,
  }) {
    if (preset != null) {
      return preset.decimalSeparator;
    }
    return inferDecimalSeparator([
      ...data.columnValues(columnMapping[CsvField.amount]),
      ...data.columnValues(columnMapping[CsvField.debit]),
      ...data.columnValues(columnMapping[CsvField.credit]),
    ], fallback: fallback);
  }

  /// Detects the date format and decimal separator of the mapped columns
  /// and counts the signs of the amounts, off the UI thread (a pass over
  /// every row for every date format; seconds on a phone for a long
  /// file). See [detectDateFormat] and [detectDecimalSeparator].
  Future<CsvColumnAnalysis> analyzeColumns(
    CsvImportData data,
    Map<String, String?> columnMapping, {
    required bool preferDayFirst,
    required String fallbackSeparator,
    BankCsvPreset? preset,
  }) => compute(
    _analyzeColumns,
    _AnalysisRequest(
      data,
      columnMapping,
      preferDayFirst,
      fallbackSeparator,
      preset,
    ),
  );

  static CsvColumnAnalysis _analyzeColumns(_AnalysisRequest request) {
    final service = CsvImportService();
    final separator = service.detectDecimalSeparator(
      request.data,
      request.columnMapping,
      fallback: request.fallbackSeparator,
      preset: request.preset,
    );
    final columns = _Columns(request.data.headers, request.columnMapping);
    final parser = MoneyParser(decimalSeparator: separator);
    var positive = 0;
    var negative = 0;
    if (columns.amount != -1 || (columns.debit != -1 && columns.credit != -1)) {
      for (final row in request.data.rows) {
        if (columns.isVoid(row)) {
          continue;
        }
        final amount = columns.amountOf(row, parser);
        if (amount != null && amount > 0) {
          positive++;
        } else if (amount != null && amount < 0) {
          negative++;
        }
      }
    }
    return CsvColumnAnalysis(
      dateDetection: service.detectDateFormat(
        request.data,
        request.columnMapping,
        preferDayFirst: request.preferDayFirst,
        preset: request.preset,
      ),
      decimalSeparator: separator,
      positiveAmounts: positive,
      negativeAmounts: negative,
    );
  }

  /// Validates the file and, when it is valid, converts its rows, off the
  /// UI thread; see [validateCsvData] and [convertCsvToTransactions].
  Future<CsvPreparedImport> prepareImport({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
    required bool outflowIsNegative,
  }) => compute(
    _prepareImport,
    _PrepareRequest(
      data,
      columnMapping,
      dateFormat,
      decimalSeparator,
      outflowIsNegative,
    ),
  );

  static CsvPreparedImport _prepareImport(_PrepareRequest request) {
    final service = CsvImportService();
    final validation = service.validateCsvData(
      data: request.data,
      columnMapping: request.columnMapping,
      dateFormat: request.dateFormat,
      decimalSeparator: request.decimalSeparator,
      outflowIsNegative: request.outflowIsNegative,
    );
    return CsvPreparedImport(
      validation,
      validation.isValid
          ? service.convertCsvToTransactions(
              data: request.data,
              columnMapping: request.columnMapping,
              dateFormat: request.dateFormat,
              decimalSeparator: request.decimalSeparator,
              outflowIsNegative: request.outflowIsNegative,
            )
          : const [],
    );
  }

  CsvValidationResult validateCsvData({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
    bool outflowIsNegative = true,
  }) {
    final errors = <CsvIssue>[];
    final warnings = <CsvIssue>[];

    final dateCol = columnMapping[CsvField.date];
    final amountCol = columnMapping[CsvField.amount];
    final debitCol = columnMapping[CsvField.debit];
    final creditCol = columnMapping[CsvField.credit];
    final hasAmountSource =
        amountCol != null || (debitCol != null && creditCol != null);

    if (dateCol == null) {
      errors.add(const CsvIssue(CsvIssueKind.dateColumnNotMapped));
    }
    if (!hasAmountSource) {
      errors.add(const CsvIssue(CsvIssueKind.amountColumnNotMapped));
    }

    if (errors.isNotEmpty) {
      return CsvValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final columns = _Columns(data.headers, columnMapping);
    if (columns.date == -1 ||
        (columns.amount == -1 &&
            (columns.debit == -1 || columns.credit == -1))) {
      errors.add(const CsvIssue(CsvIssueKind.mappedColumnsMissing));
      return CsvValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    if (data.rows.isEmpty) {
      errors.add(const CsvIssue(CsvIssueKind.noRows));
      return CsvValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    int invalidDateCount = 0;
    int invalidAmountCount = 0;
    int skipped = 0;
    final amountParser = MoneyParser(
      decimalSeparator: decimalSeparator == ',' ? ',' : '.',
    );
    final validDates = <DateTime>[];
    var inflows = 0;
    var outflows = 0;
    var voidRows = 0;

    for (final row in data.rows) {
      if (columns.isVoid(row)) {
        voidRows++;
        continue;
      }
      final date = columns.dateOf(row, dateFormat);
      if (date == null) {
        invalidDateCount++;
      } else {
        validDates.add(date);
      }
      final amount = columns.amountOf(row, amountParser);
      if (amount == null) {
        invalidAmountCount++;
      }
      if (date == null || amount == null) {
        skipped++;
      } else if (amount != 0) {
        if ((amount > 0) == outflowIsNegative) {
          inflows++;
        } else {
          outflows++;
        }
      }
    }

    final rowCount = data.rows.length - voidRows;
    final limit = skipLimit(rowCount);
    bool blocks(int count) => count > limit || count == rowCount;

    if (voidRows > 0) {
      warnings.add(CsvIssue(CsvIssueKind.voidRows, count: voidRows));
    }

    if (invalidDateCount > 0) {
      (blocks(invalidDateCount) ? errors : warnings).add(
        CsvIssue(
          CsvIssueKind.invalidDates,
          count: invalidDateCount,
          dateFormat: dateFormat,
        ),
      );
    }

    if (invalidAmountCount > 0) {
      (blocks(invalidAmountCount) ? errors : warnings).add(
        CsvIssue(CsvIssueKind.invalidAmounts, count: invalidAmountCount),
      );
    }

    // Income only? One row can be a salary; several rows without a single
    // outflow are a card statement read with the wrong sign.
    if (inflows >= 2 && outflows == 0) {
      warnings.add(CsvIssue(CsvIssueKind.allInflows, count: inflows));
    }

    // Day and month swapped? Only when both orders fit every date.
    if (data.preset == null) {
      final detection = detectCsvDateFormat(
        data.columnValues(dateCol),
        preferDayFirst: isDayFirstFormat(dateFormat),
      );
      if (detection.ambiguous && detection.candidates.contains(dateFormat)) {
        warnings.add(
          CsvIssue(
            CsvIssueKind.ambiguousDateFormat,
            dateFormat: dateFormat,
            otherFormat: detection.candidates.firstWhere(
              (c) => c != dateFormat,
            ),
          ),
        );
      }
    }

    // Date outliers: a date more than a year from the median usually means
    // a typo in the file (a bank export covers a bounded period).
    if (validDates.length >= 5) {
      validDates.sort();
      final medianDate = validDates[validDates.length ~/ 2];
      int outlierCount = 0;

      for (final date in validDates) {
        if (date.difference(medianDate).inDays.abs() > 366) {
          outlierCount++;
        }
      }

      if (outlierCount > 0) {
        warnings.add(CsvIssue(CsvIssueKind.dateOutliers, count: outlierCount));
      }
    }

    return CsvValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      skippedRows: skipped,
      voidRows: voidRows,
    );
  }

  List<ImportTransaction> convertCsvToTransactions({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
    required bool outflowIsNegative,
  }) {
    final transactions = <ImportTransaction>[];
    final columns = _Columns(data.headers, columnMapping);
    final amountParser = MoneyParser(
      decimalSeparator: decimalSeparator == ',' ? ',' : '.',
    );
    final payeePattern = data.preset?.payeeRegExp;

    for (final row in data.rows) {
      if (columns.isVoid(row)) {
        continue; // Reverted, failed or declined (validation counted it).
      }
      final parsedDate = columns.dateOf(row, dateFormat);
      if (parsedDate == null) {
        continue; // Skipped (validation warned about it).
      }
      // Bank dates are calendar days: store as UTC midnight.
      final date = CalendarDate.fromLocalPick(parsedDate);

      final parsedAmount = columns.amountOf(row, amountParser);
      if (parsedAmount == null) {
        continue; // Skip rows with invalid amounts
      }
      // Off: the file shows outflows as positive numbers (credit card
      // statements), so every sign is flipped: charges become negative
      // and refunds/payments (negative in the file) become inflows.
      // A fee comes on top: it leaves the account like the amount does.
      final amount =
          (outflowIsNegative ? parsedAmount : -parsedAmount) -
          columns.feeOf(row, amountParser);

      var payeeName = columns.text(row, columns.payee);
      if (amount > 0 && columns.inflowPayee != -1) {
        // An empty sender cell is no sender: the row keeps its payee.
        payeeName =
            _nonEmpty(columns.text(row, columns.inflowPayee)) ?? payeeName;
      }
      if (payeeName != null && payeePattern != null) {
        final extracted = payeePattern.firstMatch(payeeName)?.group(1)?.trim();
        if (extracted != null && extracted.isNotEmpty) {
          payeeName = extracted;
        }
      }

      transactions.add(
        ImportTransaction(
          date: date,
          amount: amount,
          payeeName: payeeName,
          memo: _nonEmpty(columns.text(row, columns.memo)),
          originalDescription: columns.text(row, columns.payee),
          categoryName: _nonEmpty(columns.text(row, columns.category)),
          cleared: parseClearedCell(columns.text(row, columns.cleared)),
          approved: parseApprovedCell(columns.text(row, columns.approved)),
          accountName: _nonEmpty(columns.text(row, columns.account)),
          transferAccountName: _nonEmpty(columns.text(row, columns.transfer)),
        ),
      );
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }

  static String? _nonEmpty(String? text) =>
      text == null || text.trim().isEmpty ? null : text.trim();

  /// The cleared state a `Cleared`/`Status` cell describes: our own export
  /// (`cleared`, `uncleared`, `reconciled`), yes/no flags, DKB's
  /// `Gebucht`/`Vorgemerkt`, Revolut's `COMPLETED`/`PENDING`. `null` for
  /// an empty or unknown value (the row is then imported cleared).
  static TransactionClearStatus? parseClearedCell(String? cell) {
    final value = cell?.trim().toLowerCase() ?? '';
    if (value.isEmpty) {
      return null;
    }
    if (const {'reconciled', 'r', 'abgestimmt'}.contains(value)) {
      return TransactionClearStatus.reconciled;
    }
    if (const {
      'cleared',
      'c',
      'yes',
      'y',
      'true',
      '1',
      'x',
      '*',
      'gebucht',
      'completed',
      'booked',
      'settled',
    }.contains(value)) {
      return TransactionClearStatus.cleared;
    }
    if (const {
      'uncleared',
      'u',
      'no',
      'n',
      'false',
      '0',
      'vorgemerkt',
      'pending',
      'offen',
    }.contains(value)) {
      return TransactionClearStatus.uncleared;
    }
    return null;
  }

  /// What an `Approved` cell says (our own export writes `Yes`/`No`):
  /// `null` for an empty or unknown value (the row is then imported
  /// approved).
  static bool? parseApprovedCell(String? cell) {
    final value = cell?.trim().toLowerCase() ?? '';
    if (const {'yes', 'y', 'true', '1', 'ja', 'x'}.contains(value)) {
      return true;
    }
    if (const {'no', 'n', 'false', '0', 'nein'}.contains(value)) {
      return false;
    }
    return null;
  }

  /// Whether a `Cleared`/`Status` cell says the row never happened:
  /// Revolut's `REVERTED` (a released hold), `FAILED` and `DECLINED`. Such
  /// rows are left out of the import, with a counted notice.
  static bool isVoidStatusCell(String? cell) => const {
    'reverted',
    'failed',
    'declined',
  }.contains(cell?.trim().toLowerCase());

  /// Sets [ImportTransaction.categoryId] of every row whose file category
  /// ([ImportTransaction.categoryName]) names an existing category.
  ///
  /// Matching ignores case and surrounding / repeated whitespace. A cell
  /// matches a category by its name alone ("Groceries") or qualified by
  /// its group ("Food: Groceries", as YNAB and many spreadsheets write
  /// it). A bare name that exists in more than one group is ambiguous and
  /// only matches in the qualified form. Categories are never created:
  /// rows whose category is not found stay unassigned
  /// ([ImportTransaction.hasUnmatchedCategory]).
  void assignCategories({
    required List<ImportTransaction> imported,
    required List<Category> categories,
    required List<CategoryGroup> groups,
  }) {
    final groupNames = {for (final g in groups) g.id: g.name};
    final byName = <String, String?>{};
    final byQualified = <String, String>{};
    for (final c in categories) {
      final key = _categoryKey(c.name);
      byName[key] = byName.containsKey(key) ? null : c.id;
      final group = groupNames[c.categoryGroupId];
      if (group != null) {
        byQualified['${_categoryKey(group)}:$key'] = c.id;
      }
    }
    for (final row in imported) {
      final name = row.categoryName;
      if (name == null || name.trim().isEmpty) {
        continue;
      }
      final key = _categoryKey(name);
      String? id = byName[key];
      // "Group: Category"; a name may contain a colon itself, so every
      // colon is tried as the separator.
      for (
        var colon = key.indexOf(':');
        id == null && colon != -1;
        colon = key.indexOf(':', colon + 1)
      ) {
        id =
            byQualified['${key.substring(0, colon).trim()}:'
                '${key.substring(colon + 1).trim()}'];
      }
      row.categoryId = id;
    }
  }

  static String _categoryKey(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Payee names compared trimmed, lower-cased, inner whitespace collapsed.
  static String normalizePayee(String? name) => _categoryKey(name ?? '');

  /// How many days an existing transaction with the same amount may lie
  /// from an imported row to make it a possible duplicate: a card payment
  /// entered on the day of the purchase is often booked by the bank a few
  /// days later (Friday evening to Tuesday).
  static const int possibleDuplicateWindowDays = 4;

  /// Flags rows of [imported] that already exist in [existing] (the
  /// transactions of the account the rows go into).
  ///
  /// **Duplicate**: an existing transaction on the same calendar day with
  /// the same amount whose payee name (normalised) equals the row's file
  /// payee or its [ImportTransaction.rulePayeeName] (the name a rule
  /// rewrote it to); a row without payee matches an existing transaction
  /// without payee. This is a re-import of the same bank row.
  ///
  /// **Possible duplicate**: of the existing transactions left over, one
  /// with the same amount at most [possibleDuplicateWindowDays] days away,
  /// whatever its payee: the purchase entered by hand or by quick-add
  /// under another name, a renamed payee, a booking date that differs from
  /// the purchase date. The nearest day wins.
  ///
  /// Each existing transaction matches at most one row (two identical
  /// coffees in the file against one existing row flag one). Both kinds
  /// are deselected; the user decides.
  void checkForDuplicates({
    required List<ImportTransaction> imported,
    required List<Transaction> existing,
    required Map<String, String> payeeMap,
  }) {
    DateTime dayOf(DateTime d) => CalendarDate.normalize(d);
    String exactKey(DateTime d, int amount, String payee) =>
        '${dayOf(d).toIso8601String()}|$amount|$payee';
    String? payeeOf(Transaction tx) {
      final name = tx.payeeId != null ? payeeMap[tx.payeeId] : null;
      return name == null || name.trim().isEmpty ? null : name;
    }

    // Existing rows not matched yet: by day, amount and payee for the
    // exact rule, by amount for the possible-duplicate rule.
    final exact = <String, List<Transaction>>{};
    final byAmount = <int, List<Transaction>>{};
    for (final tx in existing) {
      exact
          .putIfAbsent(
            exactKey(tx.date, tx.amount, normalizePayee(payeeOf(tx))),
            () => [],
          )
          .add(tx);
      byAmount.putIfAbsent(tx.amount, () => []).add(tx);
    }

    for (final tx in imported) {
      tx.isDuplicate = false;
      tx.isPossibleDuplicate = false;
      tx.possibleDuplicateDate = null;
      tx.possibleDuplicatePayee = null;
      final names = {
        normalizePayee(tx.payeeName),
        normalizePayee(tx.rulePayeeName),
      }..remove('');
      // A row without payee against an existing row without payee.
      for (final name in names.isEmpty ? const [''] : names) {
        final matches = exact[exactKey(tx.date, tx.amount, name)];
        if (matches != null && matches.isNotEmpty) {
          byAmount[tx.amount]!.remove(matches.removeLast());
          tx.isDuplicate = true;
          tx.isSelected = false;
          break;
        }
      }
    }

    // Nearest day first, so a row never takes the existing transaction of
    // a closer row.
    for (
      var distance = 0;
      distance <= possibleDuplicateWindowDays;
      distance++
    ) {
      for (final tx in imported) {
        if (tx.isDuplicate || tx.isPossibleDuplicate) {
          continue;
        }
        final candidates = byAmount[tx.amount];
        if (candidates == null || candidates.isEmpty) {
          continue;
        }
        final day = dayOf(tx.date);
        final at = candidates.indexWhere(
          (c) => dayOf(c.date).difference(day).inDays.abs() == distance,
        );
        if (at == -1) {
          continue;
        }
        final match = candidates.removeAt(at);
        tx.isPossibleDuplicate = true;
        tx.possibleDuplicateDate = dayOf(match.date);
        tx.possibleDuplicatePayee = payeeOf(match);
        tx.isSelected = false;
      }
    }
  }
}

class _ParseRequest {
  const _ParseRequest(this.content, this.headerLineIndex, this.hasHeader);
  final String content;
  final int? headerLineIndex;
  final bool? hasHeader;
}

class _AnalysisRequest {
  const _AnalysisRequest(
    this.data,
    this.columnMapping,
    this.preferDayFirst,
    this.fallbackSeparator,
    this.preset,
  );
  final CsvImportData data;
  final Map<String, String?> columnMapping;
  final bool preferDayFirst;
  final String fallbackSeparator;
  final BankCsvPreset? preset;
}

class _PrepareRequest {
  const _PrepareRequest(
    this.data,
    this.columnMapping,
    this.dateFormat,
    this.decimalSeparator,
    this.outflowIsNegative,
  );
  final CsvImportData data;
  final Map<String, String?> columnMapping;
  final String dateFormat;
  final String decimalSeparator;
  final bool outflowIsNegative;
}

/// Column indices of a mapping, with the cell readers shared by validation
/// and conversion.
class _Columns {
  _Columns(List<String> headers, Map<String, String?> mapping)
    : date = _indexOf(headers, mapping[CsvField.date]),
      amount = _indexOf(headers, mapping[CsvField.amount]),
      debit = _indexOf(headers, mapping[CsvField.debit]),
      credit = _indexOf(headers, mapping[CsvField.credit]),
      flag = _indexOf(headers, mapping[CsvField.debitCreditFlag]),
      payee = _indexOf(headers, mapping[CsvField.payee]),
      inflowPayee = _indexOf(headers, mapping[CsvField.inflowPayee]),
      memo = _indexOf(headers, mapping[CsvField.memo]),
      category = _indexOf(headers, mapping[CsvField.category]),
      account = _indexOf(headers, mapping[CsvField.account]),
      transfer = _indexOf(headers, mapping[CsvField.transfer]),
      cleared = _indexOf(headers, mapping[CsvField.cleared]),
      approved = _indexOf(headers, mapping[CsvField.approved]),
      fee = _indexOf(headers, mapping[CsvField.fee]);

  final int date;
  final int amount;
  final int debit;
  final int credit;
  final int flag;
  final int payee;
  final int inflowPayee;
  final int memo;
  final int category;
  final int account;
  final int transfer;
  final int cleared;
  final int approved;
  final int fee;

  static int _indexOf(List<String> headers, String? header) =>
      header == null ? -1 : headers.indexOf(header);

  /// The cell at [index], with the `'` the export sanitiser prefixes to
  /// text starting with `=`, `+`, `-`, `@`, a tab or a carriage return
  /// removed again; `null` when the column is unmapped or the row short.
  String? text(List<dynamic> row, int index) {
    if (index == -1 || row.length <= index) {
      return null;
    }
    return CsvSanitizer.unquote(row[index].toString());
  }

  /// Whether the row's status cell marks it as reverted, failed or
  /// declined (see [CsvImportService.isVoidStatusCell]).
  bool isVoid(List<dynamic> row) =>
      cleared != -1 &&
      row.length > cleared &&
      CsvImportService.isVoidStatusCell(row[cleared].toString());

  /// The fee of [row] as a positive number of minor units; 0 when no fee
  /// column is mapped or the cell is empty or unreadable.
  int feeOf(List<dynamic> row, MoneyParser parser) {
    if (fee == -1 || row.length <= fee) {
      return 0;
    }
    return (parser.tryParse(row[fee].toString()) ?? 0).abs();
  }

  DateTime? dateOf(List<dynamic> row, String format) {
    if (date == -1 || row.length <= date) {
      return null;
    }
    return parseCsvDate(row[date].toString(), format);
  }

  /// The signed amount (minor units) of [row]: the amount column, or
  /// `|credit| - |debit|`; a debit/credit flag column then decides the
  /// sign. `null` when unreadable.
  int? amountOf(List<dynamic> row, MoneyParser parser) {
    int? value;
    if (amount != -1) {
      if (row.length <= amount) {
        return null;
      }
      value = parser.tryParse(row[amount].toString());
    } else {
      if (row.length <= debit || row.length <= credit) {
        return null;
      }
      final debitText = row[debit].toString().trim();
      final creditText = row[credit].toString().trim();
      final debitValue = debitText.isEmpty ? 0 : parser.tryParse(debitText);
      final creditValue = creditText.isEmpty ? 0 : parser.tryParse(creditText);
      if (debitValue == null ||
          creditValue == null ||
          (debitText.isEmpty && creditText.isEmpty)) {
        return null;
      }
      value = creditValue.abs() - debitValue.abs();
    }
    if (value == null) {
      return null;
    }
    if (flag != -1 && row.length > flag) {
      final mark = row[flag].toString().trim().toUpperCase();
      if (mark.startsWith('S') || mark.startsWith('D') || mark == '-') {
        value = -value.abs();
      } else if (mark.startsWith('H') || mark.startsWith('C') || mark == '+') {
        value = value.abs();
      }
    }
    return value;
  }
}
