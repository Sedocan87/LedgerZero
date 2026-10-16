import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// Represents a raw account imported from YNAB
class YnabAccount {
  final String id; // Might be a name in CSV, or UUID in YNAB4
  final String name;
  final AccountType type;

  /// `false` for a YNAB tracking (off-budget) account, which is not
  /// imported (see `YnabDataMapper`).
  final bool onBudget;
  final bool isClosed;

  /// Minor units. Only for initial import if no transactions; usually
  /// calculated.
  final int balance;

  YnabAccount({
    required this.id,
    required this.name,
    required this.type,
    this.onBudget = true,
    this.isClosed = false,
    this.balance = 0,
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
  final int amount; // Net amount (Inflow - Outflow), minor units
  final bool cleared;
  final bool reconciled;

  /// For a transfer leg: the [YnabAccount.id] of the other account (the
  /// YNAB4 `targetAccountId`; for the CSV register the account name parsed
  /// from the `Transfer : <Account>` payee). `null` for other rows.
  final String? transferAccountId;
  final String? importId; // YNAB specific

  /// The split lines of a split transaction (empty otherwise). A split is
  /// imported as a parent row carrying [amount] and no category, plus one
  /// child per line; see `YnabDataMapper`.
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
  final int amount; // minor units
  final RecurrenceFrequency frequency;

  /// Repeat every [interval] periods of [frequency] (YNAB4 "EveryOtherWeek"
  /// is weekly with interval 2).
  final int interval;

  /// Number of occurrences, or `null` for no limit (YNAB4 "Never" means a
  /// one-off scheduled transaction: 1).
  final int? occurrenceCount;
  final DateTime nextDate;
  final List<YnabSplitItem> splits;

  /// For a scheduled transfer: the [YnabAccount.id] of the other account.
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
    this.interval = 1,
    this.occurrenceCount,
    required this.nextDate,
    this.splits = const [],
    this.transferAccountId,
  });
}

class YnabSplitItem {
  final String? categoryGroupName;
  final String? categoryName;
  final String? memo;
  final int amount; // minor units
  /// The line's own payee when it differs from the parent's (nYNAB split
  /// lines can have their own payee), otherwise `null`.
  final String? payeeName;

  /// When the line is a transfer: the [YnabAccount.id] of the other account
  /// (YNAB4 `targetAccountId`; for the nYNAB CSV the account name from a
  /// `Transfer : <Account>` payee). LedgerZero split children cannot be
  /// transfer legs, so such a line is imported as an uncategorised child
  /// whose memo names the transfer; see `YnabDataMapper`.
  final String? transferAccountId;

  YnabSplitItem({
    this.categoryGroupName,
    this.categoryName,
    this.memo,
    required this.amount,
    this.payeeName,
    this.transferAccountId,
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
  final int budgeted; // minor units

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
