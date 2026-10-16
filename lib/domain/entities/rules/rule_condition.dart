import 'package:ledger_zero/core/money/money.dart';

enum RuleConditionType {
  payee,
  amount,
  description,
  // Add more as needed
}

enum RuleConditionOperator {
  equals,
  contains,
  startsWith,
  endsWith,
  greaterThan,
  lessThan,
  regex,
}

class RuleCondition {
  final RuleConditionType type;
  final RuleConditionOperator operator;

  /// The value to compare against.
  ///
  /// For [RuleConditionType.amount] this is an integer in minor units
  /// (e.g. `"500"` for 5.00); see [amountMinor].
  final String value;

  const RuleCondition({
    required this.type,
    required this.operator,
    required this.value,
  });

  /// Creates an amount condition from minor units.
  factory RuleCondition.amount({
    required RuleConditionOperator operator,
    required int minor,
  }) {
    return RuleCondition(
      type: RuleConditionType.amount,
      operator: operator,
      value: minor.toString(),
    );
  }

  /// The amount threshold in minor units, for amount conditions.
  int? get amountMinor =>
      type == RuleConditionType.amount ? int.tryParse(value.trim()) : null;

  /// JSON key marking amount values as minor units. JSON without it (rules
  /// stored before schema v15 or exported by older versions) holds a
  /// major-unit decimal such as `"5.00"`.
  static const String amountUnitKey = 'amountUnit';
  static const String amountUnitMinor = 'minor';

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    final type = RuleConditionType.values.firstWhere(
      (e) => e.name == json['type'],
    );
    var value = json['value'].toString();
    if (type == RuleConditionType.amount &&
        json[amountUnitKey] != amountUnitMinor) {
      final legacy = Money.fromDecimalString(value);
      if (legacy != null) {
        value = legacy.toString();
      }
    }
    return RuleCondition(
      type: type,
      operator: RuleConditionOperator.values.firstWhere(
        (e) => e.name == json['operator'],
      ),
      value: value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'operator': operator.name,
      'value': value,
      if (type == RuleConditionType.amount) amountUnitKey: amountUnitMinor,
    };
  }
}
