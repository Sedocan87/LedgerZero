/// The fields a CSV column can be mapped to (keys of the column mapping
/// `Map<String, String?>`: field -> header name, `null` = ignored).
///
/// Saved import profiles store the five classic fields; the others are
/// mapped per import (by a bank preset or the header keywords).
class CsvField {
  CsvField._();

  static const date = 'Date';

  /// One signed amount column.
  static const amount = 'Amount';

  /// Outflows in their own column (Soll); used with [credit] when no
  /// [amount] column is mapped.
  static const debit = 'Debit';

  /// Inflows in their own column (Haben).
  static const credit = 'Credit';

  /// A column whose value marks the amount as debit (`S`, `D`, `-`) or
  /// credit (`H`, `C`, `+`); the amount's own sign is then ignored.
  static const debitCreditFlag = 'DebitCreditFlag';

  static const payee = 'Payee';

  /// The payee column for inflows when the bank writes the sender and the
  /// recipient into separate columns.
  static const inflowPayee = 'InflowPayee';
  static const memo = 'Memo';
  static const category = 'Category';

  /// The account the row belongs to (an exported file lists several).
  static const account = 'Account';

  /// For a transfer leg: the name of the other account.
  static const transfer = 'Transfer';
  static const cleared = 'Cleared';

  /// All fields in the order the mapping card shows them.
  static const all = [
    date,
    amount,
    payee,
    memo,
    category,
    debit,
    credit,
    debitCreditFlag,
    inflowPayee,
    account,
    transfer,
    cleared,
  ];

  /// The five fields shown first (and stored in import profiles).
  static const primary = [date, amount, payee, memo, category];
}
