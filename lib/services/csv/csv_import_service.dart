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

  /// The bank preset whose header fingerprint matched, or `null`.
  final BankCsvPreset? preset;

  CsvImportData({
    required this.headers,
    required this.rows,
    required this.delimiter,
    this.headerLineIndex = 0,
    this.preset,
  });

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

  CsvValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.skippedRows = 0,
  });
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
    'value',
    'summe',
  ],
  CsvField.debit: ['soll', 'debit', 'ausgang', 'belastung', 'outflow'],
  CsvField.credit: ['haben', 'credit', 'eingang', 'gutschrift', 'inflow'],
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
    'description',
    'desc',
    'buchungstext',
    'name',
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
  CsvField.debit: ['ursprungsbetrag', 'soll/haben'],
  CsvField.credit: [],
  CsvField.debitCreditFlag: [],
  CsvField.payee: ['iban', 'bic', 'kontonummer', 'account number', 'id'],
  CsvField.inflowPayee: ['iban', 'bic'],
  CsvField.memo: ['mandatsreferenz', 'kundenreferenz', 'gläubiger'],
  CsvField.category: [],
  CsvField.account: ['iban', 'number', 'nummer', 'nr'],
  CsvField.transfer: [],
  CsvField.cleared: [],
};

/// Fields whose header must equal a keyword or contain it as a whole word
/// (a substring is not enough: `Auftragskonto` is not an account column).
const Set<String> _wholeWordFields = {
  CsvField.account,
  CsvField.transfer,
  CsvField.cleared,
  CsvField.debitCreditFlag,
  CsvField.debit,
  CsvField.credit,
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

  Future<CsvImportData> parseCsvFile(
    PlatformFile file, {
    int? headerLineIndex,
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

    return compute(_parseCsvInternal, _ParseRequest(content, headerLineIndex));
  }

  /// Parses CSV text (see [parseCsvFile]); [headerLineIndex] forces the
  /// header line instead of detecting it.
  CsvImportData parseCsvContent(String content, {int? headerLineIndex}) =>
      _parseCsvInternal(_ParseRequest(content, headerLineIndex));

  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

  static CsvImportData _parseCsvInternal(_ParseRequest request) {
    final content = request.content;
    if (content.trim().isEmpty) {
      throw ImportException(ImportFailure.empty, 'The CSV file is empty');
    }

    // Detect EOL
    String? eol;
    if (content.contains('\r\n')) {
      eol = '\r\n';
    } else if (content.contains('\n')) {
      eol = '\n';
    } else if (content.contains('\r')) {
      eol = '\r';
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

    var headerIndex = request.headerLineIndex ?? _detectHeaderLine(lines) ?? 0;
    if (headerIndex >= lines.length) {
      headerIndex = 0;
    }
    final delimiter = _delimiterOf(lines[headerIndex]);
    final body = content.substring(lineStarts[headerIndex]);

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

    final headers = _uniqueHeaders(rawRows.first);
    // Blank lines (the csv package yields [''] for them) and footer lines
    // without content are dropped; other footer lines (balances) fail the
    // date check and are skipped there.
    final rows = [
      for (final row in rawRows.skip(1))
        if (row.any((cell) => cell.toString().trim().isNotEmpty)) row,
    ];

    return CsvImportData(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
      headerLineIndex: headerIndex,
      preset: BankCsvPreset.detect(headers),
    );
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

    for (final field in CsvField.all) {
      if ((field == CsvField.debit || field == CsvField.credit) &&
          mapping[CsvField.amount] != null) {
        // Separate debit/credit columns only when there is no amount.
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
      String? best;
      var bestScore = 0;
      var bestKeyword = 1 << 20;
      for (var i = 0; i < headers.length; i++) {
        if (used.contains(headers[i])) {
          continue;
        }
        final h = normalized[i];
        if ((h == 'dt' && field == CsvField.date) ||
            (h == 'amt' && field == CsvField.amount)) {
          best = headers[i];
          bestScore = 3;
          break;
        }
        if (_headerPenalties[field]!.any((p) => _containsWord(h, p))) {
          continue;
        }
        final keywords = _headerKeywords[field]!;
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
        mapping[field] = best;
        used.add(best);
      }
    }
    // Debit without credit (or the reverse) is not an amount source.
    if (mapping[CsvField.debit] == null || mapping[CsvField.credit] == null) {
      mapping[CsvField.debit] = null;
      mapping[CsvField.credit] = null;
    }
    return mapping;
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

  CsvValidationResult validateCsvData({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
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

    for (final row in data.rows) {
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
      }
    }

    final limit = skipLimit(data.rows.length);
    bool blocks(int count) => count > limit || count == data.rows.length;

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
      final amount = outflowIsNegative ? parsedAmount : -parsedAmount;

      var payeeName = columns.text(row, columns.payee);
      if (amount > 0 && columns.inflowPayee != -1) {
        payeeName = columns.text(row, columns.inflowPayee) ?? payeeName;
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
      if (id == null && key.contains(':')) {
        final colon = key.indexOf(':');
        final qualified =
            '${key.substring(0, colon).trim()}:'
            '${key.substring(colon + 1).trim()}';
        id = byQualified[qualified];
      }
      row.categoryId = id;
    }
  }

  static String _categoryKey(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Payee names compared trimmed, lower-cased, inner whitespace collapsed.
  static String normalizePayee(String? name) => _categoryKey(name ?? '');

  /// Flags rows of [imported] that already exist in [existing].
  ///
  /// A row is a duplicate of an existing transaction on the same calendar
  /// day with the same amount whose payee name (normalised) equals the
  /// row's file payee or its [ImportTransaction.rulePayeeName] (the name a
  /// rule rewrote it to). Each existing transaction matches at most one row
  /// (two identical coffees in the file against one existing row flag
  /// one). Rows left over that match an existing transaction *without*
  /// payee (a hand-entered transfer, for instance) by day and amount are
  /// [ImportTransaction.isPossibleDuplicate]. Both kinds are deselected.
  void checkForDuplicates({
    required List<ImportTransaction> imported,
    required List<Transaction> existing,
    required Map<String, String> payeeMap,
  }) {
    final byPayee = <String, int>{};
    final withoutPayee = <String, int>{};
    String day(DateTime d) => CalendarDate.normalize(d).toIso8601String();

    for (final tx in existing) {
      final key = '${day(tx.date)}|${tx.amount}';
      final payeeName = tx.payeeId != null ? payeeMap[tx.payeeId] : null;
      if (payeeName == null || payeeName.trim().isEmpty) {
        withoutPayee[key] = (withoutPayee[key] ?? 0) + 1;
      } else {
        final full = '$key|${normalizePayee(payeeName)}';
        byPayee[full] = (byPayee[full] ?? 0) + 1;
      }
    }

    bool take(Map<String, int> counts, String key) {
      final count = counts[key] ?? 0;
      if (count <= 0) {
        return false;
      }
      counts[key] = count - 1;
      return true;
    }

    for (final tx in imported) {
      tx.isDuplicate = false;
      tx.isPossibleDuplicate = false;
      final key = '${day(tx.date)}|${tx.amount}';
      final names = {
        normalizePayee(tx.payeeName),
        normalizePayee(tx.rulePayeeName),
      }..remove('');
      var found = false;
      for (final name in names) {
        if (take(byPayee, '$key|$name')) {
          found = true;
          break;
        }
      }
      if (!found && names.isEmpty) {
        // A row without payee against an existing row without payee.
        found = take(withoutPayee, key);
      }
      if (found) {
        tx.isDuplicate = true;
        tx.isSelected = false;
      }
    }

    for (final tx in imported) {
      if (tx.isDuplicate) {
        continue;
      }
      final key = '${day(tx.date)}|${tx.amount}';
      if (take(withoutPayee, key)) {
        tx.isPossibleDuplicate = true;
        tx.isSelected = false;
      }
    }
  }
}

class _ParseRequest {
  const _ParseRequest(this.content, this.headerLineIndex);
  final String content;
  final int? headerLineIndex;
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
      cleared = _indexOf(headers, mapping[CsvField.cleared]);

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
