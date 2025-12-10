import 'dart:io';
import 'package:csv/csv.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class TransactionExportService {
  /// Exports a list of transactions to a CSV file and triggers the share sheet.
  ///
  /// [transactions]: The list of transactions to export.
  /// [payeeNames]: A map of payee IDs to names.
  /// [categoryNames]: A map of category IDs to names.
  /// [accountNames]: A map of account IDs to names.
  /// [filenamePrefix]: The prefix for the filename (default: 'transactions_export').
  Future<String> exportTransactionsToCsv({
    required List<Transaction> transactions,
    Map<String, String> payeeNames = const {},
    Map<String, String> categoryNames = const {},
    Map<String, String> accountNames = const {},
    String filenamePrefix = 'transactions_export',
  }) async {
    // Header row
    final rows = <List<dynamic>>[
      [
        'Date',
        'Account',
        'Payee',
        'Category',
        'Memo',
        'Amount',
        'Cleared',
        'Approved'
      ],
    ];

    // Data rows
    for (var t in transactions) {
      final payee =
          t.payeeId != null ? (payeeNames[t.payeeId] ?? t.payeeId) : '';
      final category = t.categoryId != null
          ? (categoryNames[t.categoryId] ?? t.categoryId)
          : '';
      final account = accountNames[t.accountId] ?? t.accountId;

      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        account,
        payee,
        category,
        t.memo ?? '',
        t.amount,
        t.cleared.name,
        t.approved ? 'Yes' : 'No',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = '${filenamePrefix}_$dateStr.csv';
    final file = File('${dir.path}/$filename');

    await file.writeAsString(csv);

    // Share the file
    await SharePlus.instance.share(
      ShareParams(
        text: 'Exported Transactions',
        subject: 'Transaction Export',
        files: [XFile(file.path)],
      ),
    );

    return file.path;
  }
}
