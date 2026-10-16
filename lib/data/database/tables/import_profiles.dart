import 'package:drift/drift.dart';

class ImportProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get dateFormat => text().named('date_format')();
  TextColumn get decimalSeparator => text().named('decimal_separator')();
  BoolColumn get outflowIsNegative => boolean().named('outflow_is_negative')();
  TextColumn get dateColumn => text().nullable().named('date_column')();
  TextColumn get amountColumn => text().nullable().named('amount_column')();
  TextColumn get payeeColumn => text().nullable().named('payee_column')();
  TextColumn get memoColumn => text().nullable().named('memo_column')();
  TextColumn get categoryColumn => text().nullable().named('category_column')();
  TextColumn get createdAt => text().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
