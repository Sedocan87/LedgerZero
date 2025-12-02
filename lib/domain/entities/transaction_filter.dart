import 'package:ledger_zero/domain/entities/transaction.dart';

enum TransactionSortField {
  date,
  amount,
  payeeName,
  categoryName,
}

class TransactionSort {
  final TransactionSortField field;
  final bool ascending;

  const TransactionSort({
    required this.field,
    this.ascending = true,
  });
}

class TransactionFilter {
  final List<String>? ids;
  final List<String>? accountIds;
  final List<String>? categoryIds;
  final List<String>? payeeIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String? memoSearch;
  final List<TransactionClearStatus>? clearedStatuses;

  const TransactionFilter({
    this.ids,
    this.accountIds,
    this.categoryIds,
    this.payeeIds,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.memoSearch,
    this.clearedStatuses,
  });

  TransactionFilter copyWith({
    List<String>? ids,
    List<String>? accountIds,
    List<String>? categoryIds,
    List<String>? payeeIds,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? memoSearch,
    List<TransactionClearStatus>? clearedStatuses,
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
      memoSearch: memoSearch ?? this.memoSearch,
      clearedStatuses: clearedStatuses ?? this.clearedStatuses,
    );
  }

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
      startDate:
          json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      minAmount: (json['minAmount'] as num?)?.toDouble(),
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      memoSearch: json['memoSearch'] as String?,
      clearedStatuses: (json['clearedStatuses'] as List<dynamic>?)
          ?.map((e) => TransactionClearStatus.values[e as int])
          .toList(),
    );
  }
}
