import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/import/models/mint_import_data.dart';
import 'package:uuid/uuid.dart';

/// Maps raw Mint import data to LedgerZero domain entities.
class MintDataMapper {
  final Uuid _uuid = const Uuid();

  /// Converts [MintImportData] into lists of domain entities.
  MintMappedData mapData(MintImportData data, {List<Category>? existingCategories}) {
    final accounts = <Account>[];
    final categoryGroups = <CategoryGroup>[];
    final categories = <Category>[];
    final payees = <Payee>[];
    final transactions = <Transaction>[];

    // 1. Map Accounts
    // Mint doesn't provide account IDs, so we use the name as a temporary ID or generate one.
    // For the mapper, we'll generate new IDs but keep a mapping from Name -> ID to link transactions.
    final accountNameIdMap = <String, String>{};

    for (final rawAcc in data.accounts) {
      final id = _uuid.v4();
      accountNameIdMap[rawAcc.name] = id;

      // Infer account type from name
      AccountType type = _inferAccountType(rawAcc.name);

      accounts.add(Account(
        id: id,
        name: rawAcc.name,
        type: type,
        startingBalance: 0.0, // Mint export doesn't have balances. User must reconcile.
        currentBalance: 0.0,
      ));
    }

    // 2. Map Categories
    // Strategy:
    // a. Check if category matches an existing one (case-insensitive).
    // b. If not, create new category in "Mint Import" group.

    final existingCategoryMap = <String, Category>{};
    if (existingCategories != null) {
      for (final cat in existingCategories) {
        existingCategoryMap[cat.name.toLowerCase()] = cat;
      }
    }

    String? mintImportGroupId;
    final categoryNameIdMap = <String, String>{};

    for (final catName in data.categories) {
      final lowerName = catName.toLowerCase();
      if (existingCategoryMap.containsKey(lowerName)) {
        // Map to existing category
        categoryNameIdMap[catName] = existingCategoryMap[lowerName]!.id;
      } else {
        // Create new category in "Mint Import" group
        if (mintImportGroupId == null) {
          mintImportGroupId = _uuid.v4();
          categoryGroups.add(CategoryGroup(
            id: mintImportGroupId,
            name: 'Mint Import',
            sortOrder: 0,
          ));
        }

        final id = _uuid.v4();
        categoryNameIdMap[catName] = id;
        categories.add(Category(
          id: id,
          name: catName,
          categoryGroupId: mintImportGroupId,
          goalType: GoalType.targetBalance,
          targetAmount: 0,
        ));
      }
    }

    // 3. Map Payees and Transactions
    final payeeNameIdMap = <String, String>{};

    for (final rawTx in data.transactions) {
       // Payee
       String payeeId;
       final payeeName = rawTx.description.trim();

       if (payeeNameIdMap.containsKey(payeeName)) {
         payeeId = payeeNameIdMap[payeeName]!;
       } else {
         payeeId = _uuid.v4();
         payeeNameIdMap[payeeName] = payeeId;
         payees.add(Payee(
           id: payeeId,
           name: payeeName,
           createdAt: DateTime.now(),
         ));
       }

       // Account
       final accountId = accountNameIdMap[rawTx.accountName];
       if (accountId == null) {
         // Should not happen if accounts were extracted correctly
         continue;
       }

       // Category
       // If category is "Transfer", "Credit Card Payment", etc., handle logic?
       // Mint transfers usually have category "Transfer".
       // In LedgerZero, transfers are linked transactions.
       // Handling transfers from CSV is hard without matching pairs.
       // For now, treat "Transfer" as a category or skip category if it's a transfer?
       // If we import as is, user can fix later.

       final categoryId = categoryNameIdMap[rawTx.category];

       // Labels to Memo
       String memo = rawTx.notes;
       if (rawTx.labels.isNotEmpty) {
         if (memo.isNotEmpty) memo += ' ';
         memo += '[Tags: ${rawTx.labels}]';
       }

       transactions.add(Transaction(
         id: _uuid.v4(),
         accountId: accountId,
         date: rawTx.date,
         amount: rawTx.amount,
         payeeId: payeeId,
         categoryId: categoryId, // Nullable in Transaction? Yes.
         memo: memo,
         cleared: TransactionClearStatus.cleared, // Assume imported are cleared
         approved: true,
         createdAt: DateTime.now(),
         updatedAt: DateTime.now(),
       ));
    }

    return MintMappedData(
      accounts: accounts,
      categoryGroups: categoryGroups,
      categories: categories,
      payees: payees,
      transactions: transactions,
    );
  }

  AccountType _inferAccountType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('credit') || lower.contains('card') || lower.contains('visa') || lower.contains('amex') || lower.contains('mastercard')) {
      return AccountType.credit;
    } else if (lower.contains('save') || lower.contains('savings')) {
      return AccountType.savings;
    } else if (lower.contains('cash')) {
      return AccountType.cash;
    } else if (lower.contains('investment') || lower.contains('brokerage') || lower.contains('ira') || lower.contains('401k')) {
       // LedgerZero doesn't have investment type explicitly in the enum list in memory,
       // but memory said "AccountType enum with values: checking, savings, credit, cash".
       // Wait, memory said "AccountType.checking, savings, credit, cash".
       // Implementation.md mentions "Investment (tracking only)" but maybe not in enum yet?
       // Let's check AccountType definition.
       return AccountType.savings; // Fallback or checking
    }
    return AccountType.checking;
  }
}

class MintMappedData {
  final List<Account> accounts;
  final List<CategoryGroup> categoryGroups;
  final List<Category> categories;
  final List<Payee> payees;
  final List<Transaction> transactions;

  MintMappedData({
    required this.accounts,
    required this.categoryGroups,
    required this.categories,
    required this.payees,
    required this.transactions,
  });
}
