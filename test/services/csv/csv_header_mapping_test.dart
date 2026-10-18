import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/csv/decimal_separator_inference.dart';

void main() {
  group('CsvImportService.autoMapColumns', () {
    test(
      'Sparkasse: "Betrag" wins over "Lastschrift Ursprungsbetrag" (I3)',
      () {
        final mapping = CsvImportService.autoMapColumns([
          'Auftragskonto',
          'Buchungstag',
          'Valutadatum',
          'Buchungstext',
          'Verwendungszweck',
          'Glaeubiger ID',
          'Mandatsreferenz',
          'Kundenreferenz (End-to-End)',
          'Sammlerreferenz',
          'Lastschrift Ursprungsbetrag',
          'Auslagenersatz Ruecklastschrift',
          'Beguenstigter/Zahlungspflichtiger',
          'Kontonummer/IBAN',
          'BIC (SWIFT-Code)',
          'Betrag',
          'Waehrung',
          'Info',
        ]);
        expect(mapping[CsvField.amount], 'Betrag');
        expect(mapping[CsvField.date], 'Buchungstag');
        expect(mapping[CsvField.payee], 'Beguenstigter/Zahlungspflichtiger');
        expect(mapping[CsvField.memo], 'Verwendungszweck');
        expect(
          mapping[CsvField.account],
          isNull,
          reason: 'Auftragskonto is an IBAN',
        );
        expect(mapping[CsvField.debit], isNull);
        expect(mapping[CsvField.credit], isNull);
      },
    );

    test('whole-word matches beat substrings; the booking date beats the '
        'value date', () {
      final mapping = CsvImportService.autoMapColumns([
        'Wertstellung',
        'Buchungstag',
        'Saldo nach Buchung',
        'Betrag (EUR)',
        'Bankname Auftragskonto',
        'Name Zahlungsbeteiligter',
      ]);
      expect(mapping[CsvField.date], 'Buchungstag');
      expect(mapping[CsvField.amount], 'Betrag (EUR)');
      expect(mapping[CsvField.payee], 'Name Zahlungsbeteiligter');
    });

    test('separate debit and credit columns are mapped when there is no '
        'amount column', () {
      final mapping = CsvImportService.autoMapColumns([
        'Buchungstag',
        'Verwendungszweck',
        'Soll',
        'Haben',
        'Währung',
      ]);
      expect(mapping[CsvField.amount], isNull);
      expect(mapping[CsvField.debit], 'Soll');
      expect(mapping[CsvField.credit], 'Haben');
    });

    test('the export columns of this app map back, including Account, '
        'Transfer and Cleared', () {
      final mapping = CsvImportService.autoMapColumns([
        'Date',
        'Account',
        'Payee',
        'Category',
        'Memo',
        'Amount',
        'Cleared',
        'Approved',
        'Transfer',
      ]);
      expect(mapping, {
        CsvField.date: 'Date',
        CsvField.amount: 'Amount',
        CsvField.payee: 'Payee',
        CsvField.memo: 'Memo',
        CsvField.category: 'Category',
        CsvField.debit: null,
        CsvField.credit: null,
        CsvField.debitCreditFlag: null,
        CsvField.inflowPayee: null,
        CsvField.account: 'Account',
        CsvField.transfer: 'Transfer',
        CsvField.cleared: 'Cleared',
      });
    });
  });

  group('inferDecimalSeparator', () {
    test(
      'reads the separator from the amounts, falling back to the locale',
      () {
        expect(inferDecimalSeparator(['-12,50', '1.234,00']), ',');
        expect(inferDecimalSeparator(['-12.50', '1,234.00']), '.');
        expect(inferDecimalSeparator(['€1.234', '€2.000']), ',');
        expect(inferDecimalSeparator(['1,234', '2,000']), '.');
        expect(inferDecimalSeparator(['12', '15'], fallback: ','), ',');
        expect(inferDecimalSeparator([], fallback: '.'), '.');
      },
    );
  });
}
