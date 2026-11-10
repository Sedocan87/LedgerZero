import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';

/// The CSV variant a transaction export should write, or `null` when the
/// user cancelled.
///
/// A spreadsheet app set to German (Excel) splits columns at semicolons,
/// expects a decimal comma and needs a byte order mark to read umlauts, so
/// in German the user is offered that variant next to the standard file.
/// Other languages get the standard file without being asked.
Future<TransactionCsvFormat?> chooseTransactionCsvFormat(
  BuildContext context,
) async {
  if (Localizations.localeOf(context).languageCode != 'de') {
    return TransactionCsvFormat.standard;
  }
  final l10n = AppLocalizations.of(context)!;
  return showDialog<TransactionCsvFormat>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.csvExportFormatTitle),
      children: [
        ListTile(
          key: const Key('csv_format_standard'),
          title: Text(l10n.csvExportFormatStandard),
          subtitle: Text(l10n.csvExportFormatStandardHint),
          onTap: () => Navigator.pop(context, TransactionCsvFormat.standard),
        ),
        ListTile(
          key: const Key('csv_format_spreadsheet'),
          title: Text(l10n.csvExportFormatSpreadsheet),
          subtitle: Text(l10n.csvExportFormatSpreadsheetHint),
          onTap: () =>
              Navigator.pop(context, TransactionCsvFormat.germanSpreadsheet),
        ),
      ],
    ),
  );
}
