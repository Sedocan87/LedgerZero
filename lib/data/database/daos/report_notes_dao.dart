import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/report_notes.dart';

part 'report_notes_dao.g.dart';

@DriftAccessor(tables: [ReportNotes])
class ReportNotesDao extends DatabaseAccessor<AppDatabase>
    with _$ReportNotesDaoMixin {
  ReportNotesDao(super.db);

  Future<List<ReportNote>> getAllNotes() => select(reportNotes).get();

  Future<ReportNote?> getNoteByDate(String date) {
    return (select(
      reportNotes,
    )..where((tbl) => tbl.date.equals(date))).getSingleOrNull();
  }

  Future<void> insertNote(ReportNotesCompanion note) =>
      into(reportNotes).insert(note);

  Future<bool> updateNote(ReportNotesCompanion note) =>
      update(reportNotes).replace(note);

  Future<int> deleteNote(String id) =>
      (delete(reportNotes)..where((tbl) => tbl.id.equals(id))).go();

  Stream<ReportNote?> watchNoteByDate(String date) {
    return (select(
      reportNotes,
    )..where((tbl) => tbl.date.equals(date))).watchSingleOrNull();
  }
}
