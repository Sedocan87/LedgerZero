import 'package:drift/drift.dart';

class ReportNotes extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM or YYYY-MM-DD depending on granularity. Let's stick to YYYY-MM for monthly reports.
  TextColumn get note => text()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date}, // One note per month for simplicity for now? Or allow multiple? Task says "annotations/notes". A single note block per month seems appropriate for a "Report Note".
  ];
}

@TableIndex(name: 'idx_report_notes_date', columns: {#date})
abstract class ReportNotesIndex {}
