import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

class CsvImportData {
  final List<String> headers;
  final List<List<dynamic>> rows;
  final String delimiter;

  CsvImportData({
    required this.headers,
    required this.rows,
    required this.delimiter,
  });
}

/// A problem found while validating a CSV import. The UI turns it into a
/// localised message; [toString] is for logs.
enum CsvIssueKind {
  dateColumnNotMapped,
  amountColumnNotMapped,
  mappedColumnsMissing,

  /// [CsvIssue.count] rows have dates that do not match
  /// [CsvIssue.dateFormat].
  invalidDates,

  /// [CsvIssue.count] rows have unreadable amounts and are skipped.
  invalidAmounts,

  /// [CsvIssue.count] dates are more than 60 days from the median date
  /// (often a wrong date format or a typo in the file).
  dateOutliers,
}

class CsvIssue {
  final CsvIssueKind kind;
  final int count;
  final String? dateFormat;

  const CsvIssue(this.kind, {this.count = 0, this.dateFormat});

  @override
  String toString() =>
      'CsvIssue(${kind.name}, count: $count, dateFormat: $dateFormat)';
}

class CsvValidationResult {
  final bool isValid;
  final List<CsvIssue> errors;
  final List<CsvIssue> warnings;

  CsvValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
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

class CsvImportService {
  Future<CsvImportData> parseCsvFile(PlatformFile file) async {
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

    return compute(_parseCsvInternal, content);
  }

