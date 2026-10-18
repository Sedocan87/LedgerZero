import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// Represents a raw account imported from YNAB
class YnabAccount {
  final String id; // Might be a name in CSV, or UUID in YNAB4
  final String name;
  final AccountType type;

  /// `false` for a YNAB tracking (off-budget) account, imported as an
  /// off-budget account (see `YnabDataMapper`). YNAB 4 states it; for the
  /// nYNAB CSV it is inferred and the user can change it in the preview.
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

  YnabAccount copyWith({bool? onBudget}) => YnabAccount(
    id: id,
    name: name,
    type: type,
    onBudget: onBudget ?? this.onBudget,
    isClosed: isClosed,
    balance: balance,
  );
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

  /// nYNAB CSV: the date format the register was read with, and every
  /// format that fits all of its dates (more than one when day and month
  /// are ambiguous; the user may switch).
  final String? registerDateFormat;
  final List<String> dateFormatCandidates;

  /// Categories that appear only in Budget.csv (no register row), created
  /// so their budgeted amounts are not lost.
  final int categoriesOnlyInBudget;

  /// SHA-256 of the export's content, to recognise a second import of the
  /// same file.
  final String? fingerprint;

  YnabImportData({
    required this.accounts,
    required this.categoryGroups,
    required this.categories,
    required this.transactions,
    this.scheduledTransactions = const [],
    required this.budgetEntries,
    required this.source,
    required this.importedAt,
    this.registerDateFormat,
    this.dateFormatCandidates = const [],
    this.categoriesOnlyInBudget = 0,
    this.fingerprint,
  });

  YnabImportData copyWith({List<YnabAccount>? accounts}) => YnabImportData(
    accounts: accounts ?? this.accounts,
    categoryGroups: categoryGroups,
    categories: categories,
    transactions: transactions,
    scheduledTransactions: scheduledTransactions,
    budgetEntries: budgetEntries,
    source: source,
    importedAt: importedAt,
    registerDateFormat: registerDateFormat,
    dateFormatCandidates: dateFormatCandidates,
    categoriesOnlyInBudget: categoriesOnlyInBudget,
    fingerprint: fingerprint,
  );

  /// The first and last transaction day, or `null` without transactions.
  ({DateTime first, DateTime last})? get dateRange {
    if (transactions.isEmpty) {
      return null;
    }
    var first = transactions.first.date;
    var last = first;
    for (final t in transactions) {
      if (t.date.isBefore(first)) {
        first = t.date;
      }
      if (t.date.isAfter(last)) {
        last = t.date;
      }
    }
    return (first: first, last: last);
  }
}
