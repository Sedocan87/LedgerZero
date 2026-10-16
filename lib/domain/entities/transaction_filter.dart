import 'package:ledger_zero/domain/entities/transaction.dart';

enum TransactionSortField { date, amount, payeeName, categoryName }

class TransactionSort {
  final TransactionSortField field;
  final bool ascending;

  const TransactionSort({required this.field, this.ascending = true});
}

class TransactionFilter {
  final List<String>? ids;
  final List<String>? accountIds;
  final List<String>? categoryIds;
  final List<String>? payeeIds;

  /// Inclusive first calendar day (stored dates are UTC midnight).
  final DateTime? startDate;

  /// Inclusive last calendar day.
  final DateTime? endDate;

  /// Inclusive lower bound of the signed amount in minor units.
  final int? minAmount;

  /// Inclusive upper bound of the signed amount in minor units.
  final int? maxAmount;

  /// Inclusive lower bound of the absolute amount in minor units (what the
  /// filter sheet's "amount from" field means: 10 matches -10 and +10).
  final int? minAbsAmount;

  /// Inclusive upper bound of the absolute amount in minor units.
  final int? maxAbsAmount;

  /// Matches the memo only.
  final String? memoSearch;

  /// Free-text search: matches memo, payee name or category name
  /// (case-insensitive substring).
  final String? searchText;

  /// Exact absolute amount (minor units) to match in addition to
  /// [searchText]; set when the search query parses as money.
  final int? searchAmount;

  final List<TransactionClearStatus>? clearedStatuses;

  /// Hides split children (the list shows the split parent instead). Ignored
  /// when [categoryIds] is set, because only children carry the categories
  /// of a split.
  final bool excludeSplitChildren;

  const TransactionFilter({
    this.ids,
    this.accountIds,
    this.categoryIds,
    this.payeeIds,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.minAbsAmount,
    this.maxAbsAmount,
    this.memoSearch,
    this.searchText,
    this.searchAmount,
    this.clearedStatuses,
    this.excludeSplitChildren = false,
  });

  /// Whether any user-visible filter criterion is set.
  bool get isActive =>
      (accountIds?.isNotEmpty ?? false) ||
      (categoryIds?.isNotEmpty ?? false) ||
      (payeeIds?.isNotEmpty ?? false) ||
      startDate != null ||
      endDate != null ||
      minAbsAmount != null ||
      maxAbsAmount != null ||
      (clearedStatuses?.isNotEmpty ?? false);

  TransactionFilter copyWith({
    List<String>? ids,
    List<String>? accountIds,
    List<String>? categoryIds,
    List<String>? payeeIds,
    DateTime? startDate,
    DateTime? endDate,
    int? minAmount,
    int? maxAmount,
    int? minAbsAmount,
    int? maxAbsAmount,
    String? memoSearch,
    String? searchText,
    int? searchAmount,
    List<TransactionClearStatus>? clearedStatuses,
    bool? excludeSplitChildren,
  }) {
    return TransactionFilter(
      ids: ids ?? this.ids,
      accountIds: accountIds ?? this.accountIds,
      categoryIds: categoryIds ?? this.categoryIds,
      payeeIds: payeeIds ?? this.payeeIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      minAbsAmount: minAbsAmount ?? this.minAbsAmount,
      maxAbsAmount: maxAbsAmount ?? this.maxAbsAmount,
      memoSearch: memoSearch ?? this.memoSearch,
      searchText: searchText ?? this.searchText,
      searchAmount: searchAmount ?? this.searchAmount,
      clearedStatuses: clearedStatuses ?? this.clearedStatuses,
      excludeSplitChildren: excludeSplitChildren ?? this.excludeSplitChildren,
    );
  }

  /// A copy with the free-text search replaced (both may be `null`).
  TransactionFilter withSearch(String? text, int? amount) => TransactionFilter(
    ids: ids,
    accountIds: accountIds,
    categoryIds: categoryIds,
    payeeIds: payeeIds,
    startDate: startDate,
    endDate: endDate,
    minAmount: minAmount,
    maxAmount: maxAmount,
    minAbsAmount: minAbsAmount,
    maxAbsAmount: maxAbsAmount,
    memoSearch: memoSearch,
    searchText: text,
    searchAmount: amount,
    clearedStatuses: clearedStatuses,
    excludeSplitChildren: excludeSplitChildren,
  );

  Map<String, dynamic> toJson() {
    return {
      if (ids != null) 'ids': ids,
      if (accountIds != null) 'accountIds': accountIds,
      if (categoryIds != null) 'categoryIds': categoryIds,
      if (payeeIds != null) 'payeeIds': payeeIds,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
      if (minAbsAmount != null) 'minAbsAmount': minAbsAmount,
      if (maxAbsAmount != null) 'maxAbsAmount': maxAbsAmount,
      if (memoSearch != null) 'memoSearch': memoSearch,
      if (clearedStatuses != null)
        'clearedStatuses': clearedStatuses!.map((e) => e.index).toList(),
    };
  }

  factory TransactionFilter.fromJson(Map<String, dynamic> json) {
    return TransactionFilter(
      ids: (json['ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
      accountIds: (json['accountIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      categoryIds: (json['categoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      payeeIds: (json['payeeIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      minAmount: (json['minAmount'] as num?)?.toInt(),
      maxAmount: (json['maxAmount'] as num?)?.toInt(),
      minAbsAmount: (json['minAbsAmount'] as num?)?.toInt(),
      maxAbsAmount: (json['maxAbsAmount'] as num?)?.toInt(),
      memoSearch: json['memoSearch'] as String?,
      clearedStatuses: (json['clearedStatuses'] as List<dynamic>?)
          ?.whereType<int>()
          .where((e) => e >= 0 && e < TransactionClearStatus.values.length)
          .map((e) => TransactionClearStatus.values[e])
          .toList(),
    );
  }
}
