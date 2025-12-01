/// The type of an account.
enum AccountType {
  /// Checking account.
  checking,

  /// Savings account.
  savings,

  /// Credit card account.
  credit,

  /// Cash account.
  cash,
}

/// Represents a financial account in the LedgerZero application.
///
/// An account holds transactions and has a balance.
class Account {
  /// The unique identifier of the account.
  final String id;

  /// The name of the account.
  final String name;

  /// The type of the account.
  final AccountType type;

  /// The currency code of the account (e.g., 'USD').
  final String currency;

  /// The starting balance of the account.
  final double startingBalance;

  /// The current balance of the account.
  final double currentBalance;

  /// Whether the account is closed.
  final bool isClosed;

  /// The color of the account.
  final int? color;

  /// The icon of the account.
  final String? icon;

  /// Notes for the account.
  final String? notes;

  /// The date and time when the account was created.
  final DateTime? createdAt;

  /// The date and time when the account was last updated.
  final DateTime? updatedAt;

  /// Creates a new [Account] instance.
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'USD',
    this.startingBalance = 0.0,
    this.currentBalance = 0.0,
    this.isClosed = false,
    this.color,
    this.icon,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a copy of this [Account] but with the given fields replaced with the new values.
  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? currency,
    double? startingBalance,
    double? currentBalance,
    bool? isClosed,
    int? color,
    String? icon,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      startingBalance: startingBalance ?? this.startingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      isClosed: isClosed ?? this.isClosed,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates an [Account] from a JSON object.
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountType.values.firstWhere((e) => e.name == json['type']),
      currency: json['currency'] as String? ?? 'USD',
      startingBalance: (json['starting_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      isClosed: json['is_closed'] as bool? ?? false,
      color: json['color'] as int?,
      icon: json['icon'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts the [Account] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'currency': currency,
      'starting_balance': startingBalance,
      'current_balance': currentBalance,
      'is_closed': isClosed,
      'color': color,
      'icon': icon,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Account &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.currency == currency &&
        other.startingBalance == startingBalance &&
        other.currentBalance == currentBalance &&
        other.isClosed == isClosed &&
        other.color == color &&
        other.icon == icon &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      type,
      currency,
      startingBalance,
      currentBalance,
      isClosed,
      color,
      icon,
      notes,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: $type, currency: $currency, startingBalance: $startingBalance, currentBalance: $currentBalance, isClosed: $isClosed, color: $color, icon: $icon, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Validates the [Account] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Account name cannot be empty');
    }
    if (currency.length != 3) {
      errors.add('Currency code must be 3 characters');
    }
    return errors;
  }
}
