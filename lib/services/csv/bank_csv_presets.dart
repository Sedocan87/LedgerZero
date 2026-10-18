import 'package:ledger_zero/services/csv/csv_fields.dart';

/// Import settings for one bank's CSV export, recognised by its header.
///
/// A preset is pure data: which header names carry which field, the date
/// format, the decimal separator and how outflows are marked. The header
/// line itself is found automatically (banks put account details above
/// it), the delimiter is read from the header line and the encoding is
/// detected while reading (UTF-8, else Windows-1252), so [delimiter],
/// [encoding] and [hasPreamble] document the export and are checked by the
/// fixtures, nothing more.
///
/// To add a bank: append a [BankCsvPreset] to [bankCsvPresets] with the
/// header names exactly as the bank writes them (matching ignores case and
/// surrounding spaces) and a small fixture under `test/fixtures/bank_csv/`.
class BankCsvPreset {
  const BankCsvPreset({
    required this.id,
    required this.name,
    required this.requiredHeaders,
    required this.dateFormat,
    required this.decimalSeparator,
    required this.delimiter,
    required this.encoding,
    required this.dateColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.debitCreditFlagColumn,
    this.payeeColumn,
    this.inflowPayeeColumn,
    this.payeePattern,
    this.memoColumn,
    this.clearedColumn,
    this.outflowIsNegative = true,
    this.hasPreamble = false,
  });

  /// Stable identifier (stored nowhere yet; used by the UI selection).
  final String id;

  /// The bank and export variant, as shown to the user (a product name,
  /// the same in every language).
  final String name;

  /// Header names that must all be present for the preset to match.
  final List<String> requiredHeaders;

  final String dateFormat;
  final String decimalSeparator;
  final String delimiter;

  /// `utf-8` or `windows-1252`; informational (decoding is automatic).
  final String encoding;

  final String dateColumn;

  /// One signed amount column, or [debitColumn] + [creditColumn].
  final String? amountColumn;
  final String? debitColumn;
  final String? creditColumn;

  /// A column whose value says whether the amount is a debit (`S`/`D`) or
  /// a credit (`H`/`C`); see `CsvImportService`.
  final String? debitCreditFlagColumn;

  final String? payeeColumn;

  /// Column holding the payee of inflows when the bank splits sender and
  /// recipient into two columns (DKB).
  final String? inflowPayeeColumn;

  /// When the payee cell packs several things together (comdirect writes
  /// `Auftraggeber: X Buchungstext: Y`), group 1 of this regular expression
  /// is the payee; the whole cell is kept when it does not match.
  final String? payeePattern;

  RegExp? get payeeRegExp =>
      payeePattern == null ? null : RegExp(payeePattern!, caseSensitive: false);

  final String? memoColumn;
  final String? clearedColumn;

  /// Whether negative amounts are outflows (false for files listing
  /// charges as positive numbers).
  final bool outflowIsNegative;

  /// The export has lines above the header (account details, balances).
  final bool hasPreamble;

  /// Whether [headers] (as the file writes them) carry every required
  /// header.
  bool matches(List<String> headers) {
    final normalised = {for (final h in headers) normalizeHeader(h)};
    return requiredHeaders.every(
      (h) => normalised.contains(normalizeHeader(h)),
    );
  }

  /// The column mapping (field -> header as written in [headers]) for a
  /// file with these headers. Columns the file lacks stay unmapped.
  Map<String, String?> mappingFor(List<String> headers) {
    String? find(String? wanted) {
      if (wanted == null) {
        return null;
      }
      final key = normalizeHeader(wanted);
      for (final h in headers) {
        if (normalizeHeader(h) == key) {
          return h;
        }
      }
      return null;
    }

    return {
      CsvField.date: find(dateColumn),
      CsvField.amount: find(amountColumn),
      CsvField.debit: find(debitColumn),
      CsvField.credit: find(creditColumn),
      CsvField.debitCreditFlag: find(debitCreditFlagColumn),
      CsvField.payee: find(payeeColumn),
      CsvField.inflowPayee: find(inflowPayeeColumn),
      CsvField.memo: find(memoColumn),
      CsvField.category: null,
      CsvField.account: null,
      CsvField.transfer: null,
      CsvField.cleared: find(clearedColumn),
    };
  }

  /// The first preset of [bankCsvPresets] whose required headers are all
  /// in [headers], or `null`.
  static BankCsvPreset? detect(List<String> headers) {
    for (final preset in bankCsvPresets) {
      if (preset.matches(headers)) {
        return preset;
      }
    }
    return null;
  }

