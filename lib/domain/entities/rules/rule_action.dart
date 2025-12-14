enum RuleActionType {
  setCategory,
  setPayee,
  setAccount,
  setMemo,
  markCleared,
  markApproved,
}

class RuleAction {
  final RuleActionType type;
  final String value;

  const RuleAction({required this.type, required this.value});

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      type: RuleActionType.values.firstWhere((e) => e.name == json['type']),
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'value': value};
  }
}
