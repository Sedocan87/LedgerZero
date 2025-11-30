/// Represents a payee in the LedgerZero application.
///
/// A payee is the entity to whom money is paid or from whom money is received.
class Payee {
  /// The unique identifier of the payee.
  final String id;

  /// The name of the payee.
  final String name;

  /// The unique identifier of the default category for this payee.
  final String? autoCategoryId;

  /// The date and time when the payee was created.
  final DateTime? createdAt;

  /// Creates a new [Payee] instance.
  const Payee({
    required this.id,
    required this.name,
    this.autoCategoryId,
    this.createdAt,
  });

  /// Creates a copy of this [Payee] but with the given fields replaced with the new values.
  Payee copyWith({
    String? id,
    String? name,
    String? autoCategoryId,
    DateTime? createdAt,
  }) {
    return Payee(
      id: id ?? this.id,
      name: name ?? this.name,
      autoCategoryId: autoCategoryId ?? this.autoCategoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates a [Payee] from a JSON object.
  factory Payee.fromJson(Map<String, dynamic> json) {
    return Payee(
      id: json['id'] as String,
      name: json['name'] as String,
      autoCategoryId: json['auto_category_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converts the [Payee] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'auto_category_id': autoCategoryId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Payee &&
        other.id == id &&
        other.name == name &&
        other.autoCategoryId == autoCategoryId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      autoCategoryId,
      createdAt,
    );
  }
}
