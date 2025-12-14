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
  final String value;

  const RuleCondition({
    required this.type,
    required this.operator,
    required this.value,
  });

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      type: RuleConditionType.values.firstWhere((e) => e.name == json['type']),
      operator: RuleConditionOperator.values.firstWhere(
        (e) => e.name == json['operator'],
      ),
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'operator': operator.name, 'value': value};
  }
}
