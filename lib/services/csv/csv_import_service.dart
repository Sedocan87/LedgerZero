import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
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

class CsvValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  CsvValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

class ImportException implements Exception {
  final String message;
  ImportException(this.message);
  @override
  String toString() => message;
}

class CsvImportService {
  Future<CsvImportData> parseCsvFile(PlatformFile file) async {
    String content;
    try {
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw ImportException('File content not available');
      }
    } catch (e) {
      throw ImportException('Failed to read file: ${e.toString()}');
    }

    return compute(_parseCsvInternal, content);
  }

  static CsvImportData _parseCsvInternal(String content) {
    if (content.trim().isEmpty) {
      throw ImportException('The CSV file is empty.');
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
    final firstLine = content.split(RegExp(r'\r\n|\r|\n')).firstOrNull ?? '';
    if (firstLine.split(';').length > firstLine.split(',').length) {
      delimiter = ';';
    }

    // Convert CSV
    List<List<dynamic>> rawRows;
    try {
      rawRows = const CsvToListConverter().convert(
        content,
        fieldDelimiter: delimiter,
        eol: eol,
        shouldParseNumbers: false,
      );
    } catch (e) {
      throw ImportException('Failed to parse CSV format: ${e.toString()}');
    }

    if (rawRows.isEmpty) {
       throw ImportException('No data found in the CSV file.');
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

    List<String> headers = rawRows.first.map((e) => e.toString()).toList();
    List<List<dynamic>> rows = rawRows.skip(1).toList();

    return CsvImportData(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
    );
  }

  CsvValidationResult validateCsvData({
    required CsvImportData data,
    required Map<String, String?> columnMapping,
    required String dateFormat,
    required String decimalSeparator,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    final dateCol = columnMapping['Date'];
    final amountCol = columnMapping['Amount'];

    if (dateCol == null) {
      errors.add('Date column is not mapped.');
    }
    if (amountCol == null) {
      errors.add('Amount column is not mapped.');
    }

    if (errors.isNotEmpty) {
      return CsvValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    final dateIndex = data.headers.indexOf(dateCol!);
    final amountIndex = data.headers.indexOf(amountCol!);

    if (dateIndex == -1 || amountIndex == -1) {
       errors.add('Mapped columns not found in CSV headers.');
       return CsvValidationResult(isValid: false, errors: errors, warnings: warnings);
    }

    int invalidDateCount = 0;
    int invalidAmountCount = 0;

    for (int i = 0; i < data.rows.length; i++) {
      final row = data.rows[i];

      // Validate Date
      if (row.length > dateIndex) {
        final dateStr = row[dateIndex].toString();
        try {
          DateFormat(dateFormat).parseStrict(dateStr);
        } catch (e) {
          invalidDateCount++;
        }
      } else {
        invalidDateCount++;
      }

      // Validate Amount
      if (row.length > amountIndex) {
        final amountStr = row[amountIndex].toString();
        // Handle decimal separator
        String normalizedAmount = amountStr;
        if (decimalSeparator == ',') {
           normalizedAmount = normalizedAmount.replaceAll('.', '').replaceAll(',', '.');
        } else {
           normalizedAmount = normalizedAmount.replaceAll(',', '');
        }
        // Remove currency symbols and spaces
        normalizedAmount = normalizedAmount.replaceAll(RegExp(r'[^\d.-]'), '');

        if (double.tryParse(normalizedAmount) == null) {
          invalidAmountCount++;
        }
      } else {
        invalidAmountCount++;
      }
    }

    if (invalidDateCount > 0) {
      errors.add('$invalidDateCount rows have invalid dates (format: $dateFormat).');
    }

    if (invalidAmountCount > 0) {
      errors.add('$invalidAmountCount rows have invalid amounts.');
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
    final payeeIndex = columnMapping['Payee'] != null ? data.headers.indexOf(columnMapping['Payee']!) : -1;
    final memoIndex = columnMapping['Memo'] != null ? data.headers.indexOf(columnMapping['Memo']!) : -1;

    final dateFmt = DateFormat(dateFormat);

    for (final row in data.rows) {
      try {
        if (row.length <= dateIndex || row.length <= amountIndex) continue;

        final dateStr = row[dateIndex].toString();
        final amountStr = row[amountIndex].toString();

        DateTime date;
        try {
          date = dateFmt.parse(dateStr);
        } catch (_) {
          continue; // Skip invalid rows (should be caught by validation)
        }

        // Parse amount
        String normalizedAmount = amountStr;
        if (decimalSeparator == ',') {
           normalizedAmount = normalizedAmount.replaceAll('.', '').replaceAll(',', '.');
        } else {
           normalizedAmount = normalizedAmount.replaceAll(',', '');
        }
        normalizedAmount = normalizedAmount.replaceAll(RegExp(r'[^\d.-]'), '');

        double amount = double.tryParse(normalizedAmount) ?? 0.0;
        if (!outflowIsNegative && amount > 0) {
            amount = -amount;
        }

        String? payeeName;
        if (payeeIndex != -1 && row.length > payeeIndex) {
          payeeName = row[payeeIndex].toString();
        }

        String? memo;
        if (memoIndex != -1 && row.length > memoIndex) {
          memo = row[memoIndex].toString();
        }

        transactions.add(ImportTransaction(
          date: date,
          amount: amount,
          payeeName: payeeName,
          memo: memo,
          originalDescription: payeeName,
        ));
      } catch (e) {
        continue;
      }
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }

  void checkForDuplicates({
    required List<ImportTransaction> imported,
    required List<Transaction> existing,
    required Map<String, String> payeeMap,
  }) {
    final existingHashes = <String>{};

    for (final tx in existing) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final amountStr = tx.amount.toStringAsFixed(2);
      final payeeName = tx.payeeId != null ? (payeeMap[tx.payeeId] ?? '') : '';

      final raw = '$dateStr|$amountStr|$payeeName';
      final hash = sha256.convert(utf8.encode(raw)).toString();
      existingHashes.add(hash);
    }

    for (final tx in imported) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final amountStr = tx.amount.toStringAsFixed(2);
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
