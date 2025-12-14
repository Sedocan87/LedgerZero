import 'package:equatable/equatable.dart';

class ImportProfile extends Equatable {
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
  final DateTime createdAt;

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
  });

  ImportProfile copyWith({
    String? id,
    String? name,
    String? dateFormat,
    String? decimalSeparator,
    bool? outflowIsNegative,
    String? dateColumn,
    String? amountColumn,
    String? payeeColumn,
    String? memoColumn,
    String? categoryColumn,
    DateTime? createdAt,
  }) {
    return ImportProfile(
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
    );
  }

  @override
  List<Object?> get props => [
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
  ];
}
