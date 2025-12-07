import 'dart:convert';
import 'dart:io';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

/// Service responsible for parsing YNAB export files (CSV and YNAB4)
/// and converting them into intermediate data structures.
class YnabImportService {

  /// Parses nYNAB CSV export files.
  ///
  /// [registerCsvContent]: Content of the 'Register.csv' file.
  /// [budgetCsvContent]: Content of the 'Budget.csv' file.
  Future<YnabImportData> parseCsvExport({
    required String registerCsvContent,
    required String budgetCsvContent,
  }) async {
    final transactions = <YnabTransaction>[];
    final accounts = <YnabAccount>[];
    final categoryGroups = <YnabCategoryGroup>[];
    final categories = <YnabCategory>[];
    final budgetEntries = <YnabBudgetEntry>[];

    String? detectEol(String content) {
      if (content.contains('\r\n')) return '\r\n';
      if (content.contains('\n')) return '\n';
      if (content.contains('\r')) return '\r';
      return null;
    }

    // 1. Parse Register CSV
    final regEol = detectEol(registerCsvContent);
    final registerRows = const CsvToListConverter().convert(
        registerCsvContent,
        shouldParseNumbers: false,
        eol: regEol,
    );

    if (registerRows.isNotEmpty) {
       final headers = registerRows.first.map((e) => e.toString()).toList();
       final rows = registerRows.skip(1).toList();

       // Index headers
       final accIdx = headers.indexOf('Account');
       final dateIdx = headers.indexOf('Date');
       final payeeIdx = headers.indexOf('Payee');
       final groupIdx = headers.indexOf('Category Group');
       final catIdx = headers.indexOf('Category');
       final memoIdx = headers.indexOf('Memo');
       final outflowIdx = headers.indexOf('Outflow');
       final inflowIdx = headers.indexOf('Inflow');
       final clearedIdx = headers.indexOf('Cleared');

       final missingColumns = <String>[];
       if (accIdx == -1) missingColumns.add('Account');
       if (dateIdx == -1) missingColumns.add('Date');
       if (payeeIdx == -1) missingColumns.add('Payee');
       if (outflowIdx == -1) missingColumns.add('Outflow');
       if (inflowIdx == -1) missingColumns.add('Inflow');

       if (missingColumns.isNotEmpty) {
         throw Exception('Invalid YNAB Register CSV format: Missing required columns: ${missingColumns.join(', ')}');
       }

       // Track unique entities to avoid duplicates in list
       final accountNames = <String>{};
       final categoryKeys = <String>{}; // "Group|Category"

       for (final row in rows) {
          if (row.length < headers.length) continue;

          final accName = row[accIdx].toString();
          if (accountNames.add(accName)) {
            accounts.add(YnabAccount(
              id: accName, // Use name as ID for CSV import
              name: accName,
              type: mapAccountType(accName), // Heuristic based on name
            ));
          }

          final dateStr = row[dateIdx].toString();
          DateTime date;
          try {
             // Try standard formats
             if (dateStr.contains('/')) {
                // MM/DD/YYYY or DD/MM/YYYY?
                // YNAB export usually follows locale or MM/DD/YYYY.
                // We'll try common ones.
                try {
                  date = DateFormat('MM/dd/yyyy').parse(dateStr);
                } catch (_) {
                  date = DateFormat('dd/MM/yyyy').parse(dateStr);
                }
             } else {
               date = DateTime.parse(dateStr);
             }
          } catch (e) {
             Logger.warning('Failed to parse date: $dateStr');
             continue;
          }

          final payee = row[payeeIdx].toString();
          final group = groupIdx != -1 ? row[groupIdx].toString() : '';
          final category = catIdx != -1 ? row[catIdx].toString() : '';
          final memo = memoIdx != -1 ? row[memoIdx].toString() : '';

          // Parse amounts (currency string handling)
          double parseAmount(dynamic val) {
            String s = val.toString();
            // Remove currency symbols
            s = s.replaceAll(RegExp(r'[^\d.,-]'), '');

            if (s.contains('.') && s.contains(',')) {
               if (s.lastIndexOf('.') > s.lastIndexOf(',')) {
                  // 1,000.50 -> Remove commas
                  s = s.replaceAll(',', '');
               } else {
                  // 1.000,50 -> Remove dots, replace comma with dot
                  s = s.replaceAll('.', '').replaceAll(',', '.');
               }
            } else if (s.contains(',')) {
               s = s.replaceAll(',', '.'); // 12,34 -> 12.34
            }
            return double.tryParse(s) ?? 0.0;
          }

          final outflow = parseAmount(row[outflowIdx]);
          final inflow = parseAmount(row[inflowIdx]);
          final amount = inflow - outflow;

          final clearedStr = clearedIdx != -1 ? row[clearedIdx].toString() : 'U';
          final cleared = clearedStr == 'C' || clearedStr == 'R';
          final reconciled = clearedStr == 'R';

          // Handle categories
          if (group.isNotEmpty && category.isNotEmpty) {
             final key = '$group|$category';
             if (categoryKeys.add(key)) {
                // Determine if group exists
                var grp = categoryGroups.firstWhere((g) => g.name == group, orElse: () => YnabCategoryGroup(id: group, name: group));
                if (!categoryGroups.contains(grp)) categoryGroups.add(grp);

                categories.add(YnabCategory(
                  id: key,
                  groupId: group,
                  name: category,
                ));
             }
          }

          transactions.add(YnabTransaction(
            id: 'TX_${transactions.length}', // Generate generic ID
            accountId: accName,
            date: date,
            payeeName: payee,
            categoryGroupName: group,
            categoryName: category,
            memo: memo,
            amount: amount,
            cleared: cleared,
            reconciled: reconciled,
          ));
       }
    }

    // 2. Parse Budget CSV
    final budgetEol = detectEol(budgetCsvContent);
    final budgetRows = const CsvToListConverter().convert(
        budgetCsvContent,
        shouldParseNumbers: false,
        eol: budgetEol,
    );

    if (budgetRows.isNotEmpty) {
       final headers = budgetRows.first.map((e) => e.toString()).toList();
       final rows = budgetRows.skip(1).toList();

       final monthIdx = headers.indexOf('Month');
       final groupIdx = headers.indexOf('Category Group');
       final catIdx = headers.indexOf('Category');
       final budgetedIdx = headers.indexOf('Budgeted');

       if (monthIdx != -1 && groupIdx != -1 && catIdx != -1 && budgetedIdx != -1) {
          for (final row in rows) {
             if (row.length < headers.length) continue;

             final monthStr = row[monthIdx].toString();
             DateTime month;
             try {
                // "Jan 2023" or "01/01/2023"
                if (monthStr.contains('/')) {
                   month = DateFormat('MM/dd/yyyy').parse(monthStr); // Assume 1st of month?
                } else {
                   // Try "MMM yyyy"
                   try {
                     month = DateFormat('MMM yyyy').parse(monthStr);
                   } catch (_) {
                     // Try "MMM-yy" ?
                     month = DateTime.parse(monthStr); // ISO fallback
                   }
                }
             } catch (_) {
               continue;
             }

             final group = row[groupIdx].toString();
             final category = row[catIdx].toString();

             // Parse budgeted amount similar to transaction amount
             // Re-implement parse logic for budgeted (duplicated)
             String s = row[budgetedIdx].toString();
             s = s.replaceAll(RegExp(r'[^\d.,-]'), '');
             if (s.contains('.') && s.contains(',')) {
                if (s.lastIndexOf('.') > s.lastIndexOf(',')) {
                  s = s.replaceAll(',', '');
                } else {
                  s = s.replaceAll('.', '').replaceAll(',', '.');
                }
             } else if (s.contains(',')) {
                s = s.replaceAll(',', '.');
             }
             final budgeted = double.tryParse(s) ?? 0.0;

             if (budgeted != 0) {
               budgetEntries.add(YnabBudgetEntry(
                 categoryName: category,
                 categoryGroupName: group,
                 month: month,
                 budgeted: budgeted,
               ));
             }
          }
       }
    }

    return YnabImportData(
      accounts: accounts,
      categoryGroups: categoryGroups,
      categories: categories,
      transactions: transactions,
      budgetEntries: budgetEntries,
      source: 'CSV',
      importedAt: DateTime.now(),
    );
  }

