class BudgetTemplate {
  final String id;
  final String name;
  final Map<String, double> data;
  final DateTime? createdAt;

  const BudgetTemplate({
    required this.id,
    required this.name,
    required this.data,
    this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BudgetTemplate &&
        other.id == id &&
        other.name == name &&
        _mapEquals(other.data, data) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, data, createdAt);
  }

  bool _mapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
