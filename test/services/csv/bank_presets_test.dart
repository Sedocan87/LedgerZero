// Every bank preset imports its fixture under test/fixtures/bank_csv/
// end to end: the file is read like a picked file (encoding detected),
// the header line found below any preamble, the preset recognised from the
// headers, and the rows converted with the preset's mapping and formats.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/csv/bank_csv_presets.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

import '../../helpers/memory_platform_file.dart';

/// What the import of one fixture must produce (rows newest first).
class _Expectation {
  const _Expectation({
    required this.presetId,
    required this.headerLineIndex,
    required this.delimiter,
    required this.amounts,
    required this.dates,
    required this.payees,
    this.memos,
    this.cleared,
    this.skippedRows = 0,
  });

  final String presetId;
  final int headerLineIndex;
  final String delimiter;
  final List<int> amounts;
  final List<DateTime> dates;
  final List<String?> payees;
  final List<String?>? memos;
  final List<TransactionClearStatus?>? cleared;

  /// Footer rows (balances) that validation reports as skipped.
  final int skippedRows;
}

final _expectations = <String, _Expectation>{
  'sparkasse_camt.csv': _Expectation(
    presetId: 'sparkasse_camt',
    headerLineIndex: 0,
    delimiter: ';',
    amounts: [-85000, -2345, 275000, -12000],
    dates: [
      DateTime.utc(2026, 10, 18),
      DateTime.utc(2026, 10, 16),
      DateTime.utc(2026, 10, 15),
      DateTime.utc(2026, 10, 2),
    ],
    payees: [
      'Hausverwaltung Müller GmbH',
      'REWE SAGT DANKE 1234',
      'Beispiel AG',
      'Max Mustermann',
    ],
    memos: [
      'Miete Oktober',
      '2026-10-15T18:22 Debitk.1 2027-12',
      'Gehalt 10/2026',
      'Rechnung 4711',
    ],
  ),
  'sparkasse_mt940.csv': _Expectation(
    presetId: 'sparkasse_mt940',
    headerLineIndex: 0,
    delimiter: ';',
    amounts: [-6530, 4200, -1890],
    dates: [
      DateTime.utc(2026, 3, 9),
      DateTime.utc(2026, 3, 5),
      DateTime.utc(2026, 3, 1),
    ],
    payees: ['Stadtwerke', 'Versicherung AG', 'EDEKA Markt'],
    memos: ['Strom März', 'Rückerstattung', 'EDEKA'],
  ),
  'dkb.csv': _Expectation(
    presetId: 'dkb',
    headerLineIndex: 4,
    delimiter: ';',
    amounts: [-1299, -450, 250000],
    dates: [
      DateTime.utc(2026, 10, 18),
      DateTime.utc(2026, 10, 17),
      DateTime.utc(2026, 10, 15),
    ],
    // The inflow's payee is the sender column.
    payees: ['Netflix', 'Bäckerei Schmidt', 'Beispiel AG'],
    cleared: [
      TransactionClearStatus.cleared,
      TransactionClearStatus.uncleared,
      TransactionClearStatus.cleared,
    ],
  ),
  'dkb_legacy.csv': _Expectation(
    presetId: 'dkb_legacy',
    headerLineIndex: 6,
    delimiter: ';',
    amounts: [-3999, 230000, -1725],
    dates: [
      DateTime.utc(2026, 10, 17),
      DateTime.utc(2026, 10, 12),
      DateTime.utc(2026, 10, 4),
    ],
    payees: ['Amazon Payments Europe', 'Beispiel AG', 'DM Drogerie'],
  ),
  'ing.csv': _Expectation(
    presetId: 'ing',
    headerLineIndex: 11,
    delimiter: ';',
    amounts: [-4990, 310000, -780],
    dates: [
      DateTime.utc(2026, 10, 17),
      DateTime.utc(2026, 10, 10),
      DateTime.utc(2026, 10, 3),
    ],
    payees: ['Deutsche Bahn', 'Arbeitgeber GmbH', 'Café Zentral'],
    memos: ['Fahrkarte', 'Gehalt 10/2026', 'Kartenzahlung'],
  ),
  'comdirect.csv': _Expectation(
    presetId: 'comdirect',
    headerLineIndex: 4,
    delimiter: ';',
    amounts: [-8000, -15000, 31240],
    dates: [
      DateTime.utc(2026, 10, 16),
      DateTime.utc(2026, 10, 12),
      DateTime.utc(2026, 10, 5),
    ],
    // The payee is pulled out of "Auftraggeber: X Buchungstext: Y".
    payees: ['Stadtwerke Köln', 'Max Mustermann', 'Finanzamt Köln'],
    memos: ['Lastschrift / Belastung', 'Übertrag / Überweisung', 'Gutschrift'],
    skippedRows: 1, // "Alter Kontostand" footer
  ),
  'n26.csv': _Expectation(
    presetId: 'n26',
    headerLineIndex: 0,
    delimiter: ',',
    amounts: [-3412, 220000, -999],
    dates: [
      DateTime.utc(2026, 10, 17),
      DateTime.utc(2026, 10, 15),
      DateTime.utc(2026, 10, 14),
    ],
    payees: ['Lidl', 'Erika Musterfrau', 'Spotify'],
    memos: [null, 'Gehalt', 'Premium'],
  ),
  'n26_2024.csv': _Expectation(
    presetId: 'n26_2024',
    headerLineIndex: 0,
    delimiter: ',',
    amounts: [-5900, 260000, -2999],
    dates: [
      DateTime.utc(2026, 10, 16),
      DateTime.utc(2026, 10, 10),
      DateTime.utc(2026, 10, 2),
    ],
    payees: ['Amazon', 'Beispiel AG', 'Vodafone'],
  ),
  'volksbank_vr.csv': _Expectation(
    presetId: 'volksbank_vr',
    headerLineIndex: 0,
    delimiter: ';',
    amounts: [-4567, 290000, -3995],
    dates: [
      DateTime.utc(2026, 10, 18),
      DateTime.utc(2026, 10, 15),
      DateTime.utc(2026, 10, 11),
    ],
    payees: ['ALDI SUED', 'Beispiel AG', 'Telekom Deutschland GmbH'],
  ),
  'volksbank_vr_legacy.csv': _Expectation(
    presetId: 'volksbank_vr_legacy',
    headerLineIndex: 4,
    delimiter: ';',
    // Unsigned "Umsatz" with the Soll/Haben flag deciding the sign.
    amounts: [-9500, 240000, -2990],
    dates: [
      DateTime.utc(2026, 10, 14),
      DateTime.utc(2026, 10, 8),
      DateTime.utc(2026, 10, 1),
    ],
    payees: ['Stadtwerke', 'Beispiel AG', 'Fitnessstudio'],
    skippedRows: 2, // Anfangssaldo / Endsaldo footer
  ),
  'deutsche_bank.csv': _Expectation(
    presetId: 'deutsche_bank',
    headerLineIndex: 3,
    delimiter: ';',
    // Separate Soll (already negative) and Haben columns.
    amounts: [-4000, 300000, -5510],
    dates: [
      DateTime.utc(2026, 10, 16),
      DateTime.utc(2026, 10, 14),
      DateTime.utc(2026, 10, 5),
    ],
    payees: ['Stadtwerke Berlin', 'Beispiel AG', 'REWE'],
    skippedRows: 1, // "Kontostand" footer
  ),
  'revolut.csv': _Expectation(
    presetId: 'revolut',
    headerLineIndex: 0,
    delimiter: ',',
    amounts: [-1550, -480, -10000, 20000],
    dates: [
      DateTime.utc(2026, 10, 18),
      DateTime.utc(2026, 10, 17),
      DateTime.utc(2026, 10, 15),
      DateTime.utc(2026, 10, 14),
    ],
    payees: ['Uber', 'Starbucks', 'To Erika Musterfrau', 'Top-Up by *1234'],
    cleared: [
      TransactionClearStatus.uncleared,
      TransactionClearStatus.cleared,
      TransactionClearStatus.cleared,
      TransactionClearStatus.cleared,
    ],
  ),
};