  /// Parses a legacy YNAB4 budget folder.
  ///
  /// [folderPath]: Path to the .ynab4 directory.
  Future<YnabImportData> parseYnab4(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw Exception('YNAB4 directory not found: $folderPath');
    }

    // 1. Locate Budget.ymeta to find current version
    final metaFile = File(path.join(folderPath, 'Budget.ymeta'));
    if (!await metaFile.exists()) {
      throw Exception('Invalid YNAB4 bundle: Budget.ymeta missing');
    }

    // 2. Find the data folder (usually data1-{GUID})
    String? dataFolderPath;
    await for (final entity in dir.list()) {
      if (entity is Directory && path.basename(entity.path).startsWith('data')) {
        dataFolderPath = entity.path;
        break;
      }
    }

    if (dataFolderPath == null) {
       throw Exception('Could not find data folder in YNAB4 bundle');
    }

    // 3. Find the full budget file (Budget.yfull) inside the device folder
    File? yfullFile;
    final dataDir = Directory(dataFolderPath);

    await for (final entity in dataDir.list()) {
      if (entity is Directory) {
         final potentialFile = File(path.join(entity.path, 'Budget.yfull'));
         if (await potentialFile.exists()) {
           yfullFile = potentialFile;
           break;
         }
      }
    }

    if (yfullFile == null) {
      throw Exception('Budget.yfull not found');
    }

