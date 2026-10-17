// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _startingBalanceMeta = const VerificationMeta(
    'startingBalance',
  );
  @override
  late final GeneratedColumn<int> startingBalance = GeneratedColumn<int>(
    'starting_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isClosedMeta = const VerificationMeta(
    'isClosed',
  );
  @override
  late final GeneratedColumn<bool> isClosed = GeneratedColumn<bool>(
    'is_closed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_closed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onBudgetMeta = const VerificationMeta(
    'onBudget',
  );
  @override
  late final GeneratedColumn<bool> onBudget = GeneratedColumn<bool>(
    'on_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("on_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    currency,
    startingBalance,
    isClosed,
    onBudget,
    color,
    icon,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('starting_balance')) {
      context.handle(
        _startingBalanceMeta,
        startingBalance.isAcceptableOrUnknown(
          data['starting_balance']!,
          _startingBalanceMeta,
        ),
      );
    }
    if (data.containsKey('is_closed')) {
      context.handle(
        _isClosedMeta,
        isClosed.isAcceptableOrUnknown(data['is_closed']!, _isClosedMeta),
      );
    }
    if (data.containsKey('on_budget')) {
      context.handle(
        _onBudgetMeta,
        onBudget.isAcceptableOrUnknown(data['on_budget']!, _onBudgetMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      startingBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_balance'],
      )!,
      isClosed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_closed'],
      )!,
      onBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}on_budget'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String name;
  final String type;
  final String currency;

  /// Opening balance in minor units (hundredths). The current balance is
  /// never stored: it is computed as starting balance + SUM(amount) of the
  /// account's non-deleted transactions that are not split children.
  final int startingBalance;
  final bool isClosed;

  /// Whether the account belongs to the budget (schema v19). An off-budget
  /// (tracking) account counts towards net worth only: its starting
  /// balance and transactions never reach To Be Budgeted or categories.
  final bool onBudget;
  final int? color;
  final String? icon;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.startingBalance,
    required this.isClosed,
    required this.onBudget,
    this.color,
    this.icon,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency'] = Variable<String>(currency);
    map['starting_balance'] = Variable<int>(startingBalance);
    map['is_closed'] = Variable<bool>(isClosed);
    map['on_budget'] = Variable<bool>(onBudget);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      startingBalance: Value(startingBalance),
      isClosed: Value(isClosed),
      onBudget: Value(onBudget),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currency: serializer.fromJson<String>(json['currency']),
      startingBalance: serializer.fromJson<int>(json['startingBalance']),
      isClosed: serializer.fromJson<bool>(json['isClosed']),
      onBudget: serializer.fromJson<bool>(json['onBudget']),
      color: serializer.fromJson<int?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currency': serializer.toJson<String>(currency),
      'startingBalance': serializer.toJson<int>(startingBalance),
      'isClosed': serializer.toJson<bool>(isClosed),
      'onBudget': serializer.toJson<bool>(onBudget),
      'color': serializer.toJson<int?>(color),
      'icon': serializer.toJson<String?>(icon),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    String? currency,
    int? startingBalance,
    bool? isClosed,
    bool? onBudget,
    Value<int?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    startingBalance: startingBalance ?? this.startingBalance,
    isClosed: isClosed ?? this.isClosed,
    onBudget: onBudget ?? this.onBudget,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      startingBalance: data.startingBalance.present
          ? data.startingBalance.value
          : this.startingBalance,
      isClosed: data.isClosed.present ? data.isClosed.value : this.isClosed,
      onBudget: data.onBudget.present ? data.onBudget.value : this.onBudget,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('startingBalance: $startingBalance, ')
          ..write('isClosed: $isClosed, ')
          ..write('onBudget: $onBudget, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    currency,
    startingBalance,
    isClosed,
    onBudget,
    color,
    icon,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.startingBalance == this.startingBalance &&
          other.isClosed == this.isClosed &&
          other.onBudget == this.onBudget &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currency;
  final Value<int> startingBalance;
  final Value<bool> isClosed;
  final Value<bool> onBudget;
  final Value<int?> color;
  final Value<String?> icon;
  final Value<String?> notes;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.startingBalance = const Value.absent(),
    this.isClosed = const Value.absent(),
    this.onBudget = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.currency = const Value.absent(),
    this.startingBalance = const Value.absent(),
    this.isClosed = const Value.absent(),
    this.onBudget = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<int>? startingBalance,
    Expression<bool>? isClosed,
    Expression<bool>? onBudget,
    Expression<int>? color,
    Expression<String>? icon,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (startingBalance != null) 'starting_balance': startingBalance,
      if (isClosed != null) 'is_closed': isClosed,
      if (onBudget != null) 'on_budget': onBudget,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? currency,
    Value<int>? startingBalance,
    Value<bool>? isClosed,
    Value<bool>? onBudget,
    Value<int?>? color,
    Value<String?>? icon,
    Value<String?>? notes,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      startingBalance: startingBalance ?? this.startingBalance,
      isClosed: isClosed ?? this.isClosed,
      onBudget: onBudget ?? this.onBudget,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (startingBalance.present) {
      map['starting_balance'] = Variable<int>(startingBalance.value);
    }
    if (isClosed.present) {
      map['is_closed'] = Variable<bool>(isClosed.value);
    }
    if (onBudget.present) {
      map['on_budget'] = Variable<bool>(onBudget.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('startingBalance: $startingBalance, ')
          ..write('isClosed: $isClosed, ')
          ..write('onBudget: $onBudget, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryGroupsTable extends CategoryGroups
    with TableInfo<$CategoryGroupsTable, CategoryGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $CategoryGroupsTable createAlias(String alias) {
    return $CategoryGroupsTable(attachedDatabase, alias);
  }
}

class CategoryGroup extends DataClass implements Insertable<CategoryGroup> {
  final String id;
  final String name;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const CategoryGroup({
    required this.id,
    required this.name,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  CategoryGroupsCompanion toCompanion(bool nullToAbsent) {
    return CategoryGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory CategoryGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  CategoryGroup copyWith({
    String? id,
    String? name,
    Value<int?> sortOrder = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => CategoryGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  CategoryGroup copyWithCompanion(CategoryGroupsCompanion data) {
    return CategoryGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoryGroupsCompanion extends UpdateCompanion<CategoryGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> sortOrder;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const CategoryGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryGroupsCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CategoryGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? sortOrder,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoryGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryGroupIdMeta = const VerificationMeta(
    'categoryGroupId',
  );
  @override
  late final GeneratedColumn<String> categoryGroupId = GeneratedColumn<String>(
    'category_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_groups (id)',
    ),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<String> goalType = GeneratedColumn<String>(
    'goal_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<int> targetAmount = GeneratedColumn<int>(
    'target_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    categoryGroupId,
    isHidden,
    sortOrder,
    goalType,
    targetAmount,
    targetDate,
    color,
    icon,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_group_id')) {
      context.handle(
        _categoryGroupIdMeta,
        categoryGroupId.isAcceptableOrUnknown(
          data['category_group_id']!,
          _categoryGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_group_id'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      goalType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_type'],
      ),
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_amount'],
      ),
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String? categoryGroupId;
  final bool isHidden;
  final int? sortOrder;
  final String? goalType;

  /// Goal target in minor units.
  final int? targetAmount;
  final DateTime? targetDate;
  final int? color;
  final String? icon;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const Category({
    required this.id,
    required this.name,
    this.categoryGroupId,
    required this.isHidden,
    this.sortOrder,
    this.goalType,
    this.targetAmount,
    this.targetDate,
    this.color,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryGroupId != null) {
      map['category_group_id'] = Variable<String>(categoryGroupId);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    if (!nullToAbsent || goalType != null) {
      map['goal_type'] = Variable<String>(goalType);
    }
    if (!nullToAbsent || targetAmount != null) {
      map['target_amount'] = Variable<int>(targetAmount);
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      categoryGroupId: categoryGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryGroupId),
      isHidden: Value(isHidden),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      goalType: goalType == null && nullToAbsent
          ? const Value.absent()
          : Value(goalType),
      targetAmount: targetAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(targetAmount),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryGroupId: serializer.fromJson<String?>(json['categoryGroupId']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      goalType: serializer.fromJson<String?>(json['goalType']),
      targetAmount: serializer.fromJson<int?>(json['targetAmount']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      color: serializer.fromJson<int?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'categoryGroupId': serializer.toJson<String?>(categoryGroupId),
      'isHidden': serializer.toJson<bool>(isHidden),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'goalType': serializer.toJson<String?>(goalType),
      'targetAmount': serializer.toJson<int?>(targetAmount),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'color': serializer.toJson<int?>(color),
      'icon': serializer.toJson<String?>(icon),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    Value<String?> categoryGroupId = const Value.absent(),
    bool? isHidden,
    Value<int?> sortOrder = const Value.absent(),
    Value<String?> goalType = const Value.absent(),
    Value<int?> targetAmount = const Value.absent(),
    Value<DateTime?> targetDate = const Value.absent(),
    Value<int?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryGroupId: categoryGroupId.present
        ? categoryGroupId.value
        : this.categoryGroupId,
    isHidden: isHidden ?? this.isHidden,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    goalType: goalType.present ? goalType.value : this.goalType,
    targetAmount: targetAmount.present ? targetAmount.value : this.targetAmount,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryGroupId: data.categoryGroupId.present
          ? data.categoryGroupId.value
          : this.categoryGroupId,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryGroupId: $categoryGroupId, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('goalType: $goalType, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    categoryGroupId,
    isHidden,
    sortOrder,
    goalType,
    targetAmount,
    targetDate,
    color,
    icon,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryGroupId == this.categoryGroupId &&
          other.isHidden == this.isHidden &&
          other.sortOrder == this.sortOrder &&
          other.goalType == this.goalType &&
          other.targetAmount == this.targetAmount &&
          other.targetDate == this.targetDate &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> categoryGroupId;
  final Value<bool> isHidden;
  final Value<int?> sortOrder;
  final Value<String?> goalType;
  final Value<int?> targetAmount;
  final Value<DateTime?> targetDate;
  final Value<int?> color;
  final Value<String?> icon;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryGroupId = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.goalType = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    this.categoryGroupId = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.goalType = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? categoryGroupId,
    Expression<bool>? isHidden,
    Expression<int>? sortOrder,
    Expression<String>? goalType,
    Expression<int>? targetAmount,
    Expression<DateTime>? targetDate,
    Expression<int>? color,
    Expression<String>? icon,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryGroupId != null) 'category_group_id': categoryGroupId,
      if (isHidden != null) 'is_hidden': isHidden,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (goalType != null) 'goal_type': goalType,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (targetDate != null) 'target_date': targetDate,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? categoryGroupId,
    Value<bool>? isHidden,
    Value<int?>? sortOrder,
    Value<String?>? goalType,
    Value<int?>? targetAmount,
    Value<DateTime?>? targetDate,
    Value<int?>? color,
    Value<String?>? icon,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryGroupId: categoryGroupId ?? this.categoryGroupId,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryGroupId.present) {
      map['category_group_id'] = Variable<String>(categoryGroupId.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (goalType.present) {
      map['goal_type'] = Variable<String>(goalType.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<int>(targetAmount.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryGroupId: $categoryGroupId, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('goalType: $goalType, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetedMeta = const VerificationMeta(
    'budgeted',
  );
  @override
  late final GeneratedColumn<int> budgeted = GeneratedColumn<int>(
    'budgeted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    month,
    budgeted,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('budgeted')) {
      context.handle(
        _budgetedMeta,
        budgeted.isAcceptableOrUnknown(data['budgeted']!, _budgetedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoryId, month},
  ];
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      budgeted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budgeted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final String categoryId;
  final String month;

  /// Amount assigned to the category for the month, in minor units.
  /// Activity and available are always computed from transactions.
  final int budgeted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.budgeted,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['month'] = Variable<String>(month);
    map['budgeted'] = Variable<int>(budgeted);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      month: Value(month),
      budgeted: Value(budgeted),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      month: serializer.fromJson<String>(json['month']),
      budgeted: serializer.fromJson<int>(json['budgeted']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'month': serializer.toJson<String>(month),
      'budgeted': serializer.toJson<int>(budgeted),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Budget copyWith({
    String? id,
    String? categoryId,
    String? month,
    int? budgeted,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Budget(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    month: month ?? this.month,
    budgeted: budgeted ?? this.budgeted,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      month: data.month.present ? data.month.value : this.month,
      budgeted: data.budgeted.present ? data.budgeted.value : this.budgeted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('budgeted: $budgeted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryId, month, budgeted, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.month == this.month &&
          other.budgeted == this.budgeted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> month;
  final Value<int> budgeted;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.month = const Value.absent(),
    this.budgeted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required String categoryId,
    required String month,
    this.budgeted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       month = Value(month);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? month,
    Expression<int>? budgeted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (month != null) 'month': month,
      if (budgeted != null) 'budgeted': budgeted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? month,
    Value<int>? budgeted,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      budgeted: budgeted ?? this.budgeted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (budgeted.present) {
      map['budgeted'] = Variable<int>(budgeted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('budgeted: $budgeted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetTemplatesTable extends BudgetTemplates
    with TableInfo<$BudgetTemplatesTable, BudgetTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, data, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $BudgetTemplatesTable createAlias(String alias) {
    return $BudgetTemplatesTable(attachedDatabase, alias);
  }
}

class BudgetTemplate extends DataClass implements Insertable<BudgetTemplate> {
  final String id;
  final String name;

  /// JSON object mapping categoryId -> budgeted amount in minor units
  /// (`int`). Rows written before schema v15 held major-unit doubles and are
  /// converted by the v15 migration.
  final String data;
  final String? createdAt;
  final DateTime? updatedAt;
  const BudgetTemplate({
    required this.id,
    required this.name,
    required this.data,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  BudgetTemplatesCompanion toCompanion(bool nullToAbsent) {
    return BudgetTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      data: Value(data),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory BudgetTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'data': serializer.toJson<String>(data),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  BudgetTemplate copyWith({
    String? id,
    String? name,
    String? data,
    Value<String?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => BudgetTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    data: data ?? this.data,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  BudgetTemplate copyWithCompanion(BudgetTemplatesCompanion data) {
    return BudgetTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, data, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.data == this.data &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetTemplatesCompanion extends UpdateCompanion<BudgetTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> data;
  final Value<String?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const BudgetTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetTemplatesCompanion.insert({
    required String id,
    required String name,
    required String data,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       data = Value(data);
  static Insertable<BudgetTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? data,
    Expression<String>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? data,
    Value<String?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return BudgetTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayeesTable extends Payees with TableInfo<$PayeesTable, Payee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoCategoryIdMeta = const VerificationMeta(
    'autoCategoryId',
  );
  @override
  late final GeneratedColumn<String> autoCategoryId = GeneratedColumn<String>(
    'auto_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _defaultAccountIdMeta = const VerificationMeta(
    'defaultAccountId',
  );
  @override
  late final GeneratedColumn<String> defaultAccountId = GeneratedColumn<String>(
    'default_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    autoCategoryId,
    defaultAccountId,
    createdAt,
    updatedAt,
    icon,
    color,
    notes,
    isFavorite,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('auto_category_id')) {
      context.handle(
        _autoCategoryIdMeta,
        autoCategoryId.isAcceptableOrUnknown(
          data['auto_category_id']!,
          _autoCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('default_account_id')) {
      context.handle(
        _defaultAccountIdMeta,
        defaultAccountId.isAcceptableOrUnknown(
          data['default_account_id']!,
          _defaultAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      autoCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auto_category_id'],
      ),
      defaultAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_account_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
    );
  }

  @override
  $PayeesTable createAlias(String alias) {
    return $PayeesTable(attachedDatabase, alias);
  }
}

class Payee extends DataClass implements Insertable<Payee> {
  final String id;
  final String name;
  final String? autoCategoryId;
  final String? defaultAccountId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? icon;
  final int? color;
  final String? notes;
  final bool isFavorite;
  const Payee({
    required this.id,
    required this.name,
    this.autoCategoryId,
    this.defaultAccountId,
    this.createdAt,
    this.updatedAt,
    this.icon,
    this.color,
    this.notes,
    required this.isFavorite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || autoCategoryId != null) {
      map['auto_category_id'] = Variable<String>(autoCategoryId);
    }
    if (!nullToAbsent || defaultAccountId != null) {
      map['default_account_id'] = Variable<String>(defaultAccountId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    return map;
  }

  PayeesCompanion toCompanion(bool nullToAbsent) {
    return PayeesCompanion(
      id: Value(id),
      name: Value(name),
      autoCategoryId: autoCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(autoCategoryId),
      defaultAccountId: defaultAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAccountId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isFavorite: Value(isFavorite),
    );
  }

  factory Payee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payee(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      autoCategoryId: serializer.fromJson<String?>(json['autoCategoryId']),
      defaultAccountId: serializer.fromJson<String?>(json['defaultAccountId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<int?>(json['color']),
      notes: serializer.fromJson<String?>(json['notes']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'autoCategoryId': serializer.toJson<String?>(autoCategoryId),
      'defaultAccountId': serializer.toJson<String?>(defaultAccountId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<int?>(color),
      'notes': serializer.toJson<String?>(notes),
      'isFavorite': serializer.toJson<bool>(isFavorite),
    };
  }

  Payee copyWith({
    String? id,
    String? name,
    Value<String?> autoCategoryId = const Value.absent(),
    Value<String?> defaultAccountId = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<int?> color = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? isFavorite,
  }) => Payee(
    id: id ?? this.id,
    name: name ?? this.name,
    autoCategoryId: autoCategoryId.present
        ? autoCategoryId.value
        : this.autoCategoryId,
    defaultAccountId: defaultAccountId.present
        ? defaultAccountId.value
        : this.defaultAccountId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    notes: notes.present ? notes.value : this.notes,
    isFavorite: isFavorite ?? this.isFavorite,
  );
  Payee copyWithCompanion(PayeesCompanion data) {
    return Payee(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      autoCategoryId: data.autoCategoryId.present
          ? data.autoCategoryId.value
          : this.autoCategoryId,
      defaultAccountId: data.defaultAccountId.present
          ? data.defaultAccountId.value
          : this.defaultAccountId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      notes: data.notes.present ? data.notes.value : this.notes,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payee(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('autoCategoryId: $autoCategoryId, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('isFavorite: $isFavorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    autoCategoryId,
    defaultAccountId,
    createdAt,
    updatedAt,
    icon,
    color,
    notes,
    isFavorite,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payee &&
          other.id == this.id &&
          other.name == this.name &&
          other.autoCategoryId == this.autoCategoryId &&
          other.defaultAccountId == this.defaultAccountId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.notes == this.notes &&
          other.isFavorite == this.isFavorite);
}

class PayeesCompanion extends UpdateCompanion<Payee> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> autoCategoryId;
  final Value<String?> defaultAccountId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<String?> icon;
  final Value<int?> color;
  final Value<String?> notes;
  final Value<bool> isFavorite;
  final Value<int> rowid;
  const PayeesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.autoCategoryId = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayeesCompanion.insert({
    required String id,
    required String name,
    this.autoCategoryId = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Payee> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? autoCategoryId,
    Expression<String>? defaultAccountId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? notes,
    Expression<bool>? isFavorite,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (autoCategoryId != null) 'auto_category_id': autoCategoryId,
      if (defaultAccountId != null) 'default_account_id': defaultAccountId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (notes != null) 'notes': notes,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayeesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? autoCategoryId,
    Value<String?>? defaultAccountId,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<String?>? icon,
    Value<int?>? color,
    Value<String?>? notes,
    Value<bool>? isFavorite,
    Value<int>? rowid,
  }) {
    return PayeesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      autoCategoryId: autoCategoryId ?? this.autoCategoryId,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (autoCategoryId.present) {
      map['auto_category_id'] = Variable<String>(autoCategoryId.value);
    }
    if (defaultAccountId.present) {
      map['default_account_id'] = Variable<String>(defaultAccountId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('autoCategoryId: $autoCategoryId, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<String> payeeId = GeneratedColumn<String>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payees (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clearedMeta = const VerificationMeta(
    'cleared',
  );
  @override
  late final GeneratedColumn<int> cleared = GeneratedColumn<int>(
    'cleared',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _approvedMeta = const VerificationMeta(
    'approved',
  );
  @override
  late final GeneratedColumn<bool> approved = GeneratedColumn<bool>(
    'approved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("approved" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _transferAccountIdMeta = const VerificationMeta(
    'transferAccountId',
  );
  @override
  late final GeneratedColumn<String> transferAccountId =
      GeneratedColumn<String>(
        'transfer_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (id)',
        ),
      );
  static const VerificationMeta _transferTransactionIdMeta =
      const VerificationMeta('transferTransactionId');
  @override
  late final GeneratedColumn<String> transferTransactionId =
      GeneratedColumn<String>(
        'transfer_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _parentTransactionIdMeta =
      const VerificationMeta('parentTransactionId');
  @override
  late final GeneratedColumn<String> parentTransactionId =
      GeneratedColumn<String>(
        'parent_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES transactions (id)',
        ),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    date,
    amount,
    payeeId,
    categoryId,
    memo,
    cleared,
    approved,
    isDeleted,
    transferAccountId,
    transferTransactionId,
    parentTransactionId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('cleared')) {
      context.handle(
        _clearedMeta,
        cleared.isAcceptableOrUnknown(data['cleared']!, _clearedMeta),
      );
    }
    if (data.containsKey('approved')) {
      context.handle(
        _approvedMeta,
        approved.isAcceptableOrUnknown(data['approved']!, _approvedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('transfer_account_id')) {
      context.handle(
        _transferAccountIdMeta,
        transferAccountId.isAcceptableOrUnknown(
          data['transfer_account_id']!,
          _transferAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('transfer_transaction_id')) {
      context.handle(
        _transferTransactionIdMeta,
        transferTransactionId.isAcceptableOrUnknown(
          data['transfer_transaction_id']!,
          _transferTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_transaction_id')) {
      context.handle(
        _parentTransactionIdMeta,
        parentTransactionId.isAcceptableOrUnknown(
          data['parent_transaction_id']!,
          _parentTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      cleared: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cleared'],
      )!,
      approved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}approved'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      transferAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_account_id'],
      ),
      transferTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_transaction_id'],
      ),
      parentTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String accountId;
  final DateTime date;

  /// Amount in minor units (hundredths); negative = outflow.
  final int amount;
  final String? payeeId;
  final String? categoryId;
  final String? memo;
  final int cleared;
  final bool approved;
  final bool isDeleted;
  final String? transferAccountId;
  final String? transferTransactionId;
  final String? parentTransactionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const Transaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amount,
    this.payeeId,
    this.categoryId,
    this.memo,
    required this.cleared,
    required this.approved,
    required this.isDeleted,
    this.transferAccountId,
    this.transferTransactionId,
    this.parentTransactionId,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['date'] = Variable<DateTime>(date);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<String>(payeeId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['cleared'] = Variable<int>(cleared);
    map['approved'] = Variable<bool>(approved);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || transferAccountId != null) {
      map['transfer_account_id'] = Variable<String>(transferAccountId);
    }
    if (!nullToAbsent || transferTransactionId != null) {
      map['transfer_transaction_id'] = Variable<String>(transferTransactionId);
    }
    if (!nullToAbsent || parentTransactionId != null) {
      map['parent_transaction_id'] = Variable<String>(parentTransactionId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      date: Value(date),
      amount: Value(amount),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      cleared: Value(cleared),
      approved: Value(approved),
      isDeleted: Value(isDeleted),
      transferAccountId: transferAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferAccountId),
      transferTransactionId: transferTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferTransactionId),
      parentTransactionId: parentTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTransactionId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amount: serializer.fromJson<int>(json['amount']),
      payeeId: serializer.fromJson<String?>(json['payeeId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      memo: serializer.fromJson<String?>(json['memo']),
      cleared: serializer.fromJson<int>(json['cleared']),
      approved: serializer.fromJson<bool>(json['approved']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      transferAccountId: serializer.fromJson<String?>(
        json['transferAccountId'],
      ),
      transferTransactionId: serializer.fromJson<String?>(
        json['transferTransactionId'],
      ),
      parentTransactionId: serializer.fromJson<String?>(
        json['parentTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'date': serializer.toJson<DateTime>(date),
      'amount': serializer.toJson<int>(amount),
      'payeeId': serializer.toJson<String?>(payeeId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'memo': serializer.toJson<String?>(memo),
      'cleared': serializer.toJson<int>(cleared),
      'approved': serializer.toJson<bool>(approved),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'transferAccountId': serializer.toJson<String?>(transferAccountId),
      'transferTransactionId': serializer.toJson<String?>(
        transferTransactionId,
      ),
      'parentTransactionId': serializer.toJson<String?>(parentTransactionId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? accountId,
    DateTime? date,
    int? amount,
    Value<String?> payeeId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    int? cleared,
    bool? approved,
    bool? isDeleted,
    Value<String?> transferAccountId = const Value.absent(),
    Value<String?> transferTransactionId = const Value.absent(),
    Value<String?> parentTransactionId = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    memo: memo.present ? memo.value : this.memo,
    cleared: cleared ?? this.cleared,
    approved: approved ?? this.approved,
    isDeleted: isDeleted ?? this.isDeleted,
    transferAccountId: transferAccountId.present
        ? transferAccountId.value
        : this.transferAccountId,
    transferTransactionId: transferTransactionId.present
        ? transferTransactionId.value
        : this.transferTransactionId,
    parentTransactionId: parentTransactionId.present
        ? parentTransactionId.value
        : this.parentTransactionId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      date: data.date.present ? data.date.value : this.date,
      amount: data.amount.present ? data.amount.value : this.amount,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      memo: data.memo.present ? data.memo.value : this.memo,
      cleared: data.cleared.present ? data.cleared.value : this.cleared,
      approved: data.approved.present ? data.approved.value : this.approved,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      transferAccountId: data.transferAccountId.present
          ? data.transferAccountId.value
          : this.transferAccountId,
      transferTransactionId: data.transferTransactionId.present
          ? data.transferTransactionId.value
          : this.transferTransactionId,
      parentTransactionId: data.parentTransactionId.present
          ? data.parentTransactionId.value
          : this.parentTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('memo: $memo, ')
          ..write('cleared: $cleared, ')
          ..write('approved: $approved, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('transferAccountId: $transferAccountId, ')
          ..write('transferTransactionId: $transferTransactionId, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    date,
    amount,
    payeeId,
    categoryId,
    memo,
    cleared,
    approved,
    isDeleted,
    transferAccountId,
    transferTransactionId,
    parentTransactionId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.date == this.date &&
          other.amount == this.amount &&
          other.payeeId == this.payeeId &&
          other.categoryId == this.categoryId &&
          other.memo == this.memo &&
          other.cleared == this.cleared &&
          other.approved == this.approved &&
          other.isDeleted == this.isDeleted &&
          other.transferAccountId == this.transferAccountId &&
          other.transferTransactionId == this.transferTransactionId &&
          other.parentTransactionId == this.parentTransactionId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<DateTime> date;
  final Value<int> amount;
  final Value<String?> payeeId;
  final Value<String?> categoryId;
  final Value<String?> memo;
  final Value<int> cleared;
  final Value<bool> approved;
  final Value<bool> isDeleted;
  final Value<String?> transferAccountId;
  final Value<String?> transferTransactionId;
  final Value<String?> parentTransactionId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.date = const Value.absent(),
    this.amount = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.memo = const Value.absent(),
    this.cleared = const Value.absent(),
    this.approved = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.transferAccountId = const Value.absent(),
    this.transferTransactionId = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String accountId,
    required DateTime date,
    required int amount,
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.memo = const Value.absent(),
    this.cleared = const Value.absent(),
    this.approved = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.transferAccountId = const Value.absent(),
    this.transferTransactionId = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       date = Value(date),
       amount = Value(amount);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<DateTime>? date,
    Expression<int>? amount,
    Expression<String>? payeeId,
    Expression<String>? categoryId,
    Expression<String>? memo,
    Expression<int>? cleared,
    Expression<bool>? approved,
    Expression<bool>? isDeleted,
    Expression<String>? transferAccountId,
    Expression<String>? transferTransactionId,
    Expression<String>? parentTransactionId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (date != null) 'date': date,
      if (amount != null) 'amount': amount,
      if (payeeId != null) 'payee_id': payeeId,
      if (categoryId != null) 'category_id': categoryId,
      if (memo != null) 'memo': memo,
      if (cleared != null) 'cleared': cleared,
      if (approved != null) 'approved': approved,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (transferAccountId != null) 'transfer_account_id': transferAccountId,
      if (transferTransactionId != null)
        'transfer_transaction_id': transferTransactionId,
      if (parentTransactionId != null)
        'parent_transaction_id': parentTransactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<DateTime>? date,
    Value<int>? amount,
    Value<String?>? payeeId,
    Value<String?>? categoryId,
    Value<String?>? memo,
    Value<int>? cleared,
    Value<bool>? approved,
    Value<bool>? isDeleted,
    Value<String?>? transferAccountId,
    Value<String?>? transferTransactionId,
    Value<String?>? parentTransactionId,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      memo: memo ?? this.memo,
      cleared: cleared ?? this.cleared,
      approved: approved ?? this.approved,
      isDeleted: isDeleted ?? this.isDeleted,
      transferAccountId: transferAccountId ?? this.transferAccountId,
      transferTransactionId:
          transferTransactionId ?? this.transferTransactionId,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<String>(payeeId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (cleared.present) {
      map['cleared'] = Variable<int>(cleared.value);
    }
    if (approved.present) {
      map['approved'] = Variable<bool>(approved.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (transferAccountId.present) {
      map['transfer_account_id'] = Variable<String>(transferAccountId.value);
    }
    if (transferTransactionId.present) {
      map['transfer_transaction_id'] = Variable<String>(
        transferTransactionId.value,
      );
    }
    if (parentTransactionId.present) {
      map['parent_transaction_id'] = Variable<String>(
        parentTransactionId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('memo: $memo, ')
          ..write('cleared: $cleared, ')
          ..write('approved: $approved, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('transferAccountId: $transferAccountId, ')
          ..write('transferTransactionId: $transferTransactionId, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReportNotesTable extends ReportNotes
    with TableInfo<$ReportNotesTable, ReportNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, note, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date},
  ];
  @override
  ReportNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ReportNotesTable createAlias(String alias) {
    return $ReportNotesTable(attachedDatabase, alias);
  }
}

class ReportNote extends DataClass implements Insertable<ReportNote> {
  final String id;

  /// The month the note belongs to, `YYYY-MM` (one note per month).
  final String date;
  final String note;
  final String? createdAt;
  final String? updatedAt;
  const ReportNote({
    required this.id,
    required this.date,
    required this.note,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ReportNotesCompanion toCompanion(bool nullToAbsent) {
    return ReportNotesCompanion(
      id: Value(id),
      date: Value(date),
      note: Value(note),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ReportNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportNote(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  ReportNote copyWith({
    String? id,
    String? date,
    String? note,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => ReportNote(
    id: id ?? this.id,
    date: date ?? this.date,
    note: note ?? this.note,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ReportNote copyWithCompanion(ReportNotesCompanion data) {
    return ReportNote(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportNote(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, note, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportNote &&
          other.id == this.id &&
          other.date == this.date &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReportNotesCompanion extends UpdateCompanion<ReportNote> {
  final Value<String> id;
  final Value<String> date;
  final Value<String> note;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const ReportNotesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportNotesCompanion.insert({
    required String id,
    required String date,
    required String note,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       note = Value(note);
  static Insertable<ReportNote> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? note,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<String>? note,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReportNotesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportNotesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledTransactionsTable extends ScheduledTransactions
    with TableInfo<$ScheduledTransactionsTable, ScheduledTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<String> payeeId = GeneratedColumn<String>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payees (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurrenceCountMeta = const VerificationMeta(
    'occurrenceCount',
  );
  @override
  late final GeneratedColumn<int> occurrenceCount = GeneratedColumn<int>(
    'occurrence_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDate = GeneratedColumn<DateTime>(
    'next_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoApproveMeta = const VerificationMeta(
    'autoApprove',
  );
  @override
  late final GeneratedColumn<bool> autoApprove = GeneratedColumn<bool>(
    'auto_approve',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_approve" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchorDayMeta = const VerificationMeta(
    'anchorDay',
  );
  @override
  late final GeneratedColumn<int> anchorDay = GeneratedColumn<int>(
    'anchor_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    payeeId,
    categoryId,
    amount,
    frequency,
    interval,
    occurrenceCount,
    nextDate,
    endDate,
    autoApprove,
    memo,
    anchorDay,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('occurrence_count')) {
      context.handle(
        _occurrenceCountMeta,
        occurrenceCount.isAcceptableOrUnknown(
          data['occurrence_count']!,
          _occurrenceCountMeta,
        ),
      );
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('auto_approve')) {
      context.handle(
        _autoApproveMeta,
        autoApprove.isAcceptableOrUnknown(
          data['auto_approve']!,
          _autoApproveMeta,
        ),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('anchor_day')) {
      context.handle(
        _anchorDayMeta,
        anchorDay.isAcceptableOrUnknown(data['anchor_day']!, _anchorDayMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      ),
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      ),
      occurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_count'],
      ),
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      autoApprove: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_approve'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      anchorDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anchor_day'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ScheduledTransactionsTable createAlias(String alias) {
    return $ScheduledTransactionsTable(attachedDatabase, alias);
  }
}

class ScheduledTransaction extends DataClass
    implements Insertable<ScheduledTransaction> {
  final String id;
  final String? accountId;
  final String? payeeId;
  final String? categoryId;

  /// Amount in minor units (negative = outflow).
  final int? amount;
  final String? frequency;
  final int? interval;
  final int? occurrenceCount;
  final DateTime? nextDate;
  final DateTime? endDate;
  final bool autoApprove;

  /// Memo copied to each generated transaction (schema v16).
  final String? memo;

  /// Day of month (1-31) monthly/yearly schedules aim for (schema v16).
  /// Keeps "every month on the 31st" on the 31st after a short month clamps
  /// one occurrence to the 28th/30th. `null` means: the day of `next_date`.
  final int? anchorDay;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const ScheduledTransaction({
    required this.id,
    this.accountId,
    this.payeeId,
    this.categoryId,
    this.amount,
    this.frequency,
    this.interval,
    this.occurrenceCount,
    this.nextDate,
    this.endDate,
    required this.autoApprove,
    this.memo,
    this.anchorDay,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<String>(payeeId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<int>(amount);
    }
    if (!nullToAbsent || frequency != null) {
      map['frequency'] = Variable<String>(frequency);
    }
    if (!nullToAbsent || interval != null) {
      map['interval'] = Variable<int>(interval);
    }
    if (!nullToAbsent || occurrenceCount != null) {
      map['occurrence_count'] = Variable<int>(occurrenceCount);
    }
    if (!nullToAbsent || nextDate != null) {
      map['next_date'] = Variable<DateTime>(nextDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['auto_approve'] = Variable<bool>(autoApprove);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || anchorDay != null) {
      map['anchor_day'] = Variable<int>(anchorDay);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ScheduledTransactionsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledTransactionsCompanion(
      id: Value(id),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      frequency: frequency == null && nullToAbsent
          ? const Value.absent()
          : Value(frequency),
      interval: interval == null && nullToAbsent
          ? const Value.absent()
          : Value(interval),
      occurrenceCount: occurrenceCount == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceCount),
      nextDate: nextDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      autoApprove: Value(autoApprove),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      anchorDay: anchorDay == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorDay),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ScheduledTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledTransaction(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      payeeId: serializer.fromJson<String?>(json['payeeId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<int?>(json['amount']),
      frequency: serializer.fromJson<String?>(json['frequency']),
      interval: serializer.fromJson<int?>(json['interval']),
      occurrenceCount: serializer.fromJson<int?>(json['occurrenceCount']),
      nextDate: serializer.fromJson<DateTime?>(json['nextDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      autoApprove: serializer.fromJson<bool>(json['autoApprove']),
      memo: serializer.fromJson<String?>(json['memo']),
      anchorDay: serializer.fromJson<int?>(json['anchorDay']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String?>(accountId),
      'payeeId': serializer.toJson<String?>(payeeId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<int?>(amount),
      'frequency': serializer.toJson<String?>(frequency),
      'interval': serializer.toJson<int?>(interval),
      'occurrenceCount': serializer.toJson<int?>(occurrenceCount),
      'nextDate': serializer.toJson<DateTime?>(nextDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'autoApprove': serializer.toJson<bool>(autoApprove),
      'memo': serializer.toJson<String?>(memo),
      'anchorDay': serializer.toJson<int?>(anchorDay),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ScheduledTransaction copyWith({
    String? id,
    Value<String?> accountId = const Value.absent(),
    Value<String?> payeeId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<int?> amount = const Value.absent(),
    Value<String?> frequency = const Value.absent(),
    Value<int?> interval = const Value.absent(),
    Value<int?> occurrenceCount = const Value.absent(),
    Value<DateTime?> nextDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    bool? autoApprove,
    Value<String?> memo = const Value.absent(),
    Value<int?> anchorDay = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => ScheduledTransaction(
    id: id ?? this.id,
    accountId: accountId.present ? accountId.value : this.accountId,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amount: amount.present ? amount.value : this.amount,
    frequency: frequency.present ? frequency.value : this.frequency,
    interval: interval.present ? interval.value : this.interval,
    occurrenceCount: occurrenceCount.present
        ? occurrenceCount.value
        : this.occurrenceCount,
    nextDate: nextDate.present ? nextDate.value : this.nextDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    autoApprove: autoApprove ?? this.autoApprove,
    memo: memo.present ? memo.value : this.memo,
    anchorDay: anchorDay.present ? anchorDay.value : this.anchorDay,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ScheduledTransaction copyWithCompanion(ScheduledTransactionsCompanion data) {
    return ScheduledTransaction(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      occurrenceCount: data.occurrenceCount.present
          ? data.occurrenceCount.value
          : this.occurrenceCount,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      autoApprove: data.autoApprove.present
          ? data.autoApprove.value
          : this.autoApprove,
      memo: data.memo.present ? data.memo.value : this.memo,
      anchorDay: data.anchorDay.present ? data.anchorDay.value : this.anchorDay,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTransaction(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('occurrenceCount: $occurrenceCount, ')
          ..write('nextDate: $nextDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('memo: $memo, ')
          ..write('anchorDay: $anchorDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    payeeId,
    categoryId,
    amount,
    frequency,
    interval,
    occurrenceCount,
    nextDate,
    endDate,
    autoApprove,
    memo,
    anchorDay,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledTransaction &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.payeeId == this.payeeId &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.occurrenceCount == this.occurrenceCount &&
          other.nextDate == this.nextDate &&
          other.endDate == this.endDate &&
          other.autoApprove == this.autoApprove &&
          other.memo == this.memo &&
          other.anchorDay == this.anchorDay &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduledTransactionsCompanion
    extends UpdateCompanion<ScheduledTransaction> {
  final Value<String> id;
  final Value<String?> accountId;
  final Value<String?> payeeId;
  final Value<String?> categoryId;
  final Value<int?> amount;
  final Value<String?> frequency;
  final Value<int?> interval;
  final Value<int?> occurrenceCount;
  final Value<DateTime?> nextDate;
  final Value<DateTime?> endDate;
  final Value<bool> autoApprove;
  final Value<String?> memo;
  final Value<int?> anchorDay;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const ScheduledTransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.occurrenceCount = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.memo = const Value.absent(),
    this.anchorDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduledTransactionsCompanion.insert({
    required String id,
    this.accountId = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.occurrenceCount = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.memo = const Value.absent(),
    this.anchorDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ScheduledTransaction> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? payeeId,
    Expression<String>? categoryId,
    Expression<int>? amount,
    Expression<String>? frequency,
    Expression<int>? interval,
    Expression<int>? occurrenceCount,
    Expression<DateTime>? nextDate,
    Expression<DateTime>? endDate,
    Expression<bool>? autoApprove,
    Expression<String>? memo,
    Expression<int>? anchorDay,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (payeeId != null) 'payee_id': payeeId,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (occurrenceCount != null) 'occurrence_count': occurrenceCount,
      if (nextDate != null) 'next_date': nextDate,
      if (endDate != null) 'end_date': endDate,
      if (autoApprove != null) 'auto_approve': autoApprove,
      if (memo != null) 'memo': memo,
      if (anchorDay != null) 'anchor_day': anchorDay,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduledTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? accountId,
    Value<String?>? payeeId,
    Value<String?>? categoryId,
    Value<int?>? amount,
    Value<String?>? frequency,
    Value<int?>? interval,
    Value<int?>? occurrenceCount,
    Value<DateTime?>? nextDate,
    Value<DateTime?>? endDate,
    Value<bool>? autoApprove,
    Value<String?>? memo,
    Value<int?>? anchorDay,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScheduledTransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      nextDate: nextDate ?? this.nextDate,
      endDate: endDate ?? this.endDate,
      autoApprove: autoApprove ?? this.autoApprove,
      memo: memo ?? this.memo,
      anchorDay: anchorDay ?? this.anchorDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<String>(payeeId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (occurrenceCount.present) {
      map['occurrence_count'] = Variable<int>(occurrenceCount.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<DateTime>(nextDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (autoApprove.present) {
      map['auto_approve'] = Variable<bool>(autoApprove.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (anchorDay.present) {
      map['anchor_day'] = Variable<int>(anchorDay.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('occurrenceCount: $occurrenceCount, ')
          ..write('nextDate: $nextDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('memo: $memo, ')
          ..write('anchorDay: $anchorDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingSyncChangesTable extends PendingSyncChanges
    with TableInfo<$PendingSyncChangesTable, PendingSyncChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTableNameMeta = const VerificationMeta(
    'targetTableName',
  );
  @override
  late final GeneratedColumn<String> targetTableName = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _oldUpdatedAtMeta = const VerificationMeta(
    'oldUpdatedAt',
  );
  @override
  late final GeneratedColumn<String> oldUpdatedAt = GeneratedColumn<String>(
    'old_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetTableName,
    recordId,
    action,
    changedAt,
    oldUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sync_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSyncChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _targetTableNameMeta,
        targetTableName.isAcceptableOrUnknown(
          data['table_name']!,
          _targetTableNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableNameMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    }
    if (data.containsKey('old_updated_at')) {
      context.handle(
        _oldUpdatedAtMeta,
        oldUpdatedAt.isAcceptableOrUnknown(
          data['old_updated_at']!,
          _oldUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSyncChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetTableName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      oldUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_updated_at'],
      ),
    );
  }

  @override
  $PendingSyncChangesTable createAlias(String alias) {
    return $PendingSyncChangesTable(attachedDatabase, alias);
  }
}

class PendingSyncChange extends DataClass
    implements Insertable<PendingSyncChange> {
  final int id;
  final String targetTableName;
  final String recordId;
  final String action;
  final DateTime changedAt;

  /// DELETE only: the deleted row's `updated_at` (raw), so the tombstone's
  /// timestamp is never older than the last edit it deletes (schema v17).
  final String? oldUpdatedAt;
  const PendingSyncChange({
    required this.id,
    required this.targetTableName,
    required this.recordId,
    required this.action,
    required this.changedAt,
    this.oldUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(targetTableName);
    map['record_id'] = Variable<String>(recordId);
    map['action'] = Variable<String>(action);
    map['changed_at'] = Variable<DateTime>(changedAt);
    if (!nullToAbsent || oldUpdatedAt != null) {
      map['old_updated_at'] = Variable<String>(oldUpdatedAt);
    }
    return map;
  }

  PendingSyncChangesCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncChangesCompanion(
      id: Value(id),
      targetTableName: Value(targetTableName),
      recordId: Value(recordId),
      action: Value(action),
      changedAt: Value(changedAt),
      oldUpdatedAt: oldUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(oldUpdatedAt),
    );
  }

  factory PendingSyncChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncChange(
      id: serializer.fromJson<int>(json['id']),
      targetTableName: serializer.fromJson<String>(json['targetTableName']),
      recordId: serializer.fromJson<String>(json['recordId']),
      action: serializer.fromJson<String>(json['action']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      oldUpdatedAt: serializer.fromJson<String?>(json['oldUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetTableName': serializer.toJson<String>(targetTableName),
      'recordId': serializer.toJson<String>(recordId),
      'action': serializer.toJson<String>(action),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'oldUpdatedAt': serializer.toJson<String?>(oldUpdatedAt),
    };
  }

  PendingSyncChange copyWith({
    int? id,
    String? targetTableName,
    String? recordId,
    String? action,
    DateTime? changedAt,
    Value<String?> oldUpdatedAt = const Value.absent(),
  }) => PendingSyncChange(
    id: id ?? this.id,
    targetTableName: targetTableName ?? this.targetTableName,
    recordId: recordId ?? this.recordId,
    action: action ?? this.action,
    changedAt: changedAt ?? this.changedAt,
    oldUpdatedAt: oldUpdatedAt.present ? oldUpdatedAt.value : this.oldUpdatedAt,
  );
  PendingSyncChange copyWithCompanion(PendingSyncChangesCompanion data) {
    return PendingSyncChange(
      id: data.id.present ? data.id.value : this.id,
      targetTableName: data.targetTableName.present
          ? data.targetTableName.value
          : this.targetTableName,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      action: data.action.present ? data.action.value : this.action,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      oldUpdatedAt: data.oldUpdatedAt.present
          ? data.oldUpdatedAt.value
          : this.oldUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncChange(')
          ..write('id: $id, ')
          ..write('targetTableName: $targetTableName, ')
          ..write('recordId: $recordId, ')
          ..write('action: $action, ')
          ..write('changedAt: $changedAt, ')
          ..write('oldUpdatedAt: $oldUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetTableName,
    recordId,
    action,
    changedAt,
    oldUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncChange &&
          other.id == this.id &&
          other.targetTableName == this.targetTableName &&
          other.recordId == this.recordId &&
          other.action == this.action &&
          other.changedAt == this.changedAt &&
          other.oldUpdatedAt == this.oldUpdatedAt);
}

class PendingSyncChangesCompanion extends UpdateCompanion<PendingSyncChange> {
  final Value<int> id;
  final Value<String> targetTableName;
  final Value<String> recordId;
  final Value<String> action;
  final Value<DateTime> changedAt;
  final Value<String?> oldUpdatedAt;
  const PendingSyncChangesCompanion({
    this.id = const Value.absent(),
    this.targetTableName = const Value.absent(),
    this.recordId = const Value.absent(),
    this.action = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.oldUpdatedAt = const Value.absent(),
  });
  PendingSyncChangesCompanion.insert({
    this.id = const Value.absent(),
    required String targetTableName,
    required String recordId,
    required String action,
    this.changedAt = const Value.absent(),
    this.oldUpdatedAt = const Value.absent(),
  }) : targetTableName = Value(targetTableName),
       recordId = Value(recordId),
       action = Value(action);
  static Insertable<PendingSyncChange> custom({
    Expression<int>? id,
    Expression<String>? targetTableName,
    Expression<String>? recordId,
    Expression<String>? action,
    Expression<DateTime>? changedAt,
    Expression<String>? oldUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTableName != null) 'table_name': targetTableName,
      if (recordId != null) 'record_id': recordId,
      if (action != null) 'action': action,
      if (changedAt != null) 'changed_at': changedAt,
      if (oldUpdatedAt != null) 'old_updated_at': oldUpdatedAt,
    });
  }

  PendingSyncChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? targetTableName,
    Value<String>? recordId,
    Value<String>? action,
    Value<DateTime>? changedAt,
    Value<String?>? oldUpdatedAt,
  }) {
    return PendingSyncChangesCompanion(
      id: id ?? this.id,
      targetTableName: targetTableName ?? this.targetTableName,
      recordId: recordId ?? this.recordId,
      action: action ?? this.action,
      changedAt: changedAt ?? this.changedAt,
      oldUpdatedAt: oldUpdatedAt ?? this.oldUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetTableName.present) {
      map['table_name'] = Variable<String>(targetTableName.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (oldUpdatedAt.present) {
      map['old_updated_at'] = Variable<String>(oldUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncChangesCompanion(')
          ..write('id: $id, ')
          ..write('targetTableName: $targetTableName, ')
          ..write('recordId: $recordId, ')
          ..write('action: $action, ')
          ..write('changedAt: $changedAt, ')
          ..write('oldUpdatedAt: $oldUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $ParsingHistoryTable extends ParsingHistory
    with TableInfo<$ParsingHistoryTable, ParsingHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParsingHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputMeta = const VerificationMeta('input');
  @override
  late final GeneratedColumn<String> input = GeneratedColumn<String>(
    'input',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<String> payeeId = GeneratedColumn<String>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    input,
    payeeId,
    categoryId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parsing_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParsingHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('input')) {
      context.handle(
        _inputMeta,
        input.isAcceptableOrUnknown(data['input']!, _inputMeta),
      );
    } else if (isInserting) {
      context.missing(_inputMeta);
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParsingHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParsingHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      input: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ParsingHistoryTable createAlias(String alias) {
    return $ParsingHistoryTable(attachedDatabase, alias);
  }
}

class ParsingHistoryData extends DataClass
    implements Insertable<ParsingHistoryData> {
  final String id;
  final String input;
  final String? payeeId;
  final String? categoryId;
  final String createdAt;
  const ParsingHistoryData({
    required this.id,
    required this.input,
    this.payeeId,
    this.categoryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['input'] = Variable<String>(input);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<String>(payeeId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ParsingHistoryCompanion toCompanion(bool nullToAbsent) {
    return ParsingHistoryCompanion(
      id: Value(id),
      input: Value(input),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      createdAt: Value(createdAt),
    );
  }

  factory ParsingHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParsingHistoryData(
      id: serializer.fromJson<String>(json['id']),
      input: serializer.fromJson<String>(json['input']),
      payeeId: serializer.fromJson<String?>(json['payeeId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'input': serializer.toJson<String>(input),
      'payeeId': serializer.toJson<String?>(payeeId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ParsingHistoryData copyWith({
    String? id,
    String? input,
    Value<String?> payeeId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    String? createdAt,
  }) => ParsingHistoryData(
    id: id ?? this.id,
    input: input ?? this.input,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    createdAt: createdAt ?? this.createdAt,
  );
  ParsingHistoryData copyWithCompanion(ParsingHistoryCompanion data) {
    return ParsingHistoryData(
      id: data.id.present ? data.id.value : this.id,
      input: data.input.present ? data.input.value : this.input,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParsingHistoryData(')
          ..write('id: $id, ')
          ..write('input: $input, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, input, payeeId, categoryId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParsingHistoryData &&
          other.id == this.id &&
          other.input == this.input &&
          other.payeeId == this.payeeId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt);
}

class ParsingHistoryCompanion extends UpdateCompanion<ParsingHistoryData> {
  final Value<String> id;
  final Value<String> input;
  final Value<String?> payeeId;
  final Value<String?> categoryId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ParsingHistoryCompanion({
    this.id = const Value.absent(),
    this.input = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParsingHistoryCompanion.insert({
    required String id,
    required String input,
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       input = Value(input),
       createdAt = Value(createdAt);
  static Insertable<ParsingHistoryData> custom({
    Expression<String>? id,
    Expression<String>? input,
    Expression<String>? payeeId,
    Expression<String>? categoryId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (input != null) 'input': input,
      if (payeeId != null) 'payee_id': payeeId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParsingHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? input,
    Value<String?>? payeeId,
    Value<String?>? categoryId,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ParsingHistoryCompanion(
      id: id ?? this.id,
      input: input ?? this.input,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (input.present) {
      map['input'] = Variable<String>(input.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<String>(payeeId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParsingHistoryCompanion(')
          ..write('id: $id, ')
          ..write('input: $input, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportProfilesTable extends ImportProfiles
    with TableInfo<$ImportProfilesTable, ImportProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateFormatMeta = const VerificationMeta(
    'dateFormat',
  );
  @override
  late final GeneratedColumn<String> dateFormat = GeneratedColumn<String>(
    'date_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decimalSeparatorMeta = const VerificationMeta(
    'decimalSeparator',
  );
  @override
  late final GeneratedColumn<String> decimalSeparator = GeneratedColumn<String>(
    'decimal_separator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outflowIsNegativeMeta = const VerificationMeta(
    'outflowIsNegative',
  );
  @override
  late final GeneratedColumn<bool> outflowIsNegative = GeneratedColumn<bool>(
    'outflow_is_negative',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("outflow_is_negative" IN (0, 1))',
    ),
  );
  static const VerificationMeta _dateColumnMeta = const VerificationMeta(
    'dateColumn',
  );
  @override
  late final GeneratedColumn<String> dateColumn = GeneratedColumn<String>(
    'date_column',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountColumnMeta = const VerificationMeta(
    'amountColumn',
  );
  @override
  late final GeneratedColumn<String> amountColumn = GeneratedColumn<String>(
    'amount_column',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payeeColumnMeta = const VerificationMeta(
    'payeeColumn',
  );
  @override
  late final GeneratedColumn<String> payeeColumn = GeneratedColumn<String>(
    'payee_column',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoColumnMeta = const VerificationMeta(
    'memoColumn',
  );
  @override
  late final GeneratedColumn<String> memoColumn = GeneratedColumn<String>(
    'memo_column',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryColumnMeta = const VerificationMeta(
    'categoryColumn',
  );
  @override
  late final GeneratedColumn<String> categoryColumn = GeneratedColumn<String>(
    'category_column',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    dateFormat,
    decimalSeparator,
    outflowIsNegative,
    dateColumn,
    amountColumn,
    payeeColumn,
    memoColumn,
    categoryColumn,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('date_format')) {
      context.handle(
        _dateFormatMeta,
        dateFormat.isAcceptableOrUnknown(data['date_format']!, _dateFormatMeta),
      );
    } else if (isInserting) {
      context.missing(_dateFormatMeta);
    }
    if (data.containsKey('decimal_separator')) {
      context.handle(
        _decimalSeparatorMeta,
        decimalSeparator.isAcceptableOrUnknown(
          data['decimal_separator']!,
          _decimalSeparatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decimalSeparatorMeta);
    }
    if (data.containsKey('outflow_is_negative')) {
      context.handle(
        _outflowIsNegativeMeta,
        outflowIsNegative.isAcceptableOrUnknown(
          data['outflow_is_negative']!,
          _outflowIsNegativeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outflowIsNegativeMeta);
    }
    if (data.containsKey('date_column')) {
      context.handle(
        _dateColumnMeta,
        dateColumn.isAcceptableOrUnknown(data['date_column']!, _dateColumnMeta),
      );
    }
    if (data.containsKey('amount_column')) {
      context.handle(
        _amountColumnMeta,
        amountColumn.isAcceptableOrUnknown(
          data['amount_column']!,
          _amountColumnMeta,
        ),
      );
    }
    if (data.containsKey('payee_column')) {
      context.handle(
        _payeeColumnMeta,
        payeeColumn.isAcceptableOrUnknown(
          data['payee_column']!,
          _payeeColumnMeta,
        ),
      );
    }
    if (data.containsKey('memo_column')) {
      context.handle(
        _memoColumnMeta,
        memoColumn.isAcceptableOrUnknown(data['memo_column']!, _memoColumnMeta),
      );
    }
    if (data.containsKey('category_column')) {
      context.handle(
        _categoryColumnMeta,
        categoryColumn.isAcceptableOrUnknown(
          data['category_column']!,
          _categoryColumnMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dateFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_format'],
      )!,
      decimalSeparator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decimal_separator'],
      )!,
      outflowIsNegative: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}outflow_is_negative'],
      )!,
      dateColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_column'],
      ),
      amountColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_column'],
      ),
      payeeColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_column'],
      ),
      memoColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_column'],
      ),
      categoryColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_column'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ImportProfilesTable createAlias(String alias) {
    return $ImportProfilesTable(attachedDatabase, alias);
  }
}

class ImportProfile extends DataClass implements Insertable<ImportProfile> {
  final String id;
  final String name;
  final String dateFormat;
  final String decimalSeparator;
  final bool outflowIsNegative;
  final String? dateColumn;
  final String? amountColumn;
  final String? payeeColumn;
  final String? memoColumn;
  final String? categoryColumn;
  final String createdAt;
  final DateTime? updatedAt;
  const ImportProfile({
    required this.id,
    required this.name,
    required this.dateFormat,
    required this.decimalSeparator,
    required this.outflowIsNegative,
    this.dateColumn,
    this.amountColumn,
    this.payeeColumn,
    this.memoColumn,
    this.categoryColumn,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['date_format'] = Variable<String>(dateFormat);
    map['decimal_separator'] = Variable<String>(decimalSeparator);
    map['outflow_is_negative'] = Variable<bool>(outflowIsNegative);
    if (!nullToAbsent || dateColumn != null) {
      map['date_column'] = Variable<String>(dateColumn);
    }
    if (!nullToAbsent || amountColumn != null) {
      map['amount_column'] = Variable<String>(amountColumn);
    }
    if (!nullToAbsent || payeeColumn != null) {
      map['payee_column'] = Variable<String>(payeeColumn);
    }
    if (!nullToAbsent || memoColumn != null) {
      map['memo_column'] = Variable<String>(memoColumn);
    }
    if (!nullToAbsent || categoryColumn != null) {
      map['category_column'] = Variable<String>(categoryColumn);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ImportProfilesCompanion toCompanion(bool nullToAbsent) {
    return ImportProfilesCompanion(
      id: Value(id),
      name: Value(name),
      dateFormat: Value(dateFormat),
      decimalSeparator: Value(decimalSeparator),
      outflowIsNegative: Value(outflowIsNegative),
      dateColumn: dateColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(dateColumn),
      amountColumn: amountColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(amountColumn),
      payeeColumn: payeeColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeColumn),
      memoColumn: memoColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(memoColumn),
      categoryColumn: categoryColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryColumn),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ImportProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      dateFormat: serializer.fromJson<String>(json['dateFormat']),
      decimalSeparator: serializer.fromJson<String>(json['decimalSeparator']),
      outflowIsNegative: serializer.fromJson<bool>(json['outflowIsNegative']),
      dateColumn: serializer.fromJson<String?>(json['dateColumn']),
      amountColumn: serializer.fromJson<String?>(json['amountColumn']),
      payeeColumn: serializer.fromJson<String?>(json['payeeColumn']),
      memoColumn: serializer.fromJson<String?>(json['memoColumn']),
      categoryColumn: serializer.fromJson<String?>(json['categoryColumn']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'dateFormat': serializer.toJson<String>(dateFormat),
      'decimalSeparator': serializer.toJson<String>(decimalSeparator),
      'outflowIsNegative': serializer.toJson<bool>(outflowIsNegative),
      'dateColumn': serializer.toJson<String?>(dateColumn),
      'amountColumn': serializer.toJson<String?>(amountColumn),
      'payeeColumn': serializer.toJson<String?>(payeeColumn),
      'memoColumn': serializer.toJson<String?>(memoColumn),
      'categoryColumn': serializer.toJson<String?>(categoryColumn),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ImportProfile copyWith({
    String? id,
    String? name,
    String? dateFormat,
    String? decimalSeparator,
    bool? outflowIsNegative,
    Value<String?> dateColumn = const Value.absent(),
    Value<String?> amountColumn = const Value.absent(),
    Value<String?> payeeColumn = const Value.absent(),
    Value<String?> memoColumn = const Value.absent(),
    Value<String?> categoryColumn = const Value.absent(),
    String? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => ImportProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    dateFormat: dateFormat ?? this.dateFormat,
    decimalSeparator: decimalSeparator ?? this.decimalSeparator,
    outflowIsNegative: outflowIsNegative ?? this.outflowIsNegative,
    dateColumn: dateColumn.present ? dateColumn.value : this.dateColumn,
    amountColumn: amountColumn.present ? amountColumn.value : this.amountColumn,
    payeeColumn: payeeColumn.present ? payeeColumn.value : this.payeeColumn,
    memoColumn: memoColumn.present ? memoColumn.value : this.memoColumn,
    categoryColumn: categoryColumn.present
        ? categoryColumn.value
        : this.categoryColumn,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ImportProfile copyWithCompanion(ImportProfilesCompanion data) {
    return ImportProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      dateFormat: data.dateFormat.present
          ? data.dateFormat.value
          : this.dateFormat,
      decimalSeparator: data.decimalSeparator.present
          ? data.decimalSeparator.value
          : this.decimalSeparator,
      outflowIsNegative: data.outflowIsNegative.present
          ? data.outflowIsNegative.value
          : this.outflowIsNegative,
      dateColumn: data.dateColumn.present
          ? data.dateColumn.value
          : this.dateColumn,
      amountColumn: data.amountColumn.present
          ? data.amountColumn.value
          : this.amountColumn,
      payeeColumn: data.payeeColumn.present
          ? data.payeeColumn.value
          : this.payeeColumn,
      memoColumn: data.memoColumn.present
          ? data.memoColumn.value
          : this.memoColumn,
      categoryColumn: data.categoryColumn.present
          ? data.categoryColumn.value
          : this.categoryColumn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dateFormat: $dateFormat, ')
          ..write('decimalSeparator: $decimalSeparator, ')
          ..write('outflowIsNegative: $outflowIsNegative, ')
          ..write('dateColumn: $dateColumn, ')
          ..write('amountColumn: $amountColumn, ')
          ..write('payeeColumn: $payeeColumn, ')
          ..write('memoColumn: $memoColumn, ')
          ..write('categoryColumn: $categoryColumn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    dateFormat,
    decimalSeparator,
    outflowIsNegative,
    dateColumn,
    amountColumn,
    payeeColumn,
    memoColumn,
    categoryColumn,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.dateFormat == this.dateFormat &&
          other.decimalSeparator == this.decimalSeparator &&
          other.outflowIsNegative == this.outflowIsNegative &&
          other.dateColumn == this.dateColumn &&
          other.amountColumn == this.amountColumn &&
          other.payeeColumn == this.payeeColumn &&
          other.memoColumn == this.memoColumn &&
          other.categoryColumn == this.categoryColumn &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ImportProfilesCompanion extends UpdateCompanion<ImportProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> dateFormat;
  final Value<String> decimalSeparator;
  final Value<bool> outflowIsNegative;
  final Value<String?> dateColumn;
  final Value<String?> amountColumn;
  final Value<String?> payeeColumn;
  final Value<String?> memoColumn;
  final Value<String?> categoryColumn;
  final Value<String> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const ImportProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.dateFormat = const Value.absent(),
    this.decimalSeparator = const Value.absent(),
    this.outflowIsNegative = const Value.absent(),
    this.dateColumn = const Value.absent(),
    this.amountColumn = const Value.absent(),
    this.payeeColumn = const Value.absent(),
    this.memoColumn = const Value.absent(),
    this.categoryColumn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportProfilesCompanion.insert({
    required String id,
    required String name,
    required String dateFormat,
    required String decimalSeparator,
    required bool outflowIsNegative,
    this.dateColumn = const Value.absent(),
    this.amountColumn = const Value.absent(),
    this.payeeColumn = const Value.absent(),
    this.memoColumn = const Value.absent(),
    this.categoryColumn = const Value.absent(),
    required String createdAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       dateFormat = Value(dateFormat),
       decimalSeparator = Value(decimalSeparator),
       outflowIsNegative = Value(outflowIsNegative),
       createdAt = Value(createdAt);
  static Insertable<ImportProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? dateFormat,
    Expression<String>? decimalSeparator,
    Expression<bool>? outflowIsNegative,
    Expression<String>? dateColumn,
    Expression<String>? amountColumn,
    Expression<String>? payeeColumn,
    Expression<String>? memoColumn,
    Expression<String>? categoryColumn,
    Expression<String>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (dateFormat != null) 'date_format': dateFormat,
      if (decimalSeparator != null) 'decimal_separator': decimalSeparator,
      if (outflowIsNegative != null) 'outflow_is_negative': outflowIsNegative,
      if (dateColumn != null) 'date_column': dateColumn,
      if (amountColumn != null) 'amount_column': amountColumn,
      if (payeeColumn != null) 'payee_column': payeeColumn,
      if (memoColumn != null) 'memo_column': memoColumn,
      if (categoryColumn != null) 'category_column': categoryColumn,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? dateFormat,
    Value<String>? decimalSeparator,
    Value<bool>? outflowIsNegative,
    Value<String?>? dateColumn,
    Value<String?>? amountColumn,
    Value<String?>? payeeColumn,
    Value<String?>? memoColumn,
    Value<String?>? categoryColumn,
    Value<String>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ImportProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      dateFormat: dateFormat ?? this.dateFormat,
      decimalSeparator: decimalSeparator ?? this.decimalSeparator,
      outflowIsNegative: outflowIsNegative ?? this.outflowIsNegative,
      dateColumn: dateColumn ?? this.dateColumn,
      amountColumn: amountColumn ?? this.amountColumn,
      payeeColumn: payeeColumn ?? this.payeeColumn,
      memoColumn: memoColumn ?? this.memoColumn,
      categoryColumn: categoryColumn ?? this.categoryColumn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dateFormat.present) {
      map['date_format'] = Variable<String>(dateFormat.value);
    }
    if (decimalSeparator.present) {
      map['decimal_separator'] = Variable<String>(decimalSeparator.value);
    }
    if (outflowIsNegative.present) {
      map['outflow_is_negative'] = Variable<bool>(outflowIsNegative.value);
    }
    if (dateColumn.present) {
      map['date_column'] = Variable<String>(dateColumn.value);
    }
    if (amountColumn.present) {
      map['amount_column'] = Variable<String>(amountColumn.value);
    }
    if (payeeColumn.present) {
      map['payee_column'] = Variable<String>(payeeColumn.value);
    }
    if (memoColumn.present) {
      map['memo_column'] = Variable<String>(memoColumn.value);
    }
    if (categoryColumn.present) {
      map['category_column'] = Variable<String>(categoryColumn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dateFormat: $dateFormat, ')
          ..write('decimalSeparator: $decimalSeparator, ')
          ..write('outflowIsNegative: $outflowIsNegative, ')
          ..write('dateColumn: $dateColumn, ')
          ..write('amountColumn: $amountColumn, ')
          ..write('payeeColumn: $payeeColumn, ')
          ..write('memoColumn: $memoColumn, ')
          ..write('categoryColumn: $categoryColumn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RulesTable extends Rules with TableInfo<$RulesTable, Rule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleMatchLogic, String>
  matchLogic = GeneratedColumn<String>(
    'match_logic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RuleMatchLogic>($RulesTable.$convertermatchLogic);
  @override
  late final GeneratedColumnWithTypeConverter<List<RuleCondition>, String>
  conditions = GeneratedColumn<String>(
    'conditions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<RuleCondition>>($RulesTable.$converterconditions);
  @override
  late final GeneratedColumnWithTypeConverter<List<RuleAction>, String>
  actions = GeneratedColumn<String>(
    'actions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<RuleAction>>($RulesTable.$converteractions);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    priority,
    isActive,
    matchLogic,
    conditions,
    actions,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      matchLogic: $RulesTable.$convertermatchLogic.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}match_logic'],
        )!,
      ),
      conditions: $RulesTable.$converterconditions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}conditions'],
        )!,
      ),
      actions: $RulesTable.$converteractions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}actions'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RulesTable createAlias(String alias) {
    return $RulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RuleMatchLogic, String, String>
  $convertermatchLogic = const EnumNameConverter<RuleMatchLogic>(
    RuleMatchLogic.values,
  );
  static TypeConverter<List<RuleCondition>, String> $converterconditions =
      const RuleConditionListConverter();
  static TypeConverter<List<RuleAction>, String> $converteractions =
      const RuleActionListConverter();
}

class Rule extends DataClass implements Insertable<Rule> {
  final String id;
  final String name;
  final String? description;
  final int priority;
  final bool isActive;
  final RuleMatchLogic matchLogic;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;
  final String createdAt;
  final String updatedAt;
  const Rule({
    required this.id,
    required this.name,
    this.description,
    required this.priority,
    required this.isActive,
    required this.matchLogic,
    required this.conditions,
    required this.actions,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['priority'] = Variable<int>(priority);
    map['is_active'] = Variable<bool>(isActive);
    {
      map['match_logic'] = Variable<String>(
        $RulesTable.$convertermatchLogic.toSql(matchLogic),
      );
    }
    {
      map['conditions'] = Variable<String>(
        $RulesTable.$converterconditions.toSql(conditions),
      );
    }
    {
      map['actions'] = Variable<String>(
        $RulesTable.$converteractions.toSql(actions),
      );
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  RulesCompanion toCompanion(bool nullToAbsent) {
    return RulesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      priority: Value(priority),
      isActive: Value(isActive),
      matchLogic: Value(matchLogic),
      conditions: Value(conditions),
      actions: Value(actions),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Rule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rule(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      priority: serializer.fromJson<int>(json['priority']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      matchLogic: $RulesTable.$convertermatchLogic.fromJson(
        serializer.fromJson<String>(json['matchLogic']),
      ),
      conditions: serializer.fromJson<List<RuleCondition>>(json['conditions']),
      actions: serializer.fromJson<List<RuleAction>>(json['actions']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'priority': serializer.toJson<int>(priority),
      'isActive': serializer.toJson<bool>(isActive),
      'matchLogic': serializer.toJson<String>(
        $RulesTable.$convertermatchLogic.toJson(matchLogic),
      ),
      'conditions': serializer.toJson<List<RuleCondition>>(conditions),
      'actions': serializer.toJson<List<RuleAction>>(actions),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Rule copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? priority,
    bool? isActive,
    RuleMatchLogic? matchLogic,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
    String? createdAt,
    String? updatedAt,
  }) => Rule(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    priority: priority ?? this.priority,
    isActive: isActive ?? this.isActive,
    matchLogic: matchLogic ?? this.matchLogic,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Rule copyWithCompanion(RulesCompanion data) {
    return Rule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      priority: data.priority.present ? data.priority.value : this.priority,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      matchLogic: data.matchLogic.present
          ? data.matchLogic.value
          : this.matchLogic,
      conditions: data.conditions.present
          ? data.conditions.value
          : this.conditions,
      actions: data.actions.present ? data.actions.value : this.actions,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('matchLogic: $matchLogic, ')
          ..write('conditions: $conditions, ')
          ..write('actions: $actions, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    priority,
    isActive,
    matchLogic,
    conditions,
    actions,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rule &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.isActive == this.isActive &&
          other.matchLogic == this.matchLogic &&
          other.conditions == this.conditions &&
          other.actions == this.actions &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RulesCompanion extends UpdateCompanion<Rule> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> priority;
  final Value<bool> isActive;
  final Value<RuleMatchLogic> matchLogic;
  final Value<List<RuleCondition>> conditions;
  final Value<List<RuleAction>> actions;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const RulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.isActive = const Value.absent(),
    this.matchLogic = const Value.absent(),
    this.conditions = const Value.absent(),
    this.actions = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RulesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required int priority,
    this.isActive = const Value.absent(),
    required RuleMatchLogic matchLogic,
    required List<RuleCondition> conditions,
    required List<RuleAction> actions,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       priority = Value(priority),
       matchLogic = Value(matchLogic),
       conditions = Value(conditions),
       actions = Value(actions),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Rule> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<bool>? isActive,
    Expression<String>? matchLogic,
    Expression<String>? conditions,
    Expression<String>? actions,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (isActive != null) 'is_active': isActive,
      if (matchLogic != null) 'match_logic': matchLogic,
      if (conditions != null) 'conditions': conditions,
      if (actions != null) 'actions': actions,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RulesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? priority,
    Value<bool>? isActive,
    Value<RuleMatchLogic>? matchLogic,
    Value<List<RuleCondition>>? conditions,
    Value<List<RuleAction>>? actions,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return RulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      matchLogic: matchLogic ?? this.matchLogic,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (matchLogic.present) {
      map['match_logic'] = Variable<String>(
        $RulesTable.$convertermatchLogic.toSql(matchLogic.value),
      );
    }
    if (conditions.present) {
      map['conditions'] = Variable<String>(
        $RulesTable.$converterconditions.toSql(conditions.value),
      );
    }
    if (actions.present) {
      map['actions'] = Variable<String>(
        $RulesTable.$converteractions.toSql(actions.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('matchLogic: $matchLogic, ')
          ..write('conditions: $conditions, ')
          ..write('actions: $actions, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncDeviceProgressTable extends SyncDeviceProgress
    with TableInfo<$SyncDeviceProgressTable, SyncDeviceProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncDeviceProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSequenceMeta = const VerificationMeta(
    'lastSequence',
  );
  @override
  late final GeneratedColumn<int> lastSequence = GeneratedColumn<int>(
    'last_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, lastSequence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_device_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncDeviceProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('last_sequence')) {
      context.handle(
        _lastSequenceMeta,
        lastSequence.isAcceptableOrUnknown(
          data['last_sequence']!,
          _lastSequenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  SyncDeviceProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDeviceProgressData(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      lastSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sequence'],
      )!,
    );
  }

  @override
  $SyncDeviceProgressTable createAlias(String alias) {
    return $SyncDeviceProgressTable(attachedDatabase, alias);
  }
}

class SyncDeviceProgressData extends DataClass
    implements Insertable<SyncDeviceProgressData> {
  final String deviceId;
  final int lastSequence;
  const SyncDeviceProgressData({
    required this.deviceId,
    required this.lastSequence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['last_sequence'] = Variable<int>(lastSequence);
    return map;
  }

  SyncDeviceProgressCompanion toCompanion(bool nullToAbsent) {
    return SyncDeviceProgressCompanion(
      deviceId: Value(deviceId),
      lastSequence: Value(lastSequence),
    );
  }

  factory SyncDeviceProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncDeviceProgressData(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      lastSequence: serializer.fromJson<int>(json['lastSequence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'lastSequence': serializer.toJson<int>(lastSequence),
    };
  }

  SyncDeviceProgressData copyWith({String? deviceId, int? lastSequence}) =>
      SyncDeviceProgressData(
        deviceId: deviceId ?? this.deviceId,
        lastSequence: lastSequence ?? this.lastSequence,
      );
  SyncDeviceProgressData copyWithCompanion(SyncDeviceProgressCompanion data) {
    return SyncDeviceProgressData(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      lastSequence: data.lastSequence.present
          ? data.lastSequence.value
          : this.lastSequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeviceProgressData(')
          ..write('deviceId: $deviceId, ')
          ..write('lastSequence: $lastSequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, lastSequence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncDeviceProgressData &&
          other.deviceId == this.deviceId &&
          other.lastSequence == this.lastSequence);
}

class SyncDeviceProgressCompanion
    extends UpdateCompanion<SyncDeviceProgressData> {
  final Value<String> deviceId;
  final Value<int> lastSequence;
  final Value<int> rowid;
  const SyncDeviceProgressCompanion({
    this.deviceId = const Value.absent(),
    this.lastSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncDeviceProgressCompanion.insert({
    required String deviceId,
    this.lastSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<SyncDeviceProgressData> custom({
    Expression<String>? deviceId,
    Expression<int>? lastSequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (lastSequence != null) 'last_sequence': lastSequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncDeviceProgressCompanion copyWith({
    Value<String>? deviceId,
    Value<int>? lastSequence,
    Value<int>? rowid,
  }) {
    return SyncDeviceProgressCompanion(
      deviceId: deviceId ?? this.deviceId,
      lastSequence: lastSequence ?? this.lastSequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (lastSequence.present) {
      map['last_sequence'] = Variable<int>(lastSequence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeviceProgressCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncKvTable extends SyncKv with TableInfo<$SyncKvTable, SyncKvData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncKvData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncKvData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncKvData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncKvTable createAlias(String alias) {
    return $SyncKvTable(attachedDatabase, alias);
  }
}

class SyncKvData extends DataClass implements Insertable<SyncKvData> {
  final String key;
  final String value;
  const SyncKvData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncKvCompanion toCompanion(bool nullToAbsent) {
    return SyncKvCompanion(key: Value(key), value: Value(value));
  }

  factory SyncKvData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncKvData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncKvData copyWith({String? key, String? value}) =>
      SyncKvData(key: key ?? this.key, value: value ?? this.value);
  SyncKvData copyWithCompanion(SyncKvCompanion data) {
    return SyncKvData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncKvData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncKvCompanion extends UpdateCompanion<SyncKvData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncKvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncKvData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncKvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncKvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRowVersionsTable extends SyncRowVersions
    with TableInfo<$SyncRowVersionsTable, SyncRowVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRowVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncTableMeta = const VerificationMeta(
    'syncTable',
  );
  @override
  late final GeneratedColumn<String> syncTable = GeneratedColumn<String>(
    'sync_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncTable,
    rowId,
    version,
    deviceId,
    deleted,
    sequence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_row_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRowVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_table')) {
      context.handle(
        _syncTableMeta,
        syncTable.isAcceptableOrUnknown(data['sync_table']!, _syncTableMeta),
      );
    } else if (isInserting) {
      context.missing(_syncTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncTable, rowId};
  @override
  SyncRowVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRowVersion(
      syncTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      ),
    );
  }

  @override
  $SyncRowVersionsTable createAlias(String alias) {
    return $SyncRowVersionsTable(attachedDatabase, alias);
  }
}

class SyncRowVersion extends DataClass implements Insertable<SyncRowVersion> {
  final String syncTable;
  final String rowId;
  final int version;
  final String deviceId;
  final bool deleted;

  /// For versions written on this device: the sequence of the change file
  /// that carried it. Used to tell concurrent from sequential edits.
  final int? sequence;
  const SyncRowVersion({
    required this.syncTable,
    required this.rowId,
    required this.version,
    required this.deviceId,
    required this.deleted,
    this.sequence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_table'] = Variable<String>(syncTable);
    map['row_id'] = Variable<String>(rowId);
    map['version'] = Variable<int>(version);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<int>(sequence);
    }
    return map;
  }

  SyncRowVersionsCompanion toCompanion(bool nullToAbsent) {
    return SyncRowVersionsCompanion(
      syncTable: Value(syncTable),
      rowId: Value(rowId),
      version: Value(version),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
    );
  }

  factory SyncRowVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRowVersion(
      syncTable: serializer.fromJson<String>(json['syncTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      version: serializer.fromJson<int>(json['version']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      sequence: serializer.fromJson<int?>(json['sequence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncTable': serializer.toJson<String>(syncTable),
      'rowId': serializer.toJson<String>(rowId),
      'version': serializer.toJson<int>(version),
      'deviceId': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<bool>(deleted),
      'sequence': serializer.toJson<int?>(sequence),
    };
  }

  SyncRowVersion copyWith({
    String? syncTable,
    String? rowId,
    int? version,
    String? deviceId,
    bool? deleted,
    Value<int?> sequence = const Value.absent(),
  }) => SyncRowVersion(
    syncTable: syncTable ?? this.syncTable,
    rowId: rowId ?? this.rowId,
    version: version ?? this.version,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    sequence: sequence.present ? sequence.value : this.sequence,
  );
  SyncRowVersion copyWithCompanion(SyncRowVersionsCompanion data) {
    return SyncRowVersion(
      syncTable: data.syncTable.present ? data.syncTable.value : this.syncTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      version: data.version.present ? data.version.value : this.version,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRowVersion(')
          ..write('syncTable: $syncTable, ')
          ..write('rowId: $rowId, ')
          ..write('version: $version, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('sequence: $sequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncTable, rowId, version, deviceId, deleted, sequence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRowVersion &&
          other.syncTable == this.syncTable &&
          other.rowId == this.rowId &&
          other.version == this.version &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.sequence == this.sequence);
}

class SyncRowVersionsCompanion extends UpdateCompanion<SyncRowVersion> {
  final Value<String> syncTable;
  final Value<String> rowId;
  final Value<int> version;
  final Value<String> deviceId;
  final Value<bool> deleted;
  final Value<int?> sequence;
  final Value<int> rowid;
  const SyncRowVersionsCompanion({
    this.syncTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.version = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.sequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRowVersionsCompanion.insert({
    required String syncTable,
    required String rowId,
    required int version,
    required String deviceId,
    this.deleted = const Value.absent(),
    this.sequence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncTable = Value(syncTable),
       rowId = Value(rowId),
       version = Value(version),
       deviceId = Value(deviceId);
  static Insertable<SyncRowVersion> custom({
    Expression<String>? syncTable,
    Expression<String>? rowId,
    Expression<int>? version,
    Expression<String>? deviceId,
    Expression<bool>? deleted,
    Expression<int>? sequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncTable != null) 'sync_table': syncTable,
      if (rowId != null) 'row_id': rowId,
      if (version != null) 'version': version,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (sequence != null) 'sequence': sequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRowVersionsCompanion copyWith({
    Value<String>? syncTable,
    Value<String>? rowId,
    Value<int>? version,
    Value<String>? deviceId,
    Value<bool>? deleted,
    Value<int?>? sequence,
    Value<int>? rowid,
  }) {
    return SyncRowVersionsCompanion(
      syncTable: syncTable ?? this.syncTable,
      rowId: rowId ?? this.rowId,
      version: version ?? this.version,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      sequence: sequence ?? this.sequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncTable.present) {
      map['sync_table'] = Variable<String>(syncTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRowVersionsCompanion(')
          ..write('syncTable: $syncTable, ')
          ..write('rowId: $rowId, ')
          ..write('version: $version, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('sequence: $sequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _syncTableMeta = const VerificationMeta(
    'syncTable',
  );
  @override
  late final GeneratedColumn<String> syncTable = GeneratedColumn<String>(
    'sync_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localSnapshotMeta = const VerificationMeta(
    'localSnapshot',
  );
  @override
  late final GeneratedColumn<String> localSnapshot = GeneratedColumn<String>(
    'local_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteSnapshotMeta = const VerificationMeta(
    'remoteSnapshot',
  );
  @override
  late final GeneratedColumn<String> remoteSnapshot = GeneratedColumn<String>(
    'remote_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteDeviceIdMeta = const VerificationMeta(
    'remoteDeviceId',
  );
  @override
  late final GeneratedColumn<String> remoteDeviceId = GeneratedColumn<String>(
    'remote_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    syncTable,
    rowId,
    localSnapshot,
    remoteSnapshot,
    remoteDeviceId,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sync_table')) {
      context.handle(
        _syncTableMeta,
        syncTable.isAcceptableOrUnknown(data['sync_table']!, _syncTableMeta),
      );
    } else if (isInserting) {
      context.missing(_syncTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('local_snapshot')) {
      context.handle(
        _localSnapshotMeta,
        localSnapshot.isAcceptableOrUnknown(
          data['local_snapshot']!,
          _localSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('remote_snapshot')) {
      context.handle(
        _remoteSnapshotMeta,
        remoteSnapshot.isAcceptableOrUnknown(
          data['remote_snapshot']!,
          _remoteSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('remote_device_id')) {
      context.handle(
        _remoteDeviceIdMeta,
        remoteDeviceId.isAcceptableOrUnknown(
          data['remote_device_id']!,
          _remoteDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteDeviceIdMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_resolvedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      syncTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      localSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_snapshot'],
      ),
      remoteSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_snapshot'],
      ),
      remoteDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_device_id'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      )!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final int id;
  final String syncTable;
  final String rowId;

  /// JSON of the local row that was overwritten; null if it was a delete.
  final String? localSnapshot;

  /// JSON of the winning remote row; null if the remote change was a delete.
  final String? remoteSnapshot;
  final String remoteDeviceId;
  final DateTime resolvedAt;
  const SyncConflict({
    required this.id,
    required this.syncTable,
    required this.rowId,
    this.localSnapshot,
    this.remoteSnapshot,
    required this.remoteDeviceId,
    required this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sync_table'] = Variable<String>(syncTable);
    map['row_id'] = Variable<String>(rowId);
    if (!nullToAbsent || localSnapshot != null) {
      map['local_snapshot'] = Variable<String>(localSnapshot);
    }
    if (!nullToAbsent || remoteSnapshot != null) {
      map['remote_snapshot'] = Variable<String>(remoteSnapshot);
    }
    map['remote_device_id'] = Variable<String>(remoteDeviceId);
    map['resolved_at'] = Variable<DateTime>(resolvedAt);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      syncTable: Value(syncTable),
      rowId: Value(rowId),
      localSnapshot: localSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(localSnapshot),
      remoteSnapshot: remoteSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteSnapshot),
      remoteDeviceId: Value(remoteDeviceId),
      resolvedAt: Value(resolvedAt),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<int>(json['id']),
      syncTable: serializer.fromJson<String>(json['syncTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      localSnapshot: serializer.fromJson<String?>(json['localSnapshot']),
      remoteSnapshot: serializer.fromJson<String?>(json['remoteSnapshot']),
      remoteDeviceId: serializer.fromJson<String>(json['remoteDeviceId']),
      resolvedAt: serializer.fromJson<DateTime>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'syncTable': serializer.toJson<String>(syncTable),
      'rowId': serializer.toJson<String>(rowId),
      'localSnapshot': serializer.toJson<String?>(localSnapshot),
      'remoteSnapshot': serializer.toJson<String?>(remoteSnapshot),
      'remoteDeviceId': serializer.toJson<String>(remoteDeviceId),
      'resolvedAt': serializer.toJson<DateTime>(resolvedAt),
    };
  }

  SyncConflict copyWith({
    int? id,
    String? syncTable,
    String? rowId,
    Value<String?> localSnapshot = const Value.absent(),
    Value<String?> remoteSnapshot = const Value.absent(),
    String? remoteDeviceId,
    DateTime? resolvedAt,
  }) => SyncConflict(
    id: id ?? this.id,
    syncTable: syncTable ?? this.syncTable,
    rowId: rowId ?? this.rowId,
    localSnapshot: localSnapshot.present
        ? localSnapshot.value
        : this.localSnapshot,
    remoteSnapshot: remoteSnapshot.present
        ? remoteSnapshot.value
        : this.remoteSnapshot,
    remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      syncTable: data.syncTable.present ? data.syncTable.value : this.syncTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      localSnapshot: data.localSnapshot.present
          ? data.localSnapshot.value
          : this.localSnapshot,
      remoteSnapshot: data.remoteSnapshot.present
          ? data.remoteSnapshot.value
          : this.remoteSnapshot,
      remoteDeviceId: data.remoteDeviceId.present
          ? data.remoteDeviceId.value
          : this.remoteDeviceId,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('syncTable: $syncTable, ')
          ..write('rowId: $rowId, ')
          ..write('localSnapshot: $localSnapshot, ')
          ..write('remoteSnapshot: $remoteSnapshot, ')
          ..write('remoteDeviceId: $remoteDeviceId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    syncTable,
    rowId,
    localSnapshot,
    remoteSnapshot,
    remoteDeviceId,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.syncTable == this.syncTable &&
          other.rowId == this.rowId &&
          other.localSnapshot == this.localSnapshot &&
          other.remoteSnapshot == this.remoteSnapshot &&
          other.remoteDeviceId == this.remoteDeviceId &&
          other.resolvedAt == this.resolvedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<int> id;
  final Value<String> syncTable;
  final Value<String> rowId;
  final Value<String?> localSnapshot;
  final Value<String?> remoteSnapshot;
  final Value<String> remoteDeviceId;
  final Value<DateTime> resolvedAt;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.syncTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.localSnapshot = const Value.absent(),
    this.remoteSnapshot = const Value.absent(),
    this.remoteDeviceId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String syncTable,
    required String rowId,
    this.localSnapshot = const Value.absent(),
    this.remoteSnapshot = const Value.absent(),
    required String remoteDeviceId,
    required DateTime resolvedAt,
  }) : syncTable = Value(syncTable),
       rowId = Value(rowId),
       remoteDeviceId = Value(remoteDeviceId),
       resolvedAt = Value(resolvedAt);
  static Insertable<SyncConflict> custom({
    Expression<int>? id,
    Expression<String>? syncTable,
    Expression<String>? rowId,
    Expression<String>? localSnapshot,
    Expression<String>? remoteSnapshot,
    Expression<String>? remoteDeviceId,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (syncTable != null) 'sync_table': syncTable,
      if (rowId != null) 'row_id': rowId,
      if (localSnapshot != null) 'local_snapshot': localSnapshot,
      if (remoteSnapshot != null) 'remote_snapshot': remoteSnapshot,
      if (remoteDeviceId != null) 'remote_device_id': remoteDeviceId,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? syncTable,
    Value<String>? rowId,
    Value<String?>? localSnapshot,
    Value<String?>? remoteSnapshot,
    Value<String>? remoteDeviceId,
    Value<DateTime>? resolvedAt,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      syncTable: syncTable ?? this.syncTable,
      rowId: rowId ?? this.rowId,
      localSnapshot: localSnapshot ?? this.localSnapshot,
      remoteSnapshot: remoteSnapshot ?? this.remoteSnapshot,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (syncTable.present) {
      map['sync_table'] = Variable<String>(syncTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (localSnapshot.present) {
      map['local_snapshot'] = Variable<String>(localSnapshot.value);
    }
    if (remoteSnapshot.present) {
      map['remote_snapshot'] = Variable<String>(remoteSnapshot.value);
    }
    if (remoteDeviceId.present) {
      map['remote_device_id'] = Variable<String>(remoteDeviceId.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('syncTable: $syncTable, ')
          ..write('rowId: $rowId, ')
          ..write('localSnapshot: $localSnapshot, ')
          ..write('remoteSnapshot: $remoteSnapshot, ')
          ..write('remoteDeviceId: $remoteDeviceId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncQuarantineTable extends SyncQuarantine
    with TableInfo<$SyncQuarantineTable, SyncQuarantineData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQuarantineTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptMeta = const VerificationMeta(
    'lastAttempt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttempt = GeneratedColumn<DateTime>(
    'last_attempt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptMeta = const VerificationMeta(
    'nextAttempt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttempt = GeneratedColumn<DateTime>(
    'next_attempt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    filename,
    deviceId,
    sequence,
    reason,
    error,
    attempts,
    firstSeen,
    lastAttempt,
    nextAttempt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_quarantine';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQuarantineData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    } else if (isInserting) {
      context.missing(_errorMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
        _lastAttemptMeta,
        lastAttempt.isAcceptableOrUnknown(
          data['last_attempt']!,
          _lastAttemptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAttemptMeta);
    }
    if (data.containsKey('next_attempt')) {
      context.handle(
        _nextAttemptMeta,
        nextAttempt.isAcceptableOrUnknown(
          data['next_attempt']!,
          _nextAttemptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filename};
  @override
  SyncQuarantineData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQuarantineData(
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen'],
      )!,
      lastAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt'],
      )!,
      nextAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt'],
      )!,
    );
  }

  @override
  $SyncQuarantineTable createAlias(String alias) {
    return $SyncQuarantineTable(attachedDatabase, alias);
  }
}

class SyncQuarantineData extends DataClass
    implements Insertable<SyncQuarantineData> {
  final String filename;
  final String deviceId;
  final int sequence;

  /// `failed` (decrypt/parse/apply error) or `newer_schema`.
  final String reason;
  final String error;
  final int attempts;
  final DateTime firstSeen;
  final DateTime lastAttempt;
  final DateTime nextAttempt;
  const SyncQuarantineData({
    required this.filename,
    required this.deviceId,
    required this.sequence,
    required this.reason,
    required this.error,
    required this.attempts,
    required this.firstSeen,
    required this.lastAttempt,
    required this.nextAttempt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filename'] = Variable<String>(filename);
    map['device_id'] = Variable<String>(deviceId);
    map['sequence'] = Variable<int>(sequence);
    map['reason'] = Variable<String>(reason);
    map['error'] = Variable<String>(error);
    map['attempts'] = Variable<int>(attempts);
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_attempt'] = Variable<DateTime>(lastAttempt);
    map['next_attempt'] = Variable<DateTime>(nextAttempt);
    return map;
  }

  SyncQuarantineCompanion toCompanion(bool nullToAbsent) {
    return SyncQuarantineCompanion(
      filename: Value(filename),
      deviceId: Value(deviceId),
      sequence: Value(sequence),
      reason: Value(reason),
      error: Value(error),
      attempts: Value(attempts),
      firstSeen: Value(firstSeen),
      lastAttempt: Value(lastAttempt),
      nextAttempt: Value(nextAttempt),
    );
  }

  factory SyncQuarantineData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQuarantineData(
      filename: serializer.fromJson<String>(json['filename']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      reason: serializer.fromJson<String>(json['reason']),
      error: serializer.fromJson<String>(json['error']),
      attempts: serializer.fromJson<int>(json['attempts']),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastAttempt: serializer.fromJson<DateTime>(json['lastAttempt']),
      nextAttempt: serializer.fromJson<DateTime>(json['nextAttempt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filename': serializer.toJson<String>(filename),
      'deviceId': serializer.toJson<String>(deviceId),
      'sequence': serializer.toJson<int>(sequence),
      'reason': serializer.toJson<String>(reason),
      'error': serializer.toJson<String>(error),
      'attempts': serializer.toJson<int>(attempts),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastAttempt': serializer.toJson<DateTime>(lastAttempt),
      'nextAttempt': serializer.toJson<DateTime>(nextAttempt),
    };
  }

  SyncQuarantineData copyWith({
    String? filename,
    String? deviceId,
    int? sequence,
    String? reason,
    String? error,
    int? attempts,
    DateTime? firstSeen,
    DateTime? lastAttempt,
    DateTime? nextAttempt,
  }) => SyncQuarantineData(
    filename: filename ?? this.filename,
    deviceId: deviceId ?? this.deviceId,
    sequence: sequence ?? this.sequence,
    reason: reason ?? this.reason,
    error: error ?? this.error,
    attempts: attempts ?? this.attempts,
    firstSeen: firstSeen ?? this.firstSeen,
    lastAttempt: lastAttempt ?? this.lastAttempt,
    nextAttempt: nextAttempt ?? this.nextAttempt,
  );
  SyncQuarantineData copyWithCompanion(SyncQuarantineCompanion data) {
    return SyncQuarantineData(
      filename: data.filename.present ? data.filename.value : this.filename,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      reason: data.reason.present ? data.reason.value : this.reason,
      error: data.error.present ? data.error.value : this.error,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastAttempt: data.lastAttempt.present
          ? data.lastAttempt.value
          : this.lastAttempt,
      nextAttempt: data.nextAttempt.present
          ? data.nextAttempt.value
          : this.nextAttempt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQuarantineData(')
          ..write('filename: $filename, ')
          ..write('deviceId: $deviceId, ')
          ..write('sequence: $sequence, ')
          ..write('reason: $reason, ')
          ..write('error: $error, ')
          ..write('attempts: $attempts, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('nextAttempt: $nextAttempt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    filename,
    deviceId,
    sequence,
    reason,
    error,
    attempts,
    firstSeen,
    lastAttempt,
    nextAttempt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQuarantineData &&
          other.filename == this.filename &&
          other.deviceId == this.deviceId &&
          other.sequence == this.sequence &&
          other.reason == this.reason &&
          other.error == this.error &&
          other.attempts == this.attempts &&
          other.firstSeen == this.firstSeen &&
          other.lastAttempt == this.lastAttempt &&
          other.nextAttempt == this.nextAttempt);
}

class SyncQuarantineCompanion extends UpdateCompanion<SyncQuarantineData> {
  final Value<String> filename;
  final Value<String> deviceId;
  final Value<int> sequence;
  final Value<String> reason;
  final Value<String> error;
  final Value<int> attempts;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastAttempt;
  final Value<DateTime> nextAttempt;
  final Value<int> rowid;
  const SyncQuarantineCompanion({
    this.filename = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.reason = const Value.absent(),
    this.error = const Value.absent(),
    this.attempts = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.nextAttempt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQuarantineCompanion.insert({
    required String filename,
    required String deviceId,
    required int sequence,
    required String reason,
    required String error,
    this.attempts = const Value.absent(),
    required DateTime firstSeen,
    required DateTime lastAttempt,
    required DateTime nextAttempt,
    this.rowid = const Value.absent(),
  }) : filename = Value(filename),
       deviceId = Value(deviceId),
       sequence = Value(sequence),
       reason = Value(reason),
       error = Value(error),
       firstSeen = Value(firstSeen),
       lastAttempt = Value(lastAttempt),
       nextAttempt = Value(nextAttempt);
  static Insertable<SyncQuarantineData> custom({
    Expression<String>? filename,
    Expression<String>? deviceId,
    Expression<int>? sequence,
    Expression<String>? reason,
    Expression<String>? error,
    Expression<int>? attempts,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastAttempt,
    Expression<DateTime>? nextAttempt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filename != null) 'filename': filename,
      if (deviceId != null) 'device_id': deviceId,
      if (sequence != null) 'sequence': sequence,
      if (reason != null) 'reason': reason,
      if (error != null) 'error': error,
      if (attempts != null) 'attempts': attempts,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (nextAttempt != null) 'next_attempt': nextAttempt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQuarantineCompanion copyWith({
    Value<String>? filename,
    Value<String>? deviceId,
    Value<int>? sequence,
    Value<String>? reason,
    Value<String>? error,
    Value<int>? attempts,
    Value<DateTime>? firstSeen,
    Value<DateTime>? lastAttempt,
    Value<DateTime>? nextAttempt,
    Value<int>? rowid,
  }) {
    return SyncQuarantineCompanion(
      filename: filename ?? this.filename,
      deviceId: deviceId ?? this.deviceId,
      sequence: sequence ?? this.sequence,
      reason: reason ?? this.reason,
      error: error ?? this.error,
      attempts: attempts ?? this.attempts,
      firstSeen: firstSeen ?? this.firstSeen,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      nextAttempt: nextAttempt ?? this.nextAttempt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt.value);
    }
    if (nextAttempt.present) {
      map['next_attempt'] = Variable<DateTime>(nextAttempt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQuarantineCompanion(')
          ..write('filename: $filename, ')
          ..write('deviceId: $deviceId, ')
          ..write('sequence: $sequence, ')
          ..write('reason: $reason, ')
          ..write('error: $error, ')
          ..write('attempts: $attempts, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('nextAttempt: $nextAttempt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncApplyingTable extends SyncApplying
    with TableInfo<$SyncApplyingTable, SyncApplyingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncApplyingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_applying';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncApplyingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncApplyingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncApplyingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $SyncApplyingTable createAlias(String alias) {
    return $SyncApplyingTable(attachedDatabase, alias);
  }
}

class SyncApplyingData extends DataClass
    implements Insertable<SyncApplyingData> {
  final int id;
  const SyncApplyingData({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    return map;
  }

  SyncApplyingCompanion toCompanion(bool nullToAbsent) {
    return SyncApplyingCompanion(id: Value(id));
  }

  factory SyncApplyingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncApplyingData(id: serializer.fromJson<int>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<int>(id)};
  }

  SyncApplyingData copyWith({int? id}) => SyncApplyingData(id: id ?? this.id);
  SyncApplyingData copyWithCompanion(SyncApplyingCompanion data) {
    return SyncApplyingData(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('SyncApplyingData(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncApplyingData && other.id == this.id);
}

class SyncApplyingCompanion extends UpdateCompanion<SyncApplyingData> {
  final Value<int> id;
  const SyncApplyingCompanion({this.id = const Value.absent()});
  SyncApplyingCompanion.insert({this.id = const Value.absent()});
  static Insertable<SyncApplyingData> custom({Expression<int>? id}) {
    return RawValuesInsertable({if (id != null) 'id': id});
  }

  SyncApplyingCompanion copyWith({Value<int>? id}) {
    return SyncApplyingCompanion(id: id ?? this.id);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncApplyingCompanion(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoryGroupsTable categoryGroups = $CategoryGroupsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $BudgetTemplatesTable budgetTemplates = $BudgetTemplatesTable(
    this,
  );
  late final $PayeesTable payees = $PayeesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $ReportNotesTable reportNotes = $ReportNotesTable(this);
  late final $ScheduledTransactionsTable scheduledTransactions =
      $ScheduledTransactionsTable(this);
  late final $PendingSyncChangesTable pendingSyncChanges =
      $PendingSyncChangesTable(this);
  late final $ParsingHistoryTable parsingHistory = $ParsingHistoryTable(this);
  late final $ImportProfilesTable importProfiles = $ImportProfilesTable(this);
  late final $RulesTable rules = $RulesTable(this);
  late final $SyncDeviceProgressTable syncDeviceProgress =
      $SyncDeviceProgressTable(this);
  late final $SyncKvTable syncKv = $SyncKvTable(this);
  late final $SyncRowVersionsTable syncRowVersions = $SyncRowVersionsTable(
    this,
  );
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $SyncQuarantineTable syncQuarantine = $SyncQuarantineTable(this);
  late final $SyncApplyingTable syncApplying = $SyncApplyingTable(this);
  late final Index idxBudgetsMonth = Index(
    'idx_budgets_month',
    'CREATE INDEX idx_budgets_month ON budgets (month)',
  );
  late final Index idxTransactionsAccount = Index(
    'idx_transactions_account',
    'CREATE INDEX idx_transactions_account ON transactions (account_id)',
  );
  late final Index idxTransactionsDate = Index(
    'idx_transactions_date',
    'CREATE INDEX idx_transactions_date ON transactions (date)',
  );
  late final Index idxTransactionsCategory = Index(
    'idx_transactions_category',
    'CREATE INDEX idx_transactions_category ON transactions (category_id)',
  );
  late final Index idxTransactionsPayee = Index(
    'idx_transactions_payee',
    'CREATE INDEX idx_transactions_payee ON transactions (payee_id)',
  );
  late final Index idxPayeesName = Index(
    'idx_payees_name',
    'CREATE INDEX idx_payees_name ON payees (name)',
  );
  late final Index idxPayeesIsFavorite = Index(
    'idx_payees_is_favorite',
    'CREATE INDEX idx_payees_is_favorite ON payees (is_favorite)',
  );
  late final Index idxPendingSyncRecord = Index(
    'idx_pending_sync_record',
    'CREATE INDEX idx_pending_sync_record ON pending_sync_changes (table_name, record_id)',
  );
  late final Index idxSyncRowVersionsDeleted = Index(
    'idx_sync_row_versions_deleted',
    'CREATE INDEX idx_sync_row_versions_deleted ON sync_row_versions (deleted, version)',
  );
  late final AccountsDao accountsDao = AccountsDao(this as AppDatabase);
  late final BudgetsDao budgetsDao = BudgetsDao(this as AppDatabase);
  late final BudgetTemplatesDao budgetTemplatesDao = BudgetTemplatesDao(
    this as AppDatabase,
  );
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final PayeesDao payeesDao = PayeesDao(this as AppDatabase);
  late final ReportNotesDao reportNotesDao = ReportNotesDao(
    this as AppDatabase,
  );
  late final ScheduledTransactionsDao scheduledTransactionsDao =
      ScheduledTransactionsDao(this as AppDatabase);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  late final TransactionsDao transactionsDao = TransactionsDao(
    this as AppDatabase,
  );
  late final PendingSyncChangesDao pendingSyncChangesDao =
      PendingSyncChangesDao(this as AppDatabase);
  late final ParsingHistoryDao parsingHistoryDao = ParsingHistoryDao(
    this as AppDatabase,
  );
  late final ImportProfilesDao importProfilesDao = ImportProfilesDao(
    this as AppDatabase,
  );
  late final RulesDao rulesDao = RulesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categoryGroups,
    categories,
    budgets,
    budgetTemplates,
    payees,
    transactions,
    reportNotes,
    scheduledTransactions,
    pendingSyncChanges,
    parsingHistory,
    importProfiles,
    rules,
    syncDeviceProgress,
    syncKv,
    syncRowVersions,
    syncConflicts,
    syncQuarantine,
    syncApplying,
    idxBudgetsMonth,
    idxTransactionsAccount,
    idxTransactionsDate,
    idxTransactionsCategory,
    idxTransactionsPayee,
    idxPayeesName,
    idxPayeesIsFavorite,
    idxPendingSyncRecord,
    idxSyncRowVersionsDeleted,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String> currency,
      Value<int> startingBalance,
      Value<bool> isClosed,
      Value<bool> onBudget,
      Value<int?> color,
      Value<String?> icon,
      Value<String?> notes,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> currency,
      Value<int> startingBalance,
      Value<bool> isClosed,
      Value<bool> onBudget,
      Value<int?> color,
      Value<String?> icon,
      Value<String?> notes,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PayeesTable, List<Payee>> _payeesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payees,
    aliasName: 'accounts__id__payees__default_account_id',
  );

  $$PayeesTableProcessedTableManager get payeesRefs {
    final manager = $$PayeesTableTableManager($_db, $_db.payees).filter(
      (f) => f.defaultAccountId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_payeesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _accountTransactionsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__account_id',
  );

  $$TransactionsTableProcessedTableManager get accountTransactions {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _accountTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transferTransactionsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__transfer_account_id',
  );

  $$TransactionsTableProcessedTableManager get transferTransactions {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter(
          (f) => f.transferAccountId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _transferTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledTransactionsTable,
    List<ScheduledTransaction>
  >
  _scheduledTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTransactions,
        aliasName: 'accounts__id__scheduled_transactions__account_id',
      );

  $$ScheduledTransactionsTableProcessedTableManager
  get scheduledTransactionsRefs {
    final manager = $$ScheduledTransactionsTableTableManager(
      $_db,
      $_db.scheduledTransactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isClosed => $composableBuilder(
    column: $table.isClosed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onBudget => $composableBuilder(
    column: $table.onBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> payeesRefs(
    Expression<bool> Function($$PayeesTableFilterComposer f) f,
  ) {
    final $$PayeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.defaultAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableFilterComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> accountTransactions(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transferTransactions(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.transferAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledTransactionsRefs(
    Expression<bool> Function($$ScheduledTransactionsTableFilterComposer f) f,
  ) {
    final $$ScheduledTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isClosed => $composableBuilder(
    column: $table.isClosed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onBudget => $composableBuilder(
    column: $table.onBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isClosed =>
      $composableBuilder(column: $table.isClosed, builder: (column) => column);

  GeneratedColumn<bool> get onBudget =>
      $composableBuilder(column: $table.onBudget, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> payeesRefs<T extends Object>(
    Expression<T> Function($$PayeesTableAnnotationComposer a) f,
  ) {
    final $$PayeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.defaultAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableAnnotationComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> accountTransactions<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transferTransactions<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.transferAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduledTransactionsRefs<T extends Object>(
    Expression<T> Function($$ScheduledTransactionsTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool payeesRefs,
            bool accountTransactions,
            bool transferTransactions,
            bool scheduledTransactionsRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> startingBalance = const Value.absent(),
                Value<bool> isClosed = const Value.absent(),
                Value<bool> onBudget = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                currency: currency,
                startingBalance: startingBalance,
                isClosed: isClosed,
                onBudget: onBudget,
                color: color,
                icon: icon,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String> currency = const Value.absent(),
                Value<int> startingBalance = const Value.absent(),
                Value<bool> isClosed = const Value.absent(),
                Value<bool> onBudget = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                currency: currency,
                startingBalance: startingBalance,
                isClosed: isClosed,
                onBudget: onBudget,
                color: color,
                icon: icon,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                payeesRefs = false,
                accountTransactions = false,
                transferTransactions = false,
                scheduledTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (payeesRefs) db.payees,
                    if (accountTransactions) db.transactions,
                    if (transferTransactions) db.transactions,
                    if (scheduledTransactionsRefs) db.scheduledTransactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (payeesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Payee
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._payeesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).payeesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultAccountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (accountTransactions)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._accountTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).accountTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transferTransactions)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._transferTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).transferTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transferAccountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduledTransactionsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          ScheduledTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._scheduledTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool payeesRefs,
        bool accountTransactions,
        bool transferTransactions,
        bool scheduledTransactionsRefs,
      })
    >;
typedef $$CategoryGroupsTableCreateCompanionBuilder =
    CategoryGroupsCompanion Function({
      required String id,
      required String name,
      Value<int?> sortOrder,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$CategoryGroupsTableUpdateCompanionBuilder =
    CategoryGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> sortOrder,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$CategoryGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $CategoryGroupsTable, CategoryGroup> {
  $$CategoryGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CategoriesTable, List<Category>>
  _categoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categories,
    aliasName: 'category_groups__id__categories__category_group_id',
  );

  $$CategoriesTableProcessedTableManager get categoriesRefs {
    final manager = $$CategoriesTableTableManager($_db, $_db.categories).filter(
      (f) => f.categoryGroupId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_categoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> categoriesRefs(
    Expression<bool> Function($$CategoriesTableFilterComposer f) f,
  ) {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> categoriesRefs<T extends Object>(
    Expression<T> Function($$CategoriesTableAnnotationComposer a) f,
  ) {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryGroupsTable,
          CategoryGroup,
          $$CategoryGroupsTableFilterComposer,
          $$CategoryGroupsTableOrderingComposer,
          $$CategoryGroupsTableAnnotationComposer,
          $$CategoryGroupsTableCreateCompanionBuilder,
          $$CategoryGroupsTableUpdateCompanionBuilder,
          (CategoryGroup, $$CategoryGroupsTableReferences),
          CategoryGroup,
          PrefetchHooks Function({bool categoriesRefs})
        > {
  $$CategoryGroupsTableTableManager(
    _$AppDatabase db,
    $CategoryGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> sortOrder = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryGroupsTable, CategoryGroup>(table),
                  $$CategoryGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (categoriesRefs) db.categories],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (categoriesRefs)
                    await $_getPrefetchedData<
                      CategoryGroup,
                      $CategoryGroupsTable,
                      Category
                    >(
                      currentTable: table,
                      referencedTable: $$CategoryGroupsTableReferences
                          ._categoriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoryGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).categoriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.categoryGroupId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoryGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryGroupsTable,
      CategoryGroup,
      $$CategoryGroupsTableFilterComposer,
      $$CategoryGroupsTableOrderingComposer,
      $$CategoryGroupsTableAnnotationComposer,
      $$CategoryGroupsTableCreateCompanionBuilder,
      $$CategoryGroupsTableUpdateCompanionBuilder,
      (CategoryGroup, $$CategoryGroupsTableReferences),
      CategoryGroup,
      PrefetchHooks Function({bool categoriesRefs})
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String name,
      Value<String?> categoryGroupId,
      Value<bool> isHidden,
      Value<int?> sortOrder,
      Value<String?> goalType,
      Value<int?> targetAmount,
      Value<DateTime?> targetDate,
      Value<int?> color,
      Value<String?> icon,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> categoryGroupId,
      Value<bool> isHidden,
      Value<int?> sortOrder,
      Value<String?> goalType,
      Value<int?> targetAmount,
      Value<DateTime?> targetDate,
      Value<int?> color,
      Value<String?> icon,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoryGroupsTable _categoryGroupIdTable(_$AppDatabase db) => db
      .categoryGroups
      .createAlias('categories__category_group_id__category_groups__id');

  $$CategoryGroupsTableProcessedTableManager? get categoryGroupId {
    final $_column = $_itemColumn<String>('category_group_id');
    if ($_column == null) return null;
    final manager = $$CategoryGroupsTableTableManager(
      $_db,
      $_db.categoryGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BudgetsTable, List<Budget>> _budgetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.budgets,
    aliasName: 'categories__id__budgets__category_id',
  );

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayeesTable, List<Payee>> _payeesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payees,
    aliasName: 'categories__id__payees__auto_category_id',
  );

  $$PayeesTableProcessedTableManager get payeesRefs {
    final manager = $$PayeesTableTableManager(
      $_db,
      $_db.payees,
    ).filter((f) => f.autoCategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payeesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledTransactionsTable,
    List<ScheduledTransaction>
  >
  _scheduledTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTransactions,
        aliasName: 'categories__id__scheduled_transactions__category_id',
      );

  $$ScheduledTransactionsTableProcessedTableManager
  get scheduledTransactionsRefs {
    final manager = $$ScheduledTransactionsTableTableManager(
      $_db,
      $_db.scheduledTransactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryGroupsTableFilterComposer get categoryGroupId {
    final $$CategoryGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryGroupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableFilterComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> budgetsRefs(
    Expression<bool> Function($$BudgetsTableFilterComposer f) f,
  ) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payeesRefs(
    Expression<bool> Function($$PayeesTableFilterComposer f) f,
  ) {
    final $$PayeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.autoCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableFilterComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledTransactionsRefs(
    Expression<bool> Function($$ScheduledTransactionsTableFilterComposer f) f,
  ) {
    final $$ScheduledTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryGroupsTableOrderingComposer get categoryGroupId {
    final $$CategoryGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryGroupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoryGroupsTableAnnotationComposer get categoryGroupId {
    final $$CategoryGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryGroupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> budgetsRefs<T extends Object>(
    Expression<T> Function($$BudgetsTableAnnotationComposer a) f,
  ) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payeesRefs<T extends Object>(
    Expression<T> Function($$PayeesTableAnnotationComposer a) f,
  ) {
    final $$PayeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.autoCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableAnnotationComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduledTransactionsRefs<T extends Object>(
    Expression<T> Function($$ScheduledTransactionsTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool categoryGroupId,
            bool budgetsRefs,
            bool payeesRefs,
            bool transactionsRefs,
            bool scheduledTransactionsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> categoryGroupId = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> goalType = const Value.absent(),
                Value<int?> targetAmount = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                categoryGroupId: categoryGroupId,
                isHidden: isHidden,
                sortOrder: sortOrder,
                goalType: goalType,
                targetAmount: targetAmount,
                targetDate: targetDate,
                color: color,
                icon: icon,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> categoryGroupId = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> goalType = const Value.absent(),
                Value<int?> targetAmount = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                categoryGroupId: categoryGroupId,
                isHidden: isHidden,
                sortOrder: sortOrder,
                goalType: goalType,
                targetAmount: targetAmount,
                targetDate: targetDate,
                color: color,
                icon: icon,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryGroupId = false,
                budgetsRefs = false,
                payeesRefs = false,
                transactionsRefs = false,
                scheduledTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (budgetsRefs) db.budgets,
                    if (payeesRefs) db.payees,
                    if (transactionsRefs) db.transactions,
                    if (scheduledTransactionsRefs) db.scheduledTransactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryGroupId,
                                    referencedTable: $$CategoriesTableReferences
                                        ._categoryGroupIdTable(db),
                                    referencedColumn:
                                        $$CategoriesTableReferences
                                            ._categoryGroupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (budgetsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Budget
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (payeesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Payee
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._payeesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).payeesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.autoCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduledTransactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          ScheduledTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._scheduledTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool categoryGroupId,
        bool budgetsRefs,
        bool payeesRefs,
        bool transactionsRefs,
        bool scheduledTransactionsRefs,
      })
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      required String categoryId,
      required String month,
      Value<int> budgeted,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> month,
      Value<int> budgeted,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, Budget> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgeted => $composableBuilder(
    column: $table.budgeted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgeted => $composableBuilder(
    column: $table.budgeted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get budgeted =>
      $composableBuilder(column: $table.budgeted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, $$BudgetsTableReferences),
          Budget,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> budgeted = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                categoryId: categoryId,
                month: month,
                budgeted: budgeted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String month,
                Value<int> budgeted = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                month: month,
                budgeted: budgeted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, Budget>(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$BudgetsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$BudgetsTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, $$BudgetsTableReferences),
      Budget,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$BudgetTemplatesTableCreateCompanionBuilder =
    BudgetTemplatesCompanion Function({
      required String id,
      required String name,
      required String data,
      Value<String?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$BudgetTemplatesTableUpdateCompanionBuilder =
    BudgetTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> data,
      Value<String?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$BudgetTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetTemplatesTable> {
  $$BudgetTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetTemplatesTable> {
  $$BudgetTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetTemplatesTable> {
  $$BudgetTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BudgetTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetTemplatesTable,
          BudgetTemplate,
          $$BudgetTemplatesTableFilterComposer,
          $$BudgetTemplatesTableOrderingComposer,
          $$BudgetTemplatesTableAnnotationComposer,
          $$BudgetTemplatesTableCreateCompanionBuilder,
          $$BudgetTemplatesTableUpdateCompanionBuilder,
          (
            BudgetTemplate,
            BaseReferences<
              _$AppDatabase,
              $BudgetTemplatesTable,
              BudgetTemplate
            >,
          ),
          BudgetTemplate,
          PrefetchHooks Function()
        > {
  $$BudgetTemplatesTableTableManager(
    _$AppDatabase db,
    $BudgetTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetTemplatesCompanion(
                id: id,
                name: name,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String data,
                Value<String?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetTemplatesCompanion.insert(
                id: id,
                name: name,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetTemplatesTable, BudgetTemplate>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BudgetTemplatesTable,
                    BudgetTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetTemplatesTable,
      BudgetTemplate,
      $$BudgetTemplatesTableFilterComposer,
      $$BudgetTemplatesTableOrderingComposer,
      $$BudgetTemplatesTableAnnotationComposer,
      $$BudgetTemplatesTableCreateCompanionBuilder,
      $$BudgetTemplatesTableUpdateCompanionBuilder,
      (
        BudgetTemplate,
        BaseReferences<_$AppDatabase, $BudgetTemplatesTable, BudgetTemplate>,
      ),
      BudgetTemplate,
      PrefetchHooks Function()
    >;
typedef $$PayeesTableCreateCompanionBuilder =
    PayeesCompanion Function({
      required String id,
      required String name,
      Value<String?> autoCategoryId,
      Value<String?> defaultAccountId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String?> icon,
      Value<int?> color,
      Value<String?> notes,
      Value<bool> isFavorite,
      Value<int> rowid,
    });
typedef $$PayeesTableUpdateCompanionBuilder =
    PayeesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> autoCategoryId,
      Value<String?> defaultAccountId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String?> icon,
      Value<int?> color,
      Value<String?> notes,
      Value<bool> isFavorite,
      Value<int> rowid,
    });

final class $$PayeesTableReferences
    extends BaseReferences<_$AppDatabase, $PayeesTable, Payee> {
  $$PayeesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _autoCategoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('payees__auto_category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get autoCategoryId {
    final $_column = $_itemColumn<String>('auto_category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_autoCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _defaultAccountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('payees__default_account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get defaultAccountId {
    final $_column = $_itemColumn<String>('default_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_defaultAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'payees__id__transactions__payee_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.payeeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledTransactionsTable,
    List<ScheduledTransaction>
  >
  _scheduledTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTransactions,
        aliasName: 'payees__id__scheduled_transactions__payee_id',
      );

  $$ScheduledTransactionsTableProcessedTableManager
  get scheduledTransactionsRefs {
    final manager = $$ScheduledTransactionsTableTableManager(
      $_db,
      $_db.scheduledTransactions,
    ).filter((f) => f.payeeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayeesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get autoCategoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.autoCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get defaultAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledTransactionsRefs(
    Expression<bool> Function($$ScheduledTransactionsTableFilterComposer f) f,
  ) {
    final $$ScheduledTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.payeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PayeesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get autoCategoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.autoCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get defaultAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get autoCategoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.autoCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get defaultAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduledTransactionsRefs<T extends Object>(
    Expression<T> Function($$ScheduledTransactionsTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTransactions,
          getReferencedColumn: (t) => t.payeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PayeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeesTable,
          Payee,
          $$PayeesTableFilterComposer,
          $$PayeesTableOrderingComposer,
          $$PayeesTableAnnotationComposer,
          $$PayeesTableCreateCompanionBuilder,
          $$PayeesTableUpdateCompanionBuilder,
          (Payee, $$PayeesTableReferences),
          Payee,
          PrefetchHooks Function({
            bool autoCategoryId,
            bool defaultAccountId,
            bool transactionsRefs,
            bool scheduledTransactionsRefs,
          })
        > {
  $$PayeesTableTableManager(_$AppDatabase db, $PayeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> autoCategoryId = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion(
                id: id,
                name: name,
                autoCategoryId: autoCategoryId,
                defaultAccountId: defaultAccountId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                icon: icon,
                color: color,
                notes: notes,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> autoCategoryId = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion.insert(
                id: id,
                name: name,
                autoCategoryId: autoCategoryId,
                defaultAccountId: defaultAccountId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                icon: icon,
                color: color,
                notes: notes,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayeesTable, Payee>(table),
                  $$PayeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                autoCategoryId = false,
                defaultAccountId = false,
                transactionsRefs = false,
                scheduledTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (scheduledTransactionsRefs) db.scheduledTransactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (autoCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.autoCategoryId,
                                    referencedTable: $$PayeesTableReferences
                                        ._autoCategoryIdTable(db),
                                    referencedColumn: $$PayeesTableReferences
                                        ._autoCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (defaultAccountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.defaultAccountId,
                                    referencedTable: $$PayeesTableReferences
                                        ._defaultAccountIdTable(db),
                                    referencedColumn: $$PayeesTableReferences
                                        ._defaultAccountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Payee,
                          $PayeesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$PayeesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayeesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.payeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduledTransactionsRefs)
                        await $_getPrefetchedData<
                          Payee,
                          $PayeesTable,
                          ScheduledTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$PayeesTableReferences
                              ._scheduledTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayeesTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.payeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PayeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeesTable,
      Payee,
      $$PayeesTableFilterComposer,
      $$PayeesTableOrderingComposer,
      $$PayeesTableAnnotationComposer,
      $$PayeesTableCreateCompanionBuilder,
      $$PayeesTableUpdateCompanionBuilder,
      (Payee, $$PayeesTableReferences),
      Payee,
      PrefetchHooks Function({
        bool autoCategoryId,
        bool defaultAccountId,
        bool transactionsRefs,
        bool scheduledTransactionsRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String accountId,
      required DateTime date,
      required int amount,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<String?> memo,
      Value<int> cleared,
      Value<bool> approved,
      Value<bool> isDeleted,
      Value<String?> transferAccountId,
      Value<String?> transferTransactionId,
      Value<String?> parentTransactionId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<DateTime> date,
      Value<int> amount,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<String?> memo,
      Value<int> cleared,
      Value<bool> approved,
      Value<bool> isDeleted,
      Value<String?> transferAccountId,
      Value<String?> transferTransactionId,
      Value<String?> parentTransactionId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('transactions__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayeesTable _payeeIdTable(_$AppDatabase db) =>
      db.payees.createAlias('transactions__payee_id__payees__id');

  $$PayeesTableProcessedTableManager? get payeeId {
    final $_column = $_itemColumn<String>('payee_id');
    if ($_column == null) return null;
    final manager = $$PayeesTableTableManager(
      $_db,
      $_db.payees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _transferAccountIdTable(_$AppDatabase db) => db.accounts
      .createAlias('transactions__transfer_account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get transferAccountId {
    final $_column = $_itemColumn<String>('transfer_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transferAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _parentTransactionIdTable(_$AppDatabase db) => db
      .transactions
      .createAlias('transactions__parent_transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager? get parentTransactionId {
    final $_column = $_itemColumn<String>('parent_transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentTransactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cleared => $composableBuilder(
    column: $table.cleared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferTransactionId => $composableBuilder(
    column: $table.transferTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableFilterComposer get payeeId {
    final $$PayeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableFilterComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get transferAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get parentTransactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cleared => $composableBuilder(
    column: $table.cleared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferTransactionId => $composableBuilder(
    column: $table.transferTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableOrderingComposer get payeeId {
    final $$PayeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableOrderingComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get transferAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get parentTransactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<int> get cleared =>
      $composableBuilder(column: $table.cleared, builder: (column) => column);

  GeneratedColumn<bool> get approved =>
      $composableBuilder(column: $table.approved, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get transferTransactionId => $composableBuilder(
    column: $table.transferTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableAnnotationComposer get payeeId {
    final $$PayeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableAnnotationComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get transferAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get parentTransactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool accountId,
            bool payeeId,
            bool categoryId,
            bool transferAccountId,
            bool parentTransactionId,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> cleared = const Value.absent(),
                Value<bool> approved = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> transferAccountId = const Value.absent(),
                Value<String?> transferTransactionId = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                accountId: accountId,
                date: date,
                amount: amount,
                payeeId: payeeId,
                categoryId: categoryId,
                memo: memo,
                cleared: cleared,
                approved: approved,
                isDeleted: isDeleted,
                transferAccountId: transferAccountId,
                transferTransactionId: transferTransactionId,
                parentTransactionId: parentTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required DateTime date,
                required int amount,
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> cleared = const Value.absent(),
                Value<bool> approved = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> transferAccountId = const Value.absent(),
                Value<String?> transferTransactionId = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                date: date,
                amount: amount,
                payeeId: payeeId,
                categoryId: categoryId,
                memo: memo,
                cleared: cleared,
                approved: approved,
                isDeleted: isDeleted,
                transferAccountId: transferAccountId,
                transferTransactionId: transferTransactionId,
                parentTransactionId: parentTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                payeeId = false,
                categoryId = false,
                transferAccountId = false,
                parentTransactionId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (payeeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.payeeId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._payeeIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._payeeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (transferAccountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transferAccountId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._transferAccountIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._transferAccountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (parentTransactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentTransactionId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._parentTransactionIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._parentTransactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({
        bool accountId,
        bool payeeId,
        bool categoryId,
        bool transferAccountId,
        bool parentTransactionId,
      })
    >;
typedef $$ReportNotesTableCreateCompanionBuilder =
    ReportNotesCompanion Function({
      required String id,
      required String date,
      required String note,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$ReportNotesTableUpdateCompanionBuilder =
    ReportNotesCompanion Function({
      Value<String> id,
      Value<String> date,
      Value<String> note,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$ReportNotesTableFilterComposer
    extends Composer<_$AppDatabase, $ReportNotesTable> {
  $$ReportNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReportNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportNotesTable> {
  $$ReportNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReportNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportNotesTable> {
  $$ReportNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReportNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReportNotesTable,
          ReportNote,
          $$ReportNotesTableFilterComposer,
          $$ReportNotesTableOrderingComposer,
          $$ReportNotesTableAnnotationComposer,
          $$ReportNotesTableCreateCompanionBuilder,
          $$ReportNotesTableUpdateCompanionBuilder,
          (
            ReportNote,
            BaseReferences<_$AppDatabase, $ReportNotesTable, ReportNote>,
          ),
          ReportNote,
          PrefetchHooks Function()
        > {
  $$ReportNotesTableTableManager(_$AppDatabase db, $ReportNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportNotesCompanion(
                id: id,
                date: date,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                required String note,
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportNotesCompanion.insert(
                id: id,
                date: date,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportNotesTable, ReportNote>(table),
                  BaseReferences<_$AppDatabase, $ReportNotesTable, ReportNote>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReportNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReportNotesTable,
      ReportNote,
      $$ReportNotesTableFilterComposer,
      $$ReportNotesTableOrderingComposer,
      $$ReportNotesTableAnnotationComposer,
      $$ReportNotesTableCreateCompanionBuilder,
      $$ReportNotesTableUpdateCompanionBuilder,
      (
        ReportNote,
        BaseReferences<_$AppDatabase, $ReportNotesTable, ReportNote>,
      ),
      ReportNote,
      PrefetchHooks Function()
    >;
typedef $$ScheduledTransactionsTableCreateCompanionBuilder =
    ScheduledTransactionsCompanion Function({
      required String id,
      Value<String?> accountId,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<int?> amount,
      Value<String?> frequency,
      Value<int?> interval,
      Value<int?> occurrenceCount,
      Value<DateTime?> nextDate,
      Value<DateTime?> endDate,
      Value<bool> autoApprove,
      Value<String?> memo,
      Value<int?> anchorDay,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$ScheduledTransactionsTableUpdateCompanionBuilder =
    ScheduledTransactionsCompanion Function({
      Value<String> id,
      Value<String?> accountId,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<int?> amount,
      Value<String?> frequency,
      Value<int?> interval,
      Value<int?> occurrenceCount,
      Value<DateTime?> nextDate,
      Value<DateTime?> endDate,
      Value<bool> autoApprove,
      Value<String?> memo,
      Value<int?> anchorDay,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$ScheduledTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledTransactionsTable,
          ScheduledTransaction
        > {
  $$ScheduledTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias('scheduled_transactions__account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<String>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayeesTable _payeeIdTable(_$AppDatabase db) =>
      db.payees.createAlias('scheduled_transactions__payee_id__payees__id');

  $$PayeesTableProcessedTableManager? get payeeId {
    final $_column = $_itemColumn<String>('payee_id');
    if ($_column == null) return null;
    final manager = $$PayeesTableTableManager(
      $_db,
      $_db.payees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('scheduled_transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduledTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledTransactionsTable> {
  $$ScheduledTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anchorDay => $composableBuilder(
    column: $table.anchorDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableFilterComposer get payeeId {
    final $$PayeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableFilterComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledTransactionsTable> {
  $$ScheduledTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anchorDay => $composableBuilder(
    column: $table.anchorDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableOrderingComposer get payeeId {
    final $$PayeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableOrderingComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledTransactionsTable> {
  $$ScheduledTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<int> get anchorDay =>
      $composableBuilder(column: $table.anchorDay, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayeesTableAnnotationComposer get payeeId {
    final $$PayeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableAnnotationComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledTransactionsTable,
          ScheduledTransaction,
          $$ScheduledTransactionsTableFilterComposer,
          $$ScheduledTransactionsTableOrderingComposer,
          $$ScheduledTransactionsTableAnnotationComposer,
          $$ScheduledTransactionsTableCreateCompanionBuilder,
          $$ScheduledTransactionsTableUpdateCompanionBuilder,
          (ScheduledTransaction, $$ScheduledTransactionsTableReferences),
          ScheduledTransaction,
          PrefetchHooks Function({
            bool accountId,
            bool payeeId,
            bool categoryId,
          })
        > {
  $$ScheduledTransactionsTableTableManager(
    _$AppDatabase db,
    $ScheduledTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int?> amount = const Value.absent(),
                Value<String?> frequency = const Value.absent(),
                Value<int?> interval = const Value.absent(),
                Value<int?> occurrenceCount = const Value.absent(),
                Value<DateTime?> nextDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int?> anchorDay = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledTransactionsCompanion(
                id: id,
                accountId: accountId,
                payeeId: payeeId,
                categoryId: categoryId,
                amount: amount,
                frequency: frequency,
                interval: interval,
                occurrenceCount: occurrenceCount,
                nextDate: nextDate,
                endDate: endDate,
                autoApprove: autoApprove,
                memo: memo,
                anchorDay: anchorDay,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> accountId = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int?> amount = const Value.absent(),
                Value<String?> frequency = const Value.absent(),
                Value<int?> interval = const Value.absent(),
                Value<int?> occurrenceCount = const Value.absent(),
                Value<DateTime?> nextDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int?> anchorDay = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledTransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                payeeId: payeeId,
                categoryId: categoryId,
                amount: amount,
                frequency: frequency,
                interval: interval,
                occurrenceCount: occurrenceCount,
                nextDate: nextDate,
                endDate: endDate,
                autoApprove: autoApprove,
                memo: memo,
                anchorDay: anchorDay,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledTransactionsTable,
                    ScheduledTransaction
                  >(table),
                  $$ScheduledTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({accountId = false, payeeId = false, categoryId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$ScheduledTransactionsTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$ScheduledTransactionsTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (payeeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.payeeId,
                                    referencedTable:
                                        $$ScheduledTransactionsTableReferences
                                            ._payeeIdTable(db),
                                    referencedColumn:
                                        $$ScheduledTransactionsTableReferences
                                            ._payeeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$ScheduledTransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$ScheduledTransactionsTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$ScheduledTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledTransactionsTable,
      ScheduledTransaction,
      $$ScheduledTransactionsTableFilterComposer,
      $$ScheduledTransactionsTableOrderingComposer,
      $$ScheduledTransactionsTableAnnotationComposer,
      $$ScheduledTransactionsTableCreateCompanionBuilder,
      $$ScheduledTransactionsTableUpdateCompanionBuilder,
      (ScheduledTransaction, $$ScheduledTransactionsTableReferences),
      ScheduledTransaction,
      PrefetchHooks Function({bool accountId, bool payeeId, bool categoryId})
    >;
typedef $$PendingSyncChangesTableCreateCompanionBuilder =
    PendingSyncChangesCompanion Function({
      Value<int> id,
      required String targetTableName,
      required String recordId,
      required String action,
      Value<DateTime> changedAt,
      Value<String?> oldUpdatedAt,
    });
typedef $$PendingSyncChangesTableUpdateCompanionBuilder =
    PendingSyncChangesCompanion Function({
      Value<int> id,
      Value<String> targetTableName,
      Value<String> recordId,
      Value<String> action,
      Value<DateTime> changedAt,
      Value<String?> oldUpdatedAt,
    });

class $$PendingSyncChangesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncChangesTable> {
  $$PendingSyncChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTableName => $composableBuilder(
    column: $table.targetTableName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldUpdatedAt => $composableBuilder(
    column: $table.oldUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSyncChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncChangesTable> {
  $$PendingSyncChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTableName => $composableBuilder(
    column: $table.targetTableName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldUpdatedAt => $composableBuilder(
    column: $table.oldUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSyncChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncChangesTable> {
  $$PendingSyncChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTableName => $composableBuilder(
    column: $table.targetTableName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<String> get oldUpdatedAt => $composableBuilder(
    column: $table.oldUpdatedAt,
    builder: (column) => column,
  );
}

class $$PendingSyncChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSyncChangesTable,
          PendingSyncChange,
          $$PendingSyncChangesTableFilterComposer,
          $$PendingSyncChangesTableOrderingComposer,
          $$PendingSyncChangesTableAnnotationComposer,
          $$PendingSyncChangesTableCreateCompanionBuilder,
          $$PendingSyncChangesTableUpdateCompanionBuilder,
          (
            PendingSyncChange,
            BaseReferences<
              _$AppDatabase,
              $PendingSyncChangesTable,
              PendingSyncChange
            >,
          ),
          PendingSyncChange,
          PrefetchHooks Function()
        > {
  $$PendingSyncChangesTableTableManager(
    _$AppDatabase db,
    $PendingSyncChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncChangesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> targetTableName = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<String?> oldUpdatedAt = const Value.absent(),
              }) => PendingSyncChangesCompanion(
                id: id,
                targetTableName: targetTableName,
                recordId: recordId,
                action: action,
                changedAt: changedAt,
                oldUpdatedAt: oldUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String targetTableName,
                required String recordId,
                required String action,
                Value<DateTime> changedAt = const Value.absent(),
                Value<String?> oldUpdatedAt = const Value.absent(),
              }) => PendingSyncChangesCompanion.insert(
                id: id,
                targetTableName: targetTableName,
                recordId: recordId,
                action: action,
                changedAt: changedAt,
                oldUpdatedAt: oldUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingSyncChangesTable, PendingSyncChange>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingSyncChangesTable,
                    PendingSyncChange
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSyncChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSyncChangesTable,
      PendingSyncChange,
      $$PendingSyncChangesTableFilterComposer,
      $$PendingSyncChangesTableOrderingComposer,
      $$PendingSyncChangesTableAnnotationComposer,
      $$PendingSyncChangesTableCreateCompanionBuilder,
      $$PendingSyncChangesTableUpdateCompanionBuilder,
      (
        PendingSyncChange,
        BaseReferences<
          _$AppDatabase,
          $PendingSyncChangesTable,
          PendingSyncChange
        >,
      ),
      PendingSyncChange,
      PrefetchHooks Function()
    >;
typedef $$ParsingHistoryTableCreateCompanionBuilder =
    ParsingHistoryCompanion Function({
      required String id,
      required String input,
      Value<String?> payeeId,
      Value<String?> categoryId,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ParsingHistoryTableUpdateCompanionBuilder =
    ParsingHistoryCompanion Function({
      Value<String> id,
      Value<String> input,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ParsingHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ParsingHistoryTable> {
  $$ParsingHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParsingHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ParsingHistoryTable> {
  $$ParsingHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParsingHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParsingHistoryTable> {
  $$ParsingHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get input =>
      $composableBuilder(column: $table.input, builder: (column) => column);

  GeneratedColumn<String> get payeeId =>
      $composableBuilder(column: $table.payeeId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ParsingHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParsingHistoryTable,
          ParsingHistoryData,
          $$ParsingHistoryTableFilterComposer,
          $$ParsingHistoryTableOrderingComposer,
          $$ParsingHistoryTableAnnotationComposer,
          $$ParsingHistoryTableCreateCompanionBuilder,
          $$ParsingHistoryTableUpdateCompanionBuilder,
          (
            ParsingHistoryData,
            BaseReferences<
              _$AppDatabase,
              $ParsingHistoryTable,
              ParsingHistoryData
            >,
          ),
          ParsingHistoryData,
          PrefetchHooks Function()
        > {
  $$ParsingHistoryTableTableManager(
    _$AppDatabase db,
    $ParsingHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParsingHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParsingHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParsingHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> input = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParsingHistoryCompanion(
                id: id,
                input: input,
                payeeId: payeeId,
                categoryId: categoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String input,
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ParsingHistoryCompanion.insert(
                id: id,
                input: input,
                payeeId: payeeId,
                categoryId: categoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ParsingHistoryTable, ParsingHistoryData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ParsingHistoryTable,
                    ParsingHistoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParsingHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParsingHistoryTable,
      ParsingHistoryData,
      $$ParsingHistoryTableFilterComposer,
      $$ParsingHistoryTableOrderingComposer,
      $$ParsingHistoryTableAnnotationComposer,
      $$ParsingHistoryTableCreateCompanionBuilder,
      $$ParsingHistoryTableUpdateCompanionBuilder,
      (
        ParsingHistoryData,
        BaseReferences<_$AppDatabase, $ParsingHistoryTable, ParsingHistoryData>,
      ),
      ParsingHistoryData,
      PrefetchHooks Function()
    >;
typedef $$ImportProfilesTableCreateCompanionBuilder =
    ImportProfilesCompanion Function({
      required String id,
      required String name,
      required String dateFormat,
      required String decimalSeparator,
      required bool outflowIsNegative,
      Value<String?> dateColumn,
      Value<String?> amountColumn,
      Value<String?> payeeColumn,
      Value<String?> memoColumn,
      Value<String?> categoryColumn,
      required String createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$ImportProfilesTableUpdateCompanionBuilder =
    ImportProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> dateFormat,
      Value<String> decimalSeparator,
      Value<bool> outflowIsNegative,
      Value<String?> dateColumn,
      Value<String?> amountColumn,
      Value<String?> payeeColumn,
      Value<String?> memoColumn,
      Value<String?> categoryColumn,
      Value<String> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$ImportProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ImportProfilesTable> {
  $$ImportProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateFormat => $composableBuilder(
    column: $table.dateFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decimalSeparator => $composableBuilder(
    column: $table.decimalSeparator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get outflowIsNegative => $composableBuilder(
    column: $table.outflowIsNegative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateColumn => $composableBuilder(
    column: $table.dateColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountColumn => $composableBuilder(
    column: $table.amountColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeColumn => $composableBuilder(
    column: $table.payeeColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoColumn => $composableBuilder(
    column: $table.memoColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryColumn => $composableBuilder(
    column: $table.categoryColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportProfilesTable> {
  $$ImportProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateFormat => $composableBuilder(
    column: $table.dateFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decimalSeparator => $composableBuilder(
    column: $table.decimalSeparator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get outflowIsNegative => $composableBuilder(
    column: $table.outflowIsNegative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateColumn => $composableBuilder(
    column: $table.dateColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountColumn => $composableBuilder(
    column: $table.amountColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeColumn => $composableBuilder(
    column: $table.payeeColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoColumn => $composableBuilder(
    column: $table.memoColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryColumn => $composableBuilder(
    column: $table.categoryColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportProfilesTable> {
  $$ImportProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get dateFormat => $composableBuilder(
    column: $table.dateFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decimalSeparator => $composableBuilder(
    column: $table.decimalSeparator,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get outflowIsNegative => $composableBuilder(
    column: $table.outflowIsNegative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateColumn => $composableBuilder(
    column: $table.dateColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amountColumn => $composableBuilder(
    column: $table.amountColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeColumn => $composableBuilder(
    column: $table.payeeColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memoColumn => $composableBuilder(
    column: $table.memoColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryColumn => $composableBuilder(
    column: $table.categoryColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ImportProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportProfilesTable,
          ImportProfile,
          $$ImportProfilesTableFilterComposer,
          $$ImportProfilesTableOrderingComposer,
          $$ImportProfilesTableAnnotationComposer,
          $$ImportProfilesTableCreateCompanionBuilder,
          $$ImportProfilesTableUpdateCompanionBuilder,
          (
            ImportProfile,
            BaseReferences<_$AppDatabase, $ImportProfilesTable, ImportProfile>,
          ),
          ImportProfile,
          PrefetchHooks Function()
        > {
  $$ImportProfilesTableTableManager(
    _$AppDatabase db,
    $ImportProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> dateFormat = const Value.absent(),
                Value<String> decimalSeparator = const Value.absent(),
                Value<bool> outflowIsNegative = const Value.absent(),
                Value<String?> dateColumn = const Value.absent(),
                Value<String?> amountColumn = const Value.absent(),
                Value<String?> payeeColumn = const Value.absent(),
                Value<String?> memoColumn = const Value.absent(),
                Value<String?> categoryColumn = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportProfilesCompanion(
                id: id,
                name: name,
                dateFormat: dateFormat,
                decimalSeparator: decimalSeparator,
                outflowIsNegative: outflowIsNegative,
                dateColumn: dateColumn,
                amountColumn: amountColumn,
                payeeColumn: payeeColumn,
                memoColumn: memoColumn,
                categoryColumn: categoryColumn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String dateFormat,
                required String decimalSeparator,
                required bool outflowIsNegative,
                Value<String?> dateColumn = const Value.absent(),
                Value<String?> amountColumn = const Value.absent(),
                Value<String?> payeeColumn = const Value.absent(),
                Value<String?> memoColumn = const Value.absent(),
                Value<String?> categoryColumn = const Value.absent(),
                required String createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportProfilesCompanion.insert(
                id: id,
                name: name,
                dateFormat: dateFormat,
                decimalSeparator: decimalSeparator,
                outflowIsNegative: outflowIsNegative,
                dateColumn: dateColumn,
                amountColumn: amountColumn,
                payeeColumn: payeeColumn,
                memoColumn: memoColumn,
                categoryColumn: categoryColumn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportProfilesTable, ImportProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ImportProfilesTable,
                    ImportProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportProfilesTable,
      ImportProfile,
      $$ImportProfilesTableFilterComposer,
      $$ImportProfilesTableOrderingComposer,
      $$ImportProfilesTableAnnotationComposer,
      $$ImportProfilesTableCreateCompanionBuilder,
      $$ImportProfilesTableUpdateCompanionBuilder,
      (
        ImportProfile,
        BaseReferences<_$AppDatabase, $ImportProfilesTable, ImportProfile>,
      ),
      ImportProfile,
      PrefetchHooks Function()
    >;
typedef $$RulesTableCreateCompanionBuilder =
    RulesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required int priority,
      Value<bool> isActive,
      required RuleMatchLogic matchLogic,
      required List<RuleCondition> conditions,
      required List<RuleAction> actions,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$RulesTableUpdateCompanionBuilder =
    RulesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<int> priority,
      Value<bool> isActive,
      Value<RuleMatchLogic> matchLogic,
      Value<List<RuleCondition>> conditions,
      Value<List<RuleAction>> actions,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$RulesTableFilterComposer extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RuleMatchLogic, RuleMatchLogic, String>
  get matchLogic => $composableBuilder(
    column: $table.matchLogic,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    List<RuleCondition>,
    List<RuleCondition>,
    String
  >
  get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<RuleAction>, List<RuleAction>, String>
  get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchLogic => $composableBuilder(
    column: $table.matchLogic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleMatchLogic, String> get matchLogic =>
      $composableBuilder(
        column: $table.matchLogic,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<RuleCondition>, String>
  get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<RuleAction>, String> get actions =>
      $composableBuilder(column: $table.actions, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RulesTable,
          Rule,
          $$RulesTableFilterComposer,
          $$RulesTableOrderingComposer,
          $$RulesTableAnnotationComposer,
          $$RulesTableCreateCompanionBuilder,
          $$RulesTableUpdateCompanionBuilder,
          (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
          Rule,
          PrefetchHooks Function()
        > {
  $$RulesTableTableManager(_$AppDatabase db, $RulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<RuleMatchLogic> matchLogic = const Value.absent(),
                Value<List<RuleCondition>> conditions = const Value.absent(),
                Value<List<RuleAction>> actions = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RulesCompanion(
                id: id,
                name: name,
                description: description,
                priority: priority,
                isActive: isActive,
                matchLogic: matchLogic,
                conditions: conditions,
                actions: actions,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required int priority,
                Value<bool> isActive = const Value.absent(),
                required RuleMatchLogic matchLogic,
                required List<RuleCondition> conditions,
                required List<RuleAction> actions,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RulesCompanion.insert(
                id: id,
                name: name,
                description: description,
                priority: priority,
                isActive: isActive,
                matchLogic: matchLogic,
                conditions: conditions,
                actions: actions,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RulesTable, Rule>(table),
                  BaseReferences<_$AppDatabase, $RulesTable, Rule>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RulesTable,
      Rule,
      $$RulesTableFilterComposer,
      $$RulesTableOrderingComposer,
      $$RulesTableAnnotationComposer,
      $$RulesTableCreateCompanionBuilder,
      $$RulesTableUpdateCompanionBuilder,
      (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
      Rule,
      PrefetchHooks Function()
    >;
typedef $$SyncDeviceProgressTableCreateCompanionBuilder =
    SyncDeviceProgressCompanion Function({
      required String deviceId,
      Value<int> lastSequence,
      Value<int> rowid,
    });
typedef $$SyncDeviceProgressTableUpdateCompanionBuilder =
    SyncDeviceProgressCompanion Function({
      Value<String> deviceId,
      Value<int> lastSequence,
      Value<int> rowid,
    });

class $$SyncDeviceProgressTableFilterComposer
    extends Composer<_$AppDatabase, $SyncDeviceProgressTable> {
  $$SyncDeviceProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncDeviceProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncDeviceProgressTable> {
  $$SyncDeviceProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncDeviceProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncDeviceProgressTable> {
  $$SyncDeviceProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => column,
  );
}

class $$SyncDeviceProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncDeviceProgressTable,
          SyncDeviceProgressData,
          $$SyncDeviceProgressTableFilterComposer,
          $$SyncDeviceProgressTableOrderingComposer,
          $$SyncDeviceProgressTableAnnotationComposer,
          $$SyncDeviceProgressTableCreateCompanionBuilder,
          $$SyncDeviceProgressTableUpdateCompanionBuilder,
          (
            SyncDeviceProgressData,
            BaseReferences<
              _$AppDatabase,
              $SyncDeviceProgressTable,
              SyncDeviceProgressData
            >,
          ),
          SyncDeviceProgressData,
          PrefetchHooks Function()
        > {
  $$SyncDeviceProgressTableTableManager(
    _$AppDatabase db,
    $SyncDeviceProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncDeviceProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncDeviceProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncDeviceProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<int> lastSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncDeviceProgressCompanion(
                deviceId: deviceId,
                lastSequence: lastSequence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                Value<int> lastSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncDeviceProgressCompanion.insert(
                deviceId: deviceId,
                lastSequence: lastSequence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncDeviceProgressTable, SyncDeviceProgressData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncDeviceProgressTable,
                    SyncDeviceProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncDeviceProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncDeviceProgressTable,
      SyncDeviceProgressData,
      $$SyncDeviceProgressTableFilterComposer,
      $$SyncDeviceProgressTableOrderingComposer,
      $$SyncDeviceProgressTableAnnotationComposer,
      $$SyncDeviceProgressTableCreateCompanionBuilder,
      $$SyncDeviceProgressTableUpdateCompanionBuilder,
      (
        SyncDeviceProgressData,
        BaseReferences<
          _$AppDatabase,
          $SyncDeviceProgressTable,
          SyncDeviceProgressData
        >,
      ),
      SyncDeviceProgressData,
      PrefetchHooks Function()
    >;
typedef $$SyncKvTableCreateCompanionBuilder =
    SyncKvCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncKvTableUpdateCompanionBuilder =
    SyncKvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncKvTableFilterComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncKvTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncKvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncKvTable,
          SyncKvData,
          $$SyncKvTableFilterComposer,
          $$SyncKvTableOrderingComposer,
          $$SyncKvTableAnnotationComposer,
          $$SyncKvTableCreateCompanionBuilder,
          $$SyncKvTableUpdateCompanionBuilder,
          (SyncKvData, BaseReferences<_$AppDatabase, $SyncKvTable, SyncKvData>),
          SyncKvData,
          PrefetchHooks Function()
        > {
  $$SyncKvTableTableManager(_$AppDatabase db, $SyncKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncKvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) =>
                  SyncKvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncKvTable, SyncKvData>(table),
                  BaseReferences<_$AppDatabase, $SyncKvTable, SyncKvData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncKvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncKvTable,
      SyncKvData,
      $$SyncKvTableFilterComposer,
      $$SyncKvTableOrderingComposer,
      $$SyncKvTableAnnotationComposer,
      $$SyncKvTableCreateCompanionBuilder,
      $$SyncKvTableUpdateCompanionBuilder,
      (SyncKvData, BaseReferences<_$AppDatabase, $SyncKvTable, SyncKvData>),
      SyncKvData,
      PrefetchHooks Function()
    >;
typedef $$SyncRowVersionsTableCreateCompanionBuilder =
    SyncRowVersionsCompanion Function({
      required String syncTable,
      required String rowId,
      required int version,
      required String deviceId,
      Value<bool> deleted,
      Value<int?> sequence,
      Value<int> rowid,
    });
typedef $$SyncRowVersionsTableUpdateCompanionBuilder =
    SyncRowVersionsCompanion Function({
      Value<String> syncTable,
      Value<String> rowId,
      Value<int> version,
      Value<String> deviceId,
      Value<bool> deleted,
      Value<int?> sequence,
      Value<int> rowid,
    });

class $$SyncRowVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRowVersionsTable> {
  $$SyncRowVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncTable => $composableBuilder(
    column: $table.syncTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRowVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRowVersionsTable> {
  $$SyncRowVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncTable => $composableBuilder(
    column: $table.syncTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRowVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRowVersionsTable> {
  $$SyncRowVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncTable =>
      $composableBuilder(column: $table.syncTable, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);
}

class $$SyncRowVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRowVersionsTable,
          SyncRowVersion,
          $$SyncRowVersionsTableFilterComposer,
          $$SyncRowVersionsTableOrderingComposer,
          $$SyncRowVersionsTableAnnotationComposer,
          $$SyncRowVersionsTableCreateCompanionBuilder,
          $$SyncRowVersionsTableUpdateCompanionBuilder,
          (
            SyncRowVersion,
            BaseReferences<
              _$AppDatabase,
              $SyncRowVersionsTable,
              SyncRowVersion
            >,
          ),
          SyncRowVersion,
          PrefetchHooks Function()
        > {
  $$SyncRowVersionsTableTableManager(
    _$AppDatabase db,
    $SyncRowVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRowVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRowVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRowVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRowVersionsCompanion(
                syncTable: syncTable,
                rowId: rowId,
                version: version,
                deviceId: deviceId,
                deleted: deleted,
                sequence: sequence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncTable,
                required String rowId,
                required int version,
                required String deviceId,
                Value<bool> deleted = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRowVersionsCompanion.insert(
                syncTable: syncTable,
                rowId: rowId,
                version: version,
                deviceId: deviceId,
                deleted: deleted,
                sequence: sequence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRowVersionsTable, SyncRowVersion>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncRowVersionsTable,
                    SyncRowVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRowVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRowVersionsTable,
      SyncRowVersion,
      $$SyncRowVersionsTableFilterComposer,
      $$SyncRowVersionsTableOrderingComposer,
      $$SyncRowVersionsTableAnnotationComposer,
      $$SyncRowVersionsTableCreateCompanionBuilder,
      $$SyncRowVersionsTableUpdateCompanionBuilder,
      (
        SyncRowVersion,
        BaseReferences<_$AppDatabase, $SyncRowVersionsTable, SyncRowVersion>,
      ),
      SyncRowVersion,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      required String syncTable,
      required String rowId,
      Value<String?> localSnapshot,
      Value<String?> remoteSnapshot,
      required String remoteDeviceId,
      required DateTime resolvedAt,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      Value<String> syncTable,
      Value<String> rowId,
      Value<String?> localSnapshot,
      Value<String?> remoteSnapshot,
      Value<String> remoteDeviceId,
      Value<DateTime> resolvedAt,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncTable => $composableBuilder(
    column: $table.syncTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localSnapshot => $composableBuilder(
    column: $table.localSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteSnapshot => $composableBuilder(
    column: $table.remoteSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncTable => $composableBuilder(
    column: $table.syncTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localSnapshot => $composableBuilder(
    column: $table.localSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteSnapshot => $composableBuilder(
    column: $table.remoteSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncTable =>
      $composableBuilder(column: $table.syncTable, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get localSnapshot => $composableBuilder(
    column: $table.localSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteSnapshot => $composableBuilder(
    column: $table.remoteSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> syncTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String?> localSnapshot = const Value.absent(),
                Value<String?> remoteSnapshot = const Value.absent(),
                Value<String> remoteDeviceId = const Value.absent(),
                Value<DateTime> resolvedAt = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                syncTable: syncTable,
                rowId: rowId,
                localSnapshot: localSnapshot,
                remoteSnapshot: remoteSnapshot,
                remoteDeviceId: remoteDeviceId,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String syncTable,
                required String rowId,
                Value<String?> localSnapshot = const Value.absent(),
                Value<String?> remoteSnapshot = const Value.absent(),
                required String remoteDeviceId,
                required DateTime resolvedAt,
              }) => SyncConflictsCompanion.insert(
                id: id,
                syncTable: syncTable,
                rowId: rowId,
                localSnapshot: localSnapshot,
                remoteSnapshot: remoteSnapshot,
                remoteDeviceId: remoteDeviceId,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflict>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncConflictsTable,
                    SyncConflict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$SyncQuarantineTableCreateCompanionBuilder =
    SyncQuarantineCompanion Function({
      required String filename,
      required String deviceId,
      required int sequence,
      required String reason,
      required String error,
      Value<int> attempts,
      required DateTime firstSeen,
      required DateTime lastAttempt,
      required DateTime nextAttempt,
      Value<int> rowid,
    });
typedef $$SyncQuarantineTableUpdateCompanionBuilder =
    SyncQuarantineCompanion Function({
      Value<String> filename,
      Value<String> deviceId,
      Value<int> sequence,
      Value<String> reason,
      Value<String> error,
      Value<int> attempts,
      Value<DateTime> firstSeen,
      Value<DateTime> lastAttempt,
      Value<DateTime> nextAttempt,
      Value<int> rowid,
    });

class $$SyncQuarantineTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQuarantineTable> {
  $$SyncQuarantineTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQuarantineTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQuarantineTable> {
  $$SyncQuarantineTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQuarantineTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQuarantineTable> {
  $$SyncQuarantineTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => column,
  );
}

class $$SyncQuarantineTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQuarantineTable,
          SyncQuarantineData,
          $$SyncQuarantineTableFilterComposer,
          $$SyncQuarantineTableOrderingComposer,
          $$SyncQuarantineTableAnnotationComposer,
          $$SyncQuarantineTableCreateCompanionBuilder,
          $$SyncQuarantineTableUpdateCompanionBuilder,
          (
            SyncQuarantineData,
            BaseReferences<
              _$AppDatabase,
              $SyncQuarantineTable,
              SyncQuarantineData
            >,
          ),
          SyncQuarantineData,
          PrefetchHooks Function()
        > {
  $$SyncQuarantineTableTableManager(
    _$AppDatabase db,
    $SyncQuarantineTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQuarantineTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQuarantineTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQuarantineTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> filename = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> error = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastAttempt = const Value.absent(),
                Value<DateTime> nextAttempt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQuarantineCompanion(
                filename: filename,
                deviceId: deviceId,
                sequence: sequence,
                reason: reason,
                error: error,
                attempts: attempts,
                firstSeen: firstSeen,
                lastAttempt: lastAttempt,
                nextAttempt: nextAttempt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filename,
                required String deviceId,
                required int sequence,
                required String reason,
                required String error,
                Value<int> attempts = const Value.absent(),
                required DateTime firstSeen,
                required DateTime lastAttempt,
                required DateTime nextAttempt,
                Value<int> rowid = const Value.absent(),
              }) => SyncQuarantineCompanion.insert(
                filename: filename,
                deviceId: deviceId,
                sequence: sequence,
                reason: reason,
                error: error,
                attempts: attempts,
                firstSeen: firstSeen,
                lastAttempt: lastAttempt,
                nextAttempt: nextAttempt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQuarantineTable, SyncQuarantineData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncQuarantineTable,
                    SyncQuarantineData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQuarantineTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQuarantineTable,
      SyncQuarantineData,
      $$SyncQuarantineTableFilterComposer,
      $$SyncQuarantineTableOrderingComposer,
      $$SyncQuarantineTableAnnotationComposer,
      $$SyncQuarantineTableCreateCompanionBuilder,
      $$SyncQuarantineTableUpdateCompanionBuilder,
      (
        SyncQuarantineData,
        BaseReferences<_$AppDatabase, $SyncQuarantineTable, SyncQuarantineData>,
      ),
      SyncQuarantineData,
      PrefetchHooks Function()
    >;
typedef $$SyncApplyingTableCreateCompanionBuilder =
    SyncApplyingCompanion Function({Value<int> id});
typedef $$SyncApplyingTableUpdateCompanionBuilder =
    SyncApplyingCompanion Function({Value<int> id});

class $$SyncApplyingTableFilterComposer
    extends Composer<_$AppDatabase, $SyncApplyingTable> {
  $$SyncApplyingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncApplyingTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncApplyingTable> {
  $$SyncApplyingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncApplyingTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncApplyingTable> {
  $$SyncApplyingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$SyncApplyingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncApplyingTable,
          SyncApplyingData,
          $$SyncApplyingTableFilterComposer,
          $$SyncApplyingTableOrderingComposer,
          $$SyncApplyingTableAnnotationComposer,
          $$SyncApplyingTableCreateCompanionBuilder,
          $$SyncApplyingTableUpdateCompanionBuilder,
          (
            SyncApplyingData,
            BaseReferences<_$AppDatabase, $SyncApplyingTable, SyncApplyingData>,
          ),
          SyncApplyingData,
          PrefetchHooks Function()
        > {
  $$SyncApplyingTableTableManager(_$AppDatabase db, $SyncApplyingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncApplyingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncApplyingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncApplyingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              SyncApplyingCompanion(id: id),
          createCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              SyncApplyingCompanion.insert(id: id),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncApplyingTable, SyncApplyingData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncApplyingTable,
                    SyncApplyingData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncApplyingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncApplyingTable,
      SyncApplyingData,
      $$SyncApplyingTableFilterComposer,
      $$SyncApplyingTableOrderingComposer,
      $$SyncApplyingTableAnnotationComposer,
      $$SyncApplyingTableCreateCompanionBuilder,
      $$SyncApplyingTableUpdateCompanionBuilder,
      (
        SyncApplyingData,
        BaseReferences<_$AppDatabase, $SyncApplyingTable, SyncApplyingData>,
      ),
      SyncApplyingData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoryGroupsTableTableManager get categoryGroups =>
      $$CategoryGroupsTableTableManager(_db, _db.categoryGroups);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$BudgetTemplatesTableTableManager get budgetTemplates =>
      $$BudgetTemplatesTableTableManager(_db, _db.budgetTemplates);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$ReportNotesTableTableManager get reportNotes =>
      $$ReportNotesTableTableManager(_db, _db.reportNotes);
  $$ScheduledTransactionsTableTableManager get scheduledTransactions =>
      $$ScheduledTransactionsTableTableManager(_db, _db.scheduledTransactions);
  $$PendingSyncChangesTableTableManager get pendingSyncChanges =>
      $$PendingSyncChangesTableTableManager(_db, _db.pendingSyncChanges);
  $$ParsingHistoryTableTableManager get parsingHistory =>
      $$ParsingHistoryTableTableManager(_db, _db.parsingHistory);
  $$ImportProfilesTableTableManager get importProfiles =>
      $$ImportProfilesTableTableManager(_db, _db.importProfiles);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db, _db.rules);
  $$SyncDeviceProgressTableTableManager get syncDeviceProgress =>
      $$SyncDeviceProgressTableTableManager(_db, _db.syncDeviceProgress);
  $$SyncKvTableTableManager get syncKv =>
      $$SyncKvTableTableManager(_db, _db.syncKv);
  $$SyncRowVersionsTableTableManager get syncRowVersions =>
      $$SyncRowVersionsTableTableManager(_db, _db.syncRowVersions);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$SyncQuarantineTableTableManager get syncQuarantine =>
      $$SyncQuarantineTableTableManager(_db, _db.syncQuarantine);
  $$SyncApplyingTableTableManager get syncApplying =>
      $$SyncApplyingTableTableManager(_db, _db.syncApplying);
}
