import 'package:csv/csv.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

class TransactionExportService {
  final ExportFileService _files;

  TransactionExportService({ExportFileService? files})
    : _files = files ?? ExportFileService();

  /// Builds the CSV text. Text cells (payee, memo, names) are neutralised
  /// against formula injection; dates and amounts stay plain values.
  String buildCsv({
    required List<Transaction> transactions,
    Map<String, String> payeeNames = const {},
    Map<String, String> categoryNames = const {},
    Map<String, String> accountNames = const {},
  }) {
    // Header names, ISO dates and plain numbers are a machine format and
    // stay English in every app language, so the file re-imports and opens
    // in any spreadsheet regardless of locale (CsvImportService recognises
    // these headers).
    final rows = <List<Object?>>[
      [
        'Date',
        'Account',
        'Payee',
        'Category',
        'Memo',
        'Amount',
        'Cleared',
        'Approved',
      ],
    ];

    // A split is exported as its lines (each with its category); the parent
    // row is left out so the amounts add up exactly once and a re-import
    // gives the same balances. Lines without a payee show the parent's.
    final byId = {for (final t in transactions) t.id: t};
    final splitParentIds = {
      for (final t in transactions)
        if (t.parentTransactionId != null) t.parentTransactionId!,
    };

    for (var t in transactions) {
      if (splitParentIds.contains(t.id)) {
        continue;
      }
      final payeeId = t.payeeId ?? byId[t.parentTransactionId]?.payeeId;
      final payee = payeeId != null ? (payeeNames[payeeId] ?? payeeId) : '';
      final category = t.categoryId != null
          ? (categoryNames[t.categoryId] ?? t.categoryId)
          : '';
      final account = accountNames[t.accountId] ?? t.accountId;

      rows.add([
        CsvLiteral(DateFormat('yyyy-MM-dd').format(t.date)),
        account,
        payee,
        category,
        t.memo ?? '',
        // Plain decimal in major units, e.g. -12.50 (amounts are minor units).
        CsvLiteral(Money.toDecimalString(t.amount)),
        CsvLiteral(t.cleared.name),
        CsvLiteral(t.approved ? 'Yes' : 'No'),
      ]);
    }
    return const ListToCsvConverter().convert(CsvSanitizer.rows(rows));
  }

  /// Exports a list of transactions to a CSV file and triggers the share sheet.
  ///
  /// [transactions]: The list of transactions to export.
  /// [payeeNames]: A map of payee IDs to names.
  /// [categoryNames]: A map of category IDs to names.
  /// [accountNames]: A map of account IDs to names.
  /// [filenamePrefix]: The prefix for the filename (default: 'transactions_export').
  /// [shareText]: Localised text for the share sheet.
  ///
  /// The file is a data export: English column names, ISO dates and plain
  /// decimal amounts, whatever the app language, so spreadsheets, scripts
  /// and the CSV import read it the same way everywhere.
  Future<String> exportTransactionsToCsv({
    required List<Transaction> transactions,
    Map<String, String> payeeNames = const {},
    Map<String, String> categoryNames = const {},
    Map<String, String> accountNames = const {},
    String filenamePrefix = 'transactions_export',
    String? shareText,
  }) async {
    final csv = buildCsv(
      transactions: transactions,
      payeeNames: payeeNames,
      categoryNames: categoryNames,
      accountNames: accountNames,
    );

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = await _files.writeString(
      '${filenamePrefix}_$dateStr.csv',
      csv,
    );
    // Deleted once the share sheet is done (see ExportFileService).
    await _files.shareAndDelete(file, text: shareText, subject: shareText);
    return file.path;
  }
}