  static BankCsvPreset? byId(String? id) {
    for (final preset in bankCsvPresets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }
}

/// Lower-cased, trimmed, inner whitespace collapsed.
String normalizeHeader(String header) =>
    header.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The built-in presets, most specific first (a file is matched against
/// them in this order).
const List<BankCsvPreset> bankCsvPresets = [
  BankCsvPreset(
    id: 'sparkasse_camt',
    name: 'Sparkasse (CSV-CAMT)',
    requiredHeaders: [
      'Buchungstag',
      'Betrag',
      'Lastschrift Ursprungsbetrag',
      'Beguenstigter/Zahlungspflichtiger',
    ],
    dateFormat: 'dd.MM.yy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Betrag',
    payeeColumn: 'Beguenstigter/Zahlungspflichtiger',
    memoColumn: 'Verwendungszweck',
  ),
  BankCsvPreset(
    id: 'sparkasse_mt940',
    name: 'Sparkasse (CSV-MT940)',
    requiredHeaders: [
      'Buchungstag',
      'Betrag',
      'Kontonummer',
      'BLZ',
      'Beguenstigter/Zahlungspflichtiger',
    ],
    dateFormat: 'dd.MM.yy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Betrag',
    payeeColumn: 'Beguenstigter/Zahlungspflichtiger',
    memoColumn: 'Verwendungszweck',
  ),
  BankCsvPreset(
    id: 'dkb',
    name: 'DKB',
    requiredHeaders: ['Buchungsdatum', 'Betrag (€)', 'Zahlungsempfänger*in'],
    dateFormat: 'dd.MM.yy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'utf-8',
    dateColumn: 'Buchungsdatum',
    amountColumn: 'Betrag (€)',
    payeeColumn: 'Zahlungsempfänger*in',
    inflowPayeeColumn: 'Zahlungspflichtige*r',
    memoColumn: 'Verwendungszweck',
    clearedColumn: 'Status',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'dkb_legacy',
    name: 'DKB (before 2023)',
    requiredHeaders: [
      'Buchungstag',
      'Betrag (EUR)',
      'Auftraggeber / Begünstigter',
    ],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Betrag (EUR)',
    payeeColumn: 'Auftraggeber / Begünstigter',
    memoColumn: 'Verwendungszweck',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'ing',
    name: 'ING',
    requiredHeaders: ['Buchung', 'Valuta', 'Auftraggeber/Empfänger', 'Betrag'],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchung',
    amountColumn: 'Betrag',
    payeeColumn: 'Auftraggeber/Empfänger',
    memoColumn: 'Verwendungszweck',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'comdirect',
    name: 'comdirect',
    requiredHeaders: ['Buchungstag', 'Wertstellung (Valuta)', 'Umsatz in EUR'],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Umsatz in EUR',
    payeeColumn: 'Buchungstext',
    payeePattern: r'(?:Auftraggeber|Empfänger):\s*(.*?)\s*(?:Buchungstext:|$)',
    memoColumn: 'Vorgang',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'n26',
    name: 'N26',
    requiredHeaders: ['Date', 'Payee', 'Amount (EUR)'],
    dateFormat: 'yyyy-MM-dd',
    decimalSeparator: '.',
    delimiter: ',',
    encoding: 'utf-8',
    dateColumn: 'Date',
    amountColumn: 'Amount (EUR)',
    payeeColumn: 'Payee',
    memoColumn: 'Payment reference',
  ),
  BankCsvPreset(
    id: 'n26_2024',
    name: 'N26 (2024 format)',
    requiredHeaders: ['Booking Date', 'Partner Name', 'Amount (EUR)'],
    dateFormat: 'yyyy-MM-dd',
    decimalSeparator: '.',
    delimiter: ',',
    encoding: 'utf-8',
    dateColumn: 'Booking Date',
    amountColumn: 'Amount (EUR)',
    payeeColumn: 'Partner Name',
    memoColumn: 'Payment Reference',
  ),
  BankCsvPreset(
    id: 'volksbank_vr',
    name: 'Volksbank / Raiffeisenbank',
    requiredHeaders: [
      'Buchungstag',
      'Name Zahlungsbeteiligter',
      'Betrag',
      'Verwendungszweck',
    ],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Betrag',
    payeeColumn: 'Name Zahlungsbeteiligter',
    memoColumn: 'Verwendungszweck',
  ),
  BankCsvPreset(
    id: 'volksbank_vr_legacy',
    name: 'Volksbank / Raiffeisenbank (Umsatz + Soll/Haben)',
    requiredHeaders: ['Buchungstag', 'Umsatz', 'Soll/Haben'],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    amountColumn: 'Umsatz',
    debitCreditFlagColumn: 'Soll/Haben',
    payeeColumn: 'Empfänger/Zahlungspflichtiger',
    memoColumn: 'Vorgang/Verwendungszweck',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'deutsche_bank',
    name: 'Deutsche Bank',
    requiredHeaders: ['Buchungstag', 'Umsatzart', 'Soll', 'Haben'],
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
    delimiter: ';',
    encoding: 'windows-1252',
    dateColumn: 'Buchungstag',
    debitColumn: 'Soll',
    creditColumn: 'Haben',
    payeeColumn: 'Begünstigter / Auftraggeber',
    memoColumn: 'Verwendungszweck',
    hasPreamble: true,
  ),
  BankCsvPreset(
    id: 'revolut',
    name: 'Revolut',
    requiredHeaders: [
      'Type',
      'Product',
      'Started Date',
      'Description',
      'Amount',
    ],
    dateFormat: 'yyyy-MM-dd HH:mm:ss',
    decimalSeparator: '.',
    delimiter: ',',
    encoding: 'utf-8',
    dateColumn: 'Started Date',
    amountColumn: 'Amount',
    payeeColumn: 'Description',
    clearedColumn: 'State',
  ),
];