    final content = await yfullFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    return _parseYnab4Json(json);
  }

  YnabImportData _parseYnab4Json(Map<String, dynamic> json) {
    // YNAB4 JSON Structure:
    // {
    //   "accounts": [...],
    //   "payees": [...],
    //   "masterCategories": [...], // Groups
    //   "subCategories": [...],    // Categories
    //   "transactions": [...],
    //   "subTransactions": [...],  // Splits
    //   "monthlyBudgets": [...],   // Budget allocations
    //   "scheduledTransactions": [...],
    //   ...
    // }

    final accounts = <YnabAccount>[];
    final categoryGroups = <YnabCategoryGroup>[];
    final categories = <YnabCategory>[];
    final transactions = <YnabTransaction>[];
    final scheduledTransactions = <YnabScheduledTransaction>[];
    final budgetEntries = <YnabBudgetEntry>[];

    // 1. Accounts
    for (final acc in (json['accounts'] as List? ?? [])) {
       if (acc['isTombstone'] == true) continue;

       accounts.add(YnabAccount(
         id: acc['entityId'],
         name: acc['accountName'],
         type: _mapYnab4AccountType(acc['accountType']),
         onBudget: acc['onBudget'] ?? true,
         isClosed: acc['hidden'] ?? false,
       ));
    }

    // 2. Payees (Need to map Payee ID -> Name)
    final payeeMap = <String, String>{}; // id -> name
    for (final payee in (json['payees'] as List? ?? [])) {
      if (payee['isTombstone'] == true) continue;
      payeeMap[payee['entityId']] = payee['name'];
    }

    // 3. Categories
    final groupMap = <String, String>{}; // id -> name

    for (final master in (json['masterCategories'] as List? ?? [])) {
      if (master['isTombstone'] == true) continue;

      final group = YnabCategoryGroup(
        id: master['entityId'],
        name: master['name'],
        isHidden: master['isHidden'] ?? false,
      );
      categoryGroups.add(group);
      groupMap[group.id] = group.name;
    }

    final categoryMap = <String, YnabCategory>{}; // id -> Category

    for (final sub in (json['subCategories'] as List? ?? [])) {
      if (sub['isTombstone'] == true) continue;

      final category = YnabCategory(
        id: sub['entityId'],
        groupId: sub['masterCategoryId'],
        name: sub['name'],
        isHidden: false, // YNAB4 hides categories?
      );
      categories.add(category);
      categoryMap[category.id] = category;
    }

    // 4. Transactions & Splits
    // First, index splits by parentId
    final splitsByParent = <String, List<YnabSplitItem>>{};
    for (final split in (json['subTransactions'] as List? ?? [])) {
       if (split['isTombstone'] == true) continue;
       final parentId = split['entitiesTransactionId'];
       final catId = split['categoryId'];
       final cat = categoryMap[catId];

       final item = YnabSplitItem(
         categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
         categoryName: cat?.name,
         amount: (split['amount'] as num).toDouble(),
         memo: split['memo'],
         payeeName: null, // YNAB4 splits don't have separate payees usually
       );

       splitsByParent.putIfAbsent(parentId, () => []).add(item);
    }

    for (final tx in (json['transactions'] as List? ?? [])) {
      if (tx['isTombstone'] == true) continue;

      final catId = tx['categoryId'];
      final cat = categoryMap[catId];
      final splitItems = splitsByParent[tx['entityId']] ?? [];
      final payeeName = payeeMap[tx['payeeId']];

      String? transferAccountId = tx['targetAccountId'];

      transactions.add(YnabTransaction(
        id: tx['entityId'],
        accountId: tx['accountId'],
        date: DateTime.parse(tx['date']),
        payeeName: payeeName,
        categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
        categoryName: cat?.name,
        amount: (tx['amount'] as num).toDouble(),
        memo: tx['memo'],
        cleared: tx['cleared'] == 'Cleared' || tx['cleared'] == 'Reconciled',
        reconciled: tx['cleared'] == 'Reconciled',
        transferAccountId: transferAccountId,
        splits: splitItems,
      ));
    }

    // 5. Scheduled Transactions
    for (final sch in (json['scheduledTransactions'] as List? ?? [])) {
      if (sch['isTombstone'] == true) continue;

      final catId = sch['categoryId'];
      final cat = categoryMap[catId];
      final payeeName = payeeMap[sch['payeeId']];

      RecurrenceFrequency frequency = RecurrenceFrequency.monthly; // Default
      final freqStr = sch['frequency'];
      // Mapping: Daily, Weekly, EveryOtherWeek, TwiceAMonth, Every4Weeks, Monthly, EveryOtherMonth, Every3Months, Every4Months, TwiceAYear, Yearly, EveryOtherYear
      if (freqStr == 'Daily') frequency = RecurrenceFrequency.daily;
      else if (freqStr == 'Weekly') frequency = RecurrenceFrequency.weekly;
      else if (freqStr == 'Monthly') frequency = RecurrenceFrequency.monthly;
      else if (freqStr == 'Yearly') frequency = RecurrenceFrequency.yearly;
      // Others map to nearest or monthly? LedgerZero supports daily, weekly, monthly, yearly.

      scheduledTransactions.add(YnabScheduledTransaction(
        id: sch['entityId'],
        accountId: sch['accountId'],
        payeeName: payeeName,
        categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
        categoryName: cat?.name,
        memo: sch['memo'],
        amount: (sch['amount'] as num).toDouble(),
        frequency: frequency,
        nextDate: DateTime.parse(sch['date']), // The next occurrence
        transferAccountId: sch['targetAccountId'],
      ));
    }

    // 6. Budget entries (monthlyBudgets)
    // Structure: { month: "2023-01-01", monthlySubCategoryBudgets: [...] }
    for (final mb in (json['monthlyBudgets'] as List? ?? [])) {
      if (mb['isTombstone'] == true) continue;

      final monthStr = mb['month']; // "2023-01-01"
      final month = DateTime.parse(monthStr);

      for (final subBudget in (mb['monthlySubCategoryBudgets'] as List? ?? [])) {
         if (subBudget['isTombstone'] == true) continue;

         final catId = subBudget['categoryId'];
         final cat = categoryMap[catId];
         if (cat == null) continue;

         final budgeted = (subBudget['budgeted'] as num).toDouble();

         budgetEntries.add(YnabBudgetEntry(
           categoryName: cat.name,
           categoryGroupName: groupMap[cat.groupId] ?? 'Unknown',
           month: month,
           budgeted: budgeted,
         ));
      }
    }

    return YnabImportData(
      accounts: accounts,
      categoryGroups: categoryGroups,
      categories: categories,
      transactions: transactions,
      scheduledTransactions: scheduledTransactions,
      budgetEntries: budgetEntries,
      source: 'YNAB4',
      importedAt: DateTime.now(),
    );
  }

  AccountType _mapYnab4AccountType(String type) {
    // YNAB4 types: Checking, Savings, CreditCard, Cash, LineOfCredit, MerchantAccount, PayPal, InvestmentAccount, Mortgage, OtherAsset, OtherLiability
    switch (type) {
      case 'Checking':
        return AccountType.checking;
      case 'Savings':
        return AccountType.savings;
      case 'CreditCard':
      case 'LineOfCredit':
        return AccountType.credit;
      case 'Cash':
      case 'MerchantAccount':
      case 'PayPal':
        return AccountType.cash;
      default:
        return AccountType.checking; // Default
    }
  }

  /// Helper to map YNAB account types to LedgerZero AccountType
  static AccountType mapAccountType(String ynabType) {
      final normalized = ynabType.toLowerCase().trim();
      if (normalized.contains('checking')) return AccountType.checking;
      if (normalized.contains('saving')) return AccountType.savings;
      if (normalized.contains('credit')) return AccountType.credit;
      if (normalized.contains('card')) return AccountType.credit;
      if (normalized.contains('cash')) return AccountType.cash;
      return AccountType.checking; // Default
  }
}
