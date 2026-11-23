import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/report_notes_dao.dart';
import 'package:ledger_zero/domain/entities/report_note.dart' as domain;
import 'package:ledger_zero/domain/repositories/report_note_repository.dart';

class ReportNoteRepositoryImpl implements ReportNoteRepository {
  final ReportNotesDao _dao;

  ReportNoteRepositoryImpl(this._dao);

  @override
  Future<List<domain.ReportNote>> getAllNotes() async {
    try {
      final dtos = await _dao.getAllNotes();
      return dtos.map(_mapToDomain).toList();
    } catch (e, stack) {
      Logger.error('Failed to get all report notes', e, stack);
      throw const DatabaseException('Failed to get all report notes');
    }
  }

  @override
  Future<domain.ReportNote?> getNoteByDate(String date) async {
    try {
      final dto = await _dao.getNoteByDate(date);
      return dto != null ? _mapToDomain(dto) : null;
    } catch (e, stack) {
      Logger.error('Failed to get report note by date: $date', e, stack);
      throw const DatabaseException('Failed to get report note');
    }
  }

  @override
  Future<void> saveNote(domain.ReportNote note) async {
    try {
      await _dao.transaction(() async {
        final existing = await _dao.getNoteByDate(note.date);
        final now = DateTime.now().toUtc().toIso8601String();
        if (existing != null) {
          await _dao.updateNote(
            ReportNotesCompanion(
              id: Value(existing.id),
              date: Value(note.date),
              note: Value(note.note),
              createdAt: Value(existing.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
        } else {
          await _dao.insertNote(
            ReportNotesCompanion(
              id: Value(note.id),
              date: Value(note.date),
              note: Value(note.note),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      });
    } catch (e, stack) {
      Logger.error('Failed to save report note', e, stack);
      throw const DatabaseException('Failed to save report note');
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      await _dao.deleteNote(id);
    } catch (e, stack) {
      Logger.error('Failed to delete report note: $id', e, stack);
      throw const DatabaseException('Failed to delete report note');
    }
  }

  @override
  Stream<domain.ReportNote?> watchNoteByDate(String date) {
    return _dao
        .watchNoteByDate(date)
        .map((dto) => dto != null ? _mapToDomain(dto) : null);
  }

  domain.ReportNote _mapToDomain(ReportNote dto) {
    return domain.ReportNote(
      id: dto.id,
      date: dto.date,
      note: dto.note,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
    );
  }
}
