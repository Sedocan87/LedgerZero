import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// Represents a raw account imported from YNAB
class YnabAccount {
  final String id; // Might be a name in CSV, or UUID in YNAB4
  final String name;
  final AccountType type;
  final bool onBudget;
  final bool isClosed;
  final String currency; // Default USD
  final double balance; // Only for initial import if no transactions? Usually calculated.

  YnabAccount({
    required this.id,
    required this.name,
    required this.type,
    this.onBudget = true,
    this.isClosed = false,
    this.currency = 'USD',
    this.balance = 0.0,
  });
}

/// Represents a raw transaction imported from YNAB
class YnabTransaction {
  final String id; // UUID or generated hash
  final String accountId;
  final DateTime date;
  final String? payeeName;
  final String? categoryGroupName;
  final String? categoryName;
  final String? memo;
  final double amount; // Net amount (Inflow - Outflow)
  final bool cleared;
  final bool reconciled;
  final String? transferAccountId; // If it's a transfer
  final String? importId; // YNAB specific

  // For splits
  final List<YnabSplitItem> splits;

  YnabTransaction({
    required this.id,
    required this.accountId,
    required this.date,
    this.payeeName,
    this.categoryGroupName,
    this.categoryName,
    this.memo,
    required this.amount,
    this.cleared = false,
    this.reconciled = false,
    this.transferAccountId,
    this.importId,
    this.splits = const [],
  });
}

class YnabScheduledTransaction {
  final String id;
  final String accountId;
  final String? payeeName;
  final String? categoryGroupName;
  final String? categoryName;
  final String? memo;
  final double amount;
  final RecurrenceFrequency frequency;
  final DateTime nextDate;
  final List<YnabSplitItem> splits;
  final String? transferAccountId;

  YnabScheduledTransaction({
    required this.id,
    required this.accountId,
    this.payeeName,
    this.categoryGroupName,
    this.categoryName,
    this.memo,
    required this.amount,
    required this.frequency,
    required this.nextDate,
    this.splits = const [],
    this.transferAccountId,
  });
}

class YnabSplitItem {
  final String? categoryGroupName;
  final String? categoryName;
  final String? memo;
  final double amount;
  final String? payeeName; // Sometimes splits have different payees in YNAB4

  YnabSplitItem({
    this.categoryGroupName,
    this.categoryName,
    this.memo,
    required this.amount,
    this.payeeName,
  });
}

class YnabCategoryGroup {
  final String id;
  final String name;
  final bool isHidden;

  YnabCategoryGroup({
    required this.id,
    required this.name,
    this.isHidden = false,
  });
}

class YnabCategory {
  final String id;
  final String groupId;
  final String name;
  final bool isHidden;

  YnabCategory({
    required this.id,
    required this.groupId,
    required this.name,
    this.isHidden = false,
  });
}

class YnabBudgetEntry {
  final String categoryName;
  final String categoryGroupName;
  final DateTime month;
  final double budgeted;

  YnabBudgetEntry({
    required this.categoryName,
    required this.categoryGroupName,
    required this.month,
    required this.budgeted,
  });
}

class YnabImportData {
  final List<YnabAccount> accounts;
  final List<YnabCategoryGroup> categoryGroups;
  final List<YnabCategory> categories;
  final List<YnabTransaction> transactions;
  final List<YnabScheduledTransaction> scheduledTransactions;
  final List<YnabBudgetEntry> budgetEntries;

  // Metadata
  final String source; // 'CSV' or 'YNAB4'
  final DateTime importedAt;

  YnabImportData({
    required this.accounts,
    required this.categoryGroups,
    required this.categories,
    required this.transactions,
    this.scheduledTransactions = const [],
    required this.budgetEntries,
    required this.source,
    required this.importedAt,
  });
}
