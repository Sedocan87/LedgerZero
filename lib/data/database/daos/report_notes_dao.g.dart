// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_notes_dao.dart';

// ignore_for_file: type=lint
mixin _$ReportNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReportNotesTable get reportNotes => attachedDatabase.reportNotes;
  ReportNotesDaoManager get managers => ReportNotesDaoManager(this);
}

class ReportNotesDaoManager {
  final _$ReportNotesDaoMixin _db;
  ReportNotesDaoManager(this._db);
  $$ReportNotesTableTableManager get reportNotes =>
      $$ReportNotesTableTableManager(_db.attachedDatabase, _db.reportNotes);
}
