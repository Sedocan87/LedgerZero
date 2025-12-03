import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PayeeExportService {
  Future<void> exportPayees(List<Payee> payees) async {
    final rows = <List<dynamic>>[
      ['Name', 'Is Favorite', 'Notes', 'Auto Category ID', 'Default Account ID', 'Created At'],
    ];

    for (var p in payees) {
      rows.add([
        p.name,
        p.isFavorite ? 'Yes' : 'No',
        p.notes ?? '',
        p.autoCategoryId ?? '',
        p.defaultAccountId ?? '',
        p.createdAt != null ? DateFormat('yyyy-MM-dd').format(p.createdAt!) : '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'ledger_zero_payees_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$filename');

    await file.writeAsString(csv);

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Payees');
  }
}
