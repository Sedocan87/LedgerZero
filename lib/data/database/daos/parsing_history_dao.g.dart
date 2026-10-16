// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parsing_history_dao.dart';

// ignore_for_file: type=lint
mixin _$ParsingHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $ParsingHistoryTable get parsingHistory => attachedDatabase.parsingHistory;
  ParsingHistoryDaoManager get managers => ParsingHistoryDaoManager(this);
}

class ParsingHistoryDaoManager {
  final _$ParsingHistoryDaoMixin _db;
  ParsingHistoryDaoManager(this._db);
  $$ParsingHistoryTableTableManager get parsingHistory =>
      $$ParsingHistoryTableTableManager(
        _db.attachedDatabase,
        _db.parsingHistory,
      );
}