void main() {
  final service = CsvImportService();

  test('every preset has a fixture and every fixture an expectation', () {
    final fixtures = Directory(
      'test/fixtures/bank_csv',
    ).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(fixtures, _expectations.keys.toSet());
    expect(
      _expectations.values.map((e) => e.presetId).toSet(),
      bankCsvPresets.map((p) => p.id).toSet(),
    );
  });

  for (final entry in _expectations.entries) {
    final name = entry.key;
    final want = entry.value;
    test('$name imports with the ${want.presetId} preset', () async {
      final bytes = File('test/fixtures/bank_csv/$name').readAsBytesSync();
      final data = await service.parseCsvFile(
        MemoryPlatformFile(name: name, bytes: bytes),
      );
      final preset = data.preset;
      expect(preset?.id, want.presetId);
      expect(data.headerLineIndex, want.headerLineIndex);
      expect(data.delimiter, want.delimiter);
      expect(data.delimiter, preset!.delimiter, reason: 'preset documents it');

      final mapping = CsvImportService.autoMapColumns(
        data.headers,
        preset: preset,
      );
      final validation = service.validateCsvData(
        data: data,
        columnMapping: mapping,
        dateFormat: preset.dateFormat,
        decimalSeparator: preset.decimalSeparator,
      );
      expect(validation.isValid, isTrue, reason: '${validation.errors}');
      expect(validation.skippedRows, want.skippedRows);

      final rows = service.convertCsvToTransactions(
        data: data,
        columnMapping: mapping,
        dateFormat: preset.dateFormat,
        decimalSeparator: preset.decimalSeparator,
        outflowIsNegative: preset.outflowIsNegative,
      );
      expect(rows.map((r) => r.amount), want.amounts);
      expect(rows.map((r) => r.date), want.dates);
      expect(rows.map((r) => r.payeeName), want.payees);
      if (want.memos != null) {
        expect(rows.map((r) => r.memo), want.memos);
      }
      if (want.cleared != null) {
        expect(rows.map((r) => r.cleared), want.cleared);
      }
    });
  }

  test('the header fingerprint picks the preset, not the file name', () {
    expect(
      BankCsvPreset.detect([
        'Buchungstag',
        'Betrag',
        'Lastschrift Ursprungsbetrag',
        'Beguenstigter/Zahlungspflichtiger',
      ])?.id,
      'sparkasse_camt',
    );
    expect(
      BankCsvPreset.detect([
        ' buchungsdatum ',
        'BETRAG (€)',
        'Zahlungsempfänger*in',
      ])?.id,
      'dkb',
    );
    expect(BankCsvPreset.detect(['Date', 'Amount', 'Payee']), isNull);
  });
}
