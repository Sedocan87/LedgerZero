import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';

class Rules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get matchLogic => textEnum<RuleMatchLogic>()();
  TextColumn get conditions => text().map(const RuleConditionListConverter())();
  TextColumn get actions => text().map(const RuleActionListConverter())();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class RuleConditionListConverter
    extends TypeConverter<List<RuleCondition>, String> {
  const RuleConditionListConverter();

  @override
  List<RuleCondition> fromSql(String fromDb) {
    final List<dynamic> jsonList = json.decode(fromDb);
    return jsonList.map((e) => RuleCondition.fromJson(e)).toList();
  }

  @override
  String toSql(List<RuleCondition> value) {
    return json.encode(value.map((e) => e.toJson()).toList());
  }
}

class RuleActionListConverter extends TypeConverter<List<RuleAction>, String> {
  const RuleActionListConverter();

  @override
  List<RuleAction> fromSql(String fromDb) {
    final List<dynamic> jsonList = json.decode(fromDb);
    return jsonList.map((e) => RuleAction.fromJson(e)).toList();
  }

  @override
  String toSql(List<RuleAction> value) {
    return json.encode(value.map((e) => e.toJson()).toList());
  }
}
