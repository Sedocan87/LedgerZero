import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

class PayeeExportService {
  final ExportFileService _files;

  PayeeExportService({ExportFileService? files})
    : _files = files ?? ExportFileService();

  /// Headers and Yes/No flags are a machine format and stay English in
  /// every app language (like the transaction export).
  String buildCsv(List<Payee> payees) {
    final rows = <List<Object?>>[
      [
        'Name',
        'Is Favorite',
        'Notes',
        'Auto Category ID',
        'Default Account ID',
        'Created At',
      ],
    ];

    for (var p in payees) {
      rows.add([
        p.name,
        CsvLiteral(p.isFavorite ? 'Yes' : 'No'),
        p.notes ?? '',
        p.autoCategoryId ?? '',
        p.defaultAccountId ?? '',
        CsvLiteral(
          p.createdAt != null
              ? DateFormat('yyyy-MM-dd').format(p.createdAt!)
              : '',
        ),
      ]);
    }

    return const ListToCsvConverter().convert(CsvSanitizer.rows(rows));
  }

  /// Shares [payees] as CSV (a data export with English column names);
  /// [shareText] is the localised share sheet text.
  Future<void> exportPayees(List<Payee> payees, {String? shareText}) async {
    final file = await _files.writeString(
      'ledger_zero_payees_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      buildCsv(payees),
    );
    await _files.shareAndDelete(file, text: shareText);
  }
}
