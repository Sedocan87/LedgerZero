// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules_dao.dart';

// ignore_for_file: type=lint
mixin _$RulesDaoMixin on DatabaseAccessor<AppDatabase> {
  $RulesTable get rules => attachedDatabase.rules;
  RulesDaoManager get managers => RulesDaoManager(this);
}

class RulesDaoManager {
  final _$RulesDaoMixin _db;
  RulesDaoManager(this._db);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db.attachedDatabase, _db.rules);
}
