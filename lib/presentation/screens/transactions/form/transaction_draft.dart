import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// The kind of transaction the form edits.
enum TransactionFormType { expense, income, transfer }

/// One split line of a [TransactionDraft].
class SplitDraft {
  const SplitDraft({this.id, this.amountText = '', this.categoryId, this.memo});

  /// Id of the existing child row, `null` for a new line.
  final String? id;

  /// The amount as typed (locale formatted, without sign).
  final String amountText;
  final String? categoryId;
  final String? memo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amountText,
    'categoryId': categoryId,
    'memo': memo,
  };

  factory SplitDraft.fromJson(Map<String, dynamic> json) => SplitDraft(
    id: json['id'] as String?,
    amountText: json['amount'] as String? ?? '',
    categoryId: json['categoryId'] as String?,
    memo: json['memo'] as String?,
  );
}

/// A pre-filled, unsaved transaction handed to the transaction form.
///
/// Used for the quick-add "Edit details" hand-off (passed as the route's
/// `extra`) and for the form's autosaved draft. Ids are resolved by the form
/// whenever the referenced lists load, so late-loading providers never lose
/// the payee, category or account.
class TransactionDraft {
  const TransactionDraft({
    this.amountText = '',
    this.memo,
    this.date,
    this.accountId,
    this.payeeId,
    this.payeeName,
    this.categoryId,
    this.formType = TransactionFormType.expense,
    this.transferAccountId,
    this.splits = const [],
    this.isRecurring = false,
    this.frequency = RecurrenceFrequency.monthly,
  });

  /// The amount as typed (locale formatted, without sign).
  final String amountText;
  final String? memo;

  /// Calendar day (UTC midnight).
  final DateTime? date;
  final String? accountId;
  final String? payeeId;

  /// Payee text when [payeeId] is not (yet) an existing payee.
  final String? payeeName;
  final String? categoryId;
  final TransactionFormType formType;
  final String? transferAccountId;
  final List<SplitDraft> splits;
  final bool isRecurring;
  final RecurrenceFrequency frequency;

  bool get isSplit => splits.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'amount': amountText,
    'memo': memo,
    'date': date?.toIso8601String(),
    'accountId': accountId,
    'payeeId': payeeId,
    'payeeName': payeeName,
    'categoryId': categoryId,
    'formType': formType.index,
    'transferAccountId': transferAccountId,
    'splits': [for (final s in splits) s.toJson()],
    'isRecurring': isRecurring,
    'frequency': frequency.index,
  };

  /// Reads a draft written by [toJson]; unknown or broken values fall back
  /// to defaults.
  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    T? pick<T>(List<T> values, Object? index) =>
        index is int && index >= 0 && index < values.length
        ? values[index]
        : null;
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    return TransactionDraft(
      amountText: json['amount'] as String? ?? '',
      memo: json['memo'] as String?,
      date: date == null ? null : CalendarDate.normalize(date),
      accountId: json['accountId'] as String?,
      payeeId: json['payeeId'] as String?,
      payeeName: json['payeeName'] as String?,
      categoryId: json['categoryId'] as String?,
      formType:
          pick(TransactionFormType.values, json['formType']) ??
          TransactionFormType.expense,
      transferAccountId: json['transferAccountId'] as String?,
      splits: [
        for (final s in (json['splits'] as List<dynamic>? ?? const []))
          if (s is Map<String, dynamic>) SplitDraft.fromJson(s),
      ],
      isRecurring: json['isRecurring'] as bool? ?? false,
      frequency:
          pick(RecurrenceFrequency.values, json['frequency']) ??
          RecurrenceFrequency.monthly,
    );
  }
}
