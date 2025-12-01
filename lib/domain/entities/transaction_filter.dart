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
}
