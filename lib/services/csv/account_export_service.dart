import 'dart:io';
import 'package:csv/csv.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AccountExportService {
  Future<String> exportTransactionsToCsv({
    required List<Transaction> transactions,
    required String accountName,
    Map<String, String> payeeNames = const {},
    Map<String, String> categoryNames = const {},
  }) async {
    final rows = <List<dynamic>>[
      ['Date', 'Payee', 'Category', 'Memo', 'Amount', 'Cleared', 'Approved'],
    ];

    for (var t in transactions) {
      final payee = t.payeeId != null ? (payeeNames[t.payeeId] ?? t.payeeId) : '';
      final category = t.categoryId != null ? (categoryNames[t.categoryId] ?? t.categoryId) : '';

      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
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
    final filename = 'ledger_zero_${accountName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$filename');

    await file.writeAsString(csv);
    return file.path;
  }
}