  static CsvImportData _parseCsvInternal(String content) {
    if (content.trim().isEmpty) {
      throw ImportException(ImportFailure.empty, 'The CSV file is empty');
    }

    String delimiter = ',';
    // Detect EOL
    String? eol;
    if (content.contains('\r\n')) {
      eol = '\r\n';
    } else if (content.contains('\n')) {
      eol = '\n';
    } else if (content.contains('\r')) {
      eol = '\r';
    }

    // Simple heuristic: if more semicolons than commas in the first line, use semicolon
    final idx = content.indexOf(RegExp(r'\r\n|\r|\n'));
    final firstLine = idx == -1 ? content : content.substring(0, idx);

    if (firstLine.split(';').length > firstLine.split(',').length) {
      delimiter = ';';
    }

    // Convert CSV
    final List<List<dynamic>> rawRows;
    try {
      rawRows = const CsvToListConverter().convert(
        content,
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

    // Assume first row is header
    if (rawRows.length < 2) {
      // Could be just headers?
      if (rawRows.length == 1) {
        // Valid CSV but no data
        return CsvImportData(
          headers: rawRows.first.map((e) => e.toString()).toList(),
          rows: [],
          delimiter: delimiter,
        );
      }
      // Should not reach here if not empty
    }

    final List<String> headers = rawRows.first
        .map((e) => e.toString())
        .toList();
    final List<List<dynamic>> rows = rawRows.skip(1).toList();

    return CsvImportData(headers: headers, rows: rows, delimiter: delimiter);
  }

  CsvValidationResult validateCsvData({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
  }) {
    final errors = <CsvIssue>[];
    final warnings = <CsvIssue>[];

    final dateCol = columnMapping['Date'];
    final amountCol = columnMapping['Amount'];

    if (dateCol == null) {
      errors.add(const CsvIssue(CsvIssueKind.dateColumnNotMapped));
    }
    if (amountCol == null) {
      errors.add(const CsvIssue(CsvIssueKind.amountColumnNotMapped));
    }

    if (errors.isNotEmpty) {
      return CsvValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final dateIndex = data.headers.indexOf(dateCol!);
    final amountIndex = data.headers.indexOf(amountCol!);

    if (dateIndex == -1 || amountIndex == -1) {
      errors.add(const CsvIssue(CsvIssueKind.mappedColumnsMissing));
      return CsvValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    int invalidDateCount = 0;
    int invalidAmountCount = 0;
    final amountParser = MoneyParser(
      decimalSeparator: decimalSeparator == ',' ? ',' : '.',
    );
    final validDates = <DateTime>[];

    for (int i = 0; i < data.rows.length; i++) {
      final row = data.rows[i];

      // Validate Date
      if (row.length > dateIndex) {
        final dateStr = row[dateIndex].toString();
        try {
          final parsedDate = DateFormat(dateFormat).parseStrict(dateStr);
          validDates.add(parsedDate);
        } catch (e) {
          invalidDateCount++;
        }
      } else {
        invalidDateCount++;
      }

      // Validate Amount
      if (row.length > amountIndex) {
        final amountStr = row[amountIndex].toString();
        if (amountParser.tryParse(amountStr) == null) {
          invalidAmountCount++;
        }
      } else {
        invalidAmountCount++;
      }
    }

    if (invalidDateCount > 0) {
      errors.add(
        CsvIssue(
          CsvIssueKind.invalidDates,
          count: invalidDateCount,
          dateFormat: dateFormat,
        ),
      );
    }

    if (invalidAmountCount > 0) {
      warnings.add(
        CsvIssue(CsvIssueKind.invalidAmounts, count: invalidAmountCount),
      );
    }

    // Date outliers: dates far from the others usually mean the wrong date
    // format was chosen (day and month swapped) or the file has a typo.
    if (validDates.length >= 5) {
      validDates.sort();
      final medianDate = validDates[validDates.length ~/ 2];
      int outlierCount = 0;

      for (final date in validDates) {
        final diff = date.difference(medianDate).inDays.abs();
        // More than 60 days from the median: probably misread.
        if (diff > 60) {
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

    final dateIndex = data.headers.indexOf(columnMapping['Date']!);
    final amountIndex = data.headers.indexOf(columnMapping['Amount']!);
    final payeeIndex = columnMapping['Payee'] != null
        ? data.headers.indexOf(columnMapping['Payee']!)
        : -1;
    final memoIndex = columnMapping['Memo'] != null
        ? data.headers.indexOf(columnMapping['Memo']!)
        : -1;
    final categoryIndex = columnMapping['Category'] != null
        ? data.headers.indexOf(columnMapping['Category']!)
        : -1;

    final dateFmt = DateFormat(dateFormat);
    final amountParser = MoneyParser(
      decimalSeparator: decimalSeparator == ',' ? ',' : '.',
    );

    for (final row in data.rows) {
      try {
        if (row.length <= dateIndex || row.length <= amountIndex) {
          continue;
        }

        final dateStr = row[dateIndex].toString();
        final amountStr = row[amountIndex].toString();

        DateTime date;
        try {
          // Bank dates are calendar days: store as UTC midnight.
          date = CalendarDate.fromLocalPick(dateFmt.parse(dateStr));
        } catch (_) {
          continue; // Skip invalid rows (should be caught by validation)
        }

        // Parse amount into minor units (both decimal styles accepted;
        // the profile's separator resolves "1.234" / "1,234").
        final parsedAmount = amountParser.tryParse(amountStr);
        if (parsedAmount == null) {
          continue; // Skip rows with invalid amounts
        }
        // Off: the file shows outflows as positive numbers (credit card
        // statements), so every sign is flipped: charges become negative
        // and refunds/payments (negative in the file) become inflows.
        final amount = outflowIsNegative ? parsedAmount : -parsedAmount;

        String? payeeName;
        if (payeeIndex != -1 && row.length > payeeIndex) {
          payeeName = row[payeeIndex].toString();
        }

        String? memo;
        if (memoIndex != -1 && row.length > memoIndex) {
          memo = row[memoIndex].toString();
        }

        String? categoryName;
        if (categoryIndex != -1 && row.length > categoryIndex) {
          final text = row[categoryIndex].toString().trim();
          categoryName = text.isEmpty ? null : text;
        }

        transactions.add(
          ImportTransaction(
            date: date,
            amount: amount,
            payeeName: payeeName,
            memo: memo,
            originalDescription: payeeName,
            categoryName: categoryName,
          ),
        );
      } catch (e) {
        continue;
      }
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
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

  void checkForDuplicates({
    required List<ImportTransaction> imported,
    required List<Transaction> existing,
    required Map<String, String> payeeMap,
  }) {
    final existingHashes = <String>{};

    for (final tx in existing) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final amountStr = tx.amount.toString(); // minor units
      final payeeName = tx.payeeId != null ? (payeeMap[tx.payeeId] ?? '') : '';

      final raw = '$dateStr|$amountStr|$payeeName';
      final hash = sha256.convert(utf8.encode(raw)).toString();
      existingHashes.add(hash);
    }

    for (final tx in imported) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final amountStr = tx.amount.toString(); // minor units
      final payeeName = tx.payeeName ?? '';

      final raw = '$dateStr|$amountStr|$payeeName';
      final hash = sha256.convert(utf8.encode(raw)).toString();

      if (existingHashes.contains(hash)) {
        tx.isDuplicate = true;
        tx.isSelected = false;
      }
    }
  }
}
