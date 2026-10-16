import 'package:drift/drift.dart';

class ReportNotes extends Table {
  TextColumn get id => text()();

  /// The month the note belongs to, `YYYY-MM` (one note per month).
  TextColumn get date => text()();
  TextColumn get note => text()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date},
  ];
}
