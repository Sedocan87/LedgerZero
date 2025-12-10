import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/services/import/models/mint_import_data.dart';

/// Service responsible for parsing Mint.com CSV export files.
class MintImportService {
  /// Parses Mint CSV export content.
  ///
  /// [csvContent]: Content of the 'transactions.csv' file from Mint.
  MintImportData parseCsvExport(String csvContent) {
    final transactions = <MintTransaction>[];
    final accountsMap = <String, MintAccount>{};
    final categoriesSet = <String>{};

    String? detectEol(String content) {
      if (content.contains('\r\n')) {
        return '\r\n';
      }
      if (content.contains('\n')) {
        return '\n';
      }
      if (content.contains('\r')) {
        return '\r';
      }
      return null;
    }

    final eol = detectEol(csvContent);
    final rows = const CsvToListConverter().convert(
      csvContent,
      shouldParseNumbers: false,
      eol: eol,
    );

    if (rows.isEmpty) {
      return MintImportData(
        accounts: [],
        categories: [],
        transactions: [],
        importedAt: DateTime.now(),
      );
    }

    // Headers: "Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    final dateIdx = headers.indexOf('Date');
    final descIdx = headers.indexOf('Description');
    final origDescIdx = headers.indexOf('Original Description');
    final amountIdx = headers.indexOf('Amount');
    final typeIdx = headers.indexOf('Transaction Type');
    final catIdx = headers.indexOf('Category');
    final accIdx = headers.indexOf('Account Name');
    final labelsIdx = headers.indexOf('Labels');
    final notesIdx = headers.indexOf('Notes');

    final missingColumns = <String>[];
    if (dateIdx == -1) {
      missingColumns.add('Date');
    }
    if (descIdx == -1) {
      missingColumns.add('Description');
    }
    if (amountIdx == -1) {
      missingColumns.add('Amount');
    }
    if (typeIdx == -1) {
      missingColumns.add('Transaction Type');
    }
    if (catIdx == -1) {
      missingColumns.add('Category');
    }
    if (accIdx == -1) {
      missingColumns.add('Account Name');
    }

    if (missingColumns.isNotEmpty) {
      throw Exception(
          'Invalid Mint CSV format: Missing required columns: ${missingColumns.join(', ')}');
    }

    for (final row in dataRows) {
      if (row.length < headers.length) {
        continue;
      }

      try {
        // 1. Date
        final dateStr = row[dateIdx].toString();
        DateTime date;
        try {
          // Mint usually uses M/d/yyyy (e.g., 6/09/2020)
          date = DateFormat('M/d/yyyy').parse(dateStr);
        } catch (_) {
          // Fallback to MM/dd/yyyy
          try {
             date = DateFormat('MM/dd/yyyy').parse(dateStr);
          } catch(__) {
             // Fallback to ISO
             date = DateTime.parse(dateStr);
          }
        }

        // 2. Amount & Type
        final amountStr = row[amountIdx].toString();
        // Remove currency symbols ($) and commas
        // 1,234.50 -> 1234.50
        String cleanAmountStr = amountStr.replaceAll(RegExp(r'[^\d.,-]'), ''); // Keep digits, dots, commas, minus

        // Handle comma as thousand separator (standard Mint CSV is US based usually)
        if (cleanAmountStr.contains(',')) {
          cleanAmountStr = cleanAmountStr.replaceAll(',', '');
        }

        double amount = double.tryParse(cleanAmountStr) ?? 0.0;

        final type = row[typeIdx].toString().toLowerCase(); // debit, credit

        // Mint exports absolute amounts.
        // debit = expense (outflow), credit = income (inflow)
        // LedgerZero: Income is positive, Expense is negative.
        if (type == 'debit' || type == 'buy') {
          amount = -amount.abs();
        } else {
          // credit, sell, income, etc.
          amount = amount.abs();
        }

        // 3. Other fields
        final description = row[descIdx].toString();
        final originalDescription = origDescIdx != -1 ? row[origDescIdx].toString() : '';
        final category = row[catIdx].toString();
        final accountName = row[accIdx].toString();
        final labels = labelsIdx != -1 ? row[labelsIdx].toString() : '';
        final notes = notesIdx != -1 ? row[notesIdx].toString() : '';

        // Collect unique categories
        if (category.isNotEmpty) {
          categoriesSet.add(category);
        }

        // Collect accounts (infer type later, default checking for now)
        if (!accountsMap.containsKey(accountName)) {
           accountsMap[accountName] = MintAccount(
             name: accountName,
             type: AccountType.checking, // Default, update logic if possible
           );
        }

        transactions.add(MintTransaction(
          date: date,
          description: description,
          originalDescription: originalDescription,
          amount: amount,
          transactionType: type,
          category: category,
          accountName: accountName,
          labels: labels,
          notes: notes,
        ));
      } catch (e) {
        Logger.warning('Failed to parse Mint row: $row. Error: $e');
        continue;
      }
    }

    return MintImportData(
      accounts: accountsMap.values.toList(),
      categories: categoriesSet.toList(),
      transactions: transactions,
      importedAt: DateTime.now(),
    );
  }
}
