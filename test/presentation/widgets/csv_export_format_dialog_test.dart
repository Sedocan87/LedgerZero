import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/csv_export_format_dialog.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';

void main() {
  Future<List<TransactionCsvFormat?>> pump(
    WidgetTester tester,
    String language,
  ) async {
    final results = <TransactionCsvFormat?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(language),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await chooseTransactionCsvFormat(context)),
            child: const Text('export'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('English: the standard file, without a question', (tester) async {
    final results = await pump(tester, 'en');
    expect(results, [TransactionCsvFormat.standard]);
    expect(find.byType(SimpleDialog), findsNothing);
  });

  testWidgets('German: the Excel variant is offered', (tester) async {
    final results = await pump(tester, 'de');
    expect(results, isEmpty);
    expect(find.text('Für Excel (Semikolon, Dezimalkomma)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('csv_format_spreadsheet')));
    await tester.pumpAndSettle();
    expect(results, [TransactionCsvFormat.germanSpreadsheet]);

    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // Dismissed: cancelled.
    await tester.pumpAndSettle();
    expect(results, [TransactionCsvFormat.germanSpreadsheet, null]);
  });
}
