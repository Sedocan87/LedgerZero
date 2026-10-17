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

  /// Brokerage, crypto or retirement account. New ones start outside the
  /// budget (tracked for net worth only). Added last: drafts store the
  /// index.
  investment;

  /// Accounts whose money is usually saved rather than spent: they start
  /// outside the budget when created.
  bool get startsOffBudget =>
      this == AccountType.savings || this == AccountType.investment;
}

/// Who an account belongs to in a household that syncs.
enum AccountOwner {
  /// Shared: everything syncs to the partner's phone.
  shared,

  /// Personal to this phone's user: off-budget, and only its name and
  /// balance sync (its transactions stay on this phone).
  me,

  /// The partner's personal account: read-only here, with the balance their
  /// phone shared and no transactions.
  partner,
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

  /// The opening balance of the account in minor units (hundredths).
  final int startingBalance;

  /// The current balance in minor units.
  ///
  /// Computed by the repository as starting balance + SUM(amount) of the
  /// account's non-deleted transactions that are not split children. It is
  /// never persisted; values set here are ignored when saving.
  final int balance;

  /// Whether the account is closed.
  final bool isClosed;

  /// Whether the account belongs to the budget. An off-budget (tracking)
  /// account counts towards net worth only; see docs/BUDGETING_RULES.md.
  final bool onBudget;

  /// Who the account belongs to; see [AccountOwner]. A personal account is
  /// always off-budget.
  final AccountOwner owner;

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
    this.startingBalance = 0,
    this.balance = 0,
    this.isClosed = false,
    this.onBudget = true,
    this.owner = AccountOwner.shared,
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
    int? startingBalance,
    int? balance,
    bool? isClosed,
    bool? onBudget,
    AccountOwner? owner,
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
      balance: balance ?? this.balance,
      isClosed: isClosed ?? this.isClosed,
      onBudget: onBudget ?? this.onBudget,
      owner: owner ?? this.owner,
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
      // Unknown (newer) types read as checking, like the repository does.
      type: AccountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AccountType.checking,
      ),
      currency: json['currency'] as String? ?? 'USD',
      startingBalance: (json['starting_balance'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      isClosed: json['is_closed'] as bool? ?? false,
      onBudget: json['on_budget'] as bool? ?? true,
      owner: AccountOwner.values.firstWhere(
        (e) => e.name == json['owner'],
        orElse: () => AccountOwner.shared,
      ),
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
      'balance': balance,
      'is_closed': isClosed,
      'on_budget': onBudget,
      'owner': owner.name,
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
        other.balance == balance &&
        other.isClosed == isClosed &&
        other.onBudget == onBudget &&
        other.owner == owner &&
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
      balance,
      isClosed,
      onBudget,
      owner,
      color,
      icon,
      notes,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: $type, currency: $currency, startingBalance: $startingBalance, balance: $balance, isClosed: $isClosed, onBudget: $onBudget, owner: $owner, color: $color, icon: $icon, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Personal to one member of the household (this phone's user or the
  /// partner).
  bool get isPersonal => owner != AccountOwner.shared;

  /// The partner's personal account: shown with its balance, never written
  /// here.
  bool get isPartners => owner == AccountOwner.partner;

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
