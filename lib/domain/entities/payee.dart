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

  /// The unique identifier of the default account for this payee.
  final String? defaultAccountId;

  /// The date and time when the payee was created.
  final DateTime? createdAt;

  /// The icon identifier for the payee.
  final String? icon;

  /// The color value (ARGB int) for the payee.
  final int? color;

  /// Custom notes for the payee.
  final String? notes;

  /// Whether this payee is marked as favorite/frequent.
  final bool isFavorite;

  /// Creates a new [Payee] instance.
  const Payee({
    required this.id,
    required this.name,
    this.autoCategoryId,
    this.defaultAccountId,
    this.createdAt,
    this.icon,
    this.color,
    this.notes,
    this.isFavorite = false,
  });

  /// Creates a copy of this [Payee] but with the given fields replaced with the new values.
  Payee copyWith({
    String? id,
    String? name,
    String? autoCategoryId,
    String? defaultAccountId,
    DateTime? createdAt,
    String? icon,
    int? color,
    String? notes,
    bool? isFavorite,
  }) {
    return Payee(
      id: id ?? this.id,
      name: name ?? this.name,
      autoCategoryId: autoCategoryId ?? this.autoCategoryId,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      createdAt: createdAt ?? this.createdAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Creates a [Payee] from a JSON object.
  factory Payee.fromJson(Map<String, dynamic> json) {
    return Payee(
      id: json['id'] as String,
      name: json['name'] as String,
      autoCategoryId: json['auto_category_id'] as String?,
      defaultAccountId: json['default_account_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
      notes: json['notes'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  /// Converts the [Payee] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'auto_category_id': autoCategoryId,
      'default_account_id': defaultAccountId,
      'created_at': createdAt?.toIso8601String(),
      'icon': icon,
      'color': color,
      'notes': notes,
      'is_favorite': isFavorite,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Payee &&
        other.id == id &&
        other.name == name &&
        other.autoCategoryId == autoCategoryId &&
        other.defaultAccountId == defaultAccountId &&
        other.createdAt == createdAt &&
        other.icon == icon &&
        other.color == color &&
        other.notes == notes &&
        other.isFavorite == isFavorite;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      autoCategoryId,
      defaultAccountId,
      createdAt,
      icon,
      color,
      notes,
      isFavorite,
    );
  }

  @override
  String toString() {
    return 'Payee(id: $id, name: $name, autoCategoryId: $autoCategoryId, defaultAccountId: $defaultAccountId, createdAt: $createdAt, icon: $icon, color: $color, notes: $notes, isFavorite: $isFavorite)';
  }

  /// Validates the [Payee] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Payee name cannot be empty');
    }
    return errors;
  }
}
