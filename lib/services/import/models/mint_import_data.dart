import 'package:ledger_zero/domain/entities/account.dart';

/// Represents a raw account extracted from Mint CSV
class MintAccount {
  final String name; // Mint CSV only provides "Account Name"
  final AccountType type; // Inferred from transactions

  MintAccount({required this.name, required this.type});
}

/// Represents a raw transaction imported from Mint
class MintTransaction {
  final DateTime date;
  final String description; // Payee
  final String originalDescription;
  final double amount;
  final String transactionType; // debit, credit
  final String category; // Mint category name
  final String accountName;
  final String labels;
  final String notes;

  MintTransaction({
    required this.date,
    required this.description,
    required this.originalDescription,
    required this.amount,
    required this.transactionType,
    required this.category,
    required this.accountName,
    required this.labels,
    required this.notes,
  });
}

/// Represents the collected data from a Mint export
class MintImportData {
  final List<MintAccount> accounts;
  final List<String> categories; // Unique category names found
  final List<MintTransaction> transactions;
  final DateTime importedAt;

  MintImportData({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.importedAt,
  });
}
