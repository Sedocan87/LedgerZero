import 'package:ledger_zero/domain/entities/report_note.dart';

abstract class ReportNoteRepository {
  Future<List<ReportNote>> getAllNotes();
  Future<ReportNote?> getNoteByDate(String date);
  Future<void> saveNote(ReportNote note);
  Future<void> deleteNote(String id);
  Stream<ReportNote?> watchNoteByDate(String date);
}
