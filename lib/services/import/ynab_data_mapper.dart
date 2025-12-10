import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class YnabDataMapper {
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final PayeeRepository _payeeRepo;
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;
  final ScheduledTransactionRepository _scheduledTransactionRepo;

  YnabDataMapper({
    required AccountRepository accountRepo,
    required CategoryRepository categoryRepo,
    required PayeeRepository payeeRepo,
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
    required ScheduledTransactionRepository scheduledTransactionRepo,
  })  : _accountRepo = accountRepo,
        _categoryRepo = categoryRepo,
        _payeeRepo = payeeRepo,
        _transactionRepo = transactionRepo,
        _budgetRepo = budgetRepo,
        _scheduledTransactionRepo = scheduledTransactionRepo;

  Future<void> importData(YnabImportData data) async {
    Logger.info('Starting YNAB import...');

    // 1. Categories & Groups
    final categoryNameMap = await _importCategories(data); // Returns "Group:Category" -> LZ ID

    // 2. Accounts
    final accountIdMap = await _importAccounts(data);

    // 3. Transactions (and Payees)
    await _importTransactions(data, accountIdMap, categoryNameMap);

    // 4. Scheduled Transactions
    await _importScheduledTransactions(data, accountIdMap, categoryNameMap);

    // 5. Budget Allocations
    await _importBudgets(data, categoryNameMap);

    Logger.info('YNAB import completed.');
  }

  /// Returns a map of "CategoryGroupName:CategoryName" -> CategoryID
  Future<Map<String, String>> _importCategories(YnabImportData data) async {
    final existingGroups = await _categoryRepo.getAllCategoryGroups();
    final groupNameMap = {for (var g in existingGroups) g.name: g.id};

    // 1. Groups
    for (final yGroup in data.categoryGroups) {
      if (yGroup.name == 'Internal Master Category') {
        continue;
      }
      if (yGroup.isHidden) {
        continue;
      }

      if (!groupNameMap.containsKey(yGroup.name)) {
        final groupId = const Uuid().v4();
        await _categoryRepo.createCategoryGroup(CategoryGroup(
          id: groupId,
          name: yGroup.name,
          sortOrder: 0,
          createdAt: DateTime.now(),
        ));
        groupNameMap[yGroup.name] = groupId;
      }
    }

    // 2. Categories
    final existingCategories = await _categoryRepo.getAllCategories();
    // Need group ID to Name map
    final groupIdToName = {for (var g in existingGroups) g.id: g.name};
    // Update with newly created groups if we can refetch or just trust local map
    groupNameMap.forEach((name, id) => groupIdToName[id] = name);

    final catNameMap = <String, String>{};
    for (var c in existingCategories) {
       if (c.categoryGroupId != null) {
          final gName = groupIdToName[c.categoryGroupId!];
          if (gName != null) {
             catNameMap['$gName:${c.name}'] = c.id;
          }
       }
    }

    for (final yCat in data.categories) {
      final sourceGroup = data.categoryGroups.firstWhere(
        (g) => g.id == yCat.groupId,
        orElse: () => YnabCategoryGroup(id: '', name: ''),
      );
      if (sourceGroup.name.isEmpty) {
        continue;
      }

      if (yCat.name == 'Uncategorized' || yCat.name.startsWith('Inflow:')) {
        continue;
      }

      final targetGroupId = groupNameMap[sourceGroup.name];
      if (targetGroupId == null) {
        continue;
      }

      final key = '${sourceGroup.name}:${yCat.name}';

       if (!catNameMap.containsKey(key)) {
         final catId = const Uuid().v4();
         await _categoryRepo.createCategory(Category(
           id: catId,
           name: yCat.name,
           categoryGroupId: targetGroupId,
           isHidden: yCat.isHidden,
           color: 0xFF000000,
           icon: null, // Icon is String? in Category
           createdAt: DateTime.now(),
           goalType: null,
           targetAmount: null,
           targetDate: null,
         ));
         catNameMap[key] = catId;
       }
    }

    return catNameMap;
  }

  Future<Map<String, String>> _importAccounts(YnabImportData data) async {
    final mapping = <String, String>{};

    final existingAccounts = await _accountRepo.getAllAccounts();
    final accNameMap = {for (var a in existingAccounts) a.name: a.id};

    for (final yAcc in data.accounts) {
      if (yAcc.isClosed && yAcc.balance == 0) {
        continue;
      }

      String accId;
      if (accNameMap.containsKey(yAcc.name)) {
        accId = accNameMap[yAcc.name]!;
      } else {
        accId = const Uuid().v4();
        await _accountRepo.createAccount(Account(
          id: accId,
          name: yAcc.name,
          type: yAcc.type,
          currency: yAcc.currency,
          startingBalance: 0,
          currentBalance: 0,
          isClosed: yAcc.isClosed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        accNameMap[yAcc.name] = accId;
      }
      mapping[yAcc.id] = accId;
    }
    return mapping;
  }

  Future<void> _importTransactions(
    YnabImportData data,
    Map<String, String> accountMap,
    Map<String, String> categoryNameMap,
  ) async {
    final existingPayees = await _payeeRepo.getAllPayees();
    final payeeNameMap = {for (var p in existingPayees) p.name.toLowerCase(): p.id};

    Future<String?> getPayeeId(String? name) async {
      if (name == null || name.isEmpty) {
        return null;
      }
      final lower = name.toLowerCase();
      if (payeeNameMap.containsKey(lower)) {
        return payeeNameMap[lower]!;
      }

      final id = const Uuid().v4();
       await _payeeRepo.createPayee(Payee(id: id, name: name, createdAt: DateTime.now()));
       payeeNameMap[lower] = id;
       return id;
    }

    final transactionsToInsert = <Transaction>[];

    for (final tx in data.transactions) {
      final accId = accountMap[tx.accountId];
      if (accId == null) {
        continue;
      }

      final payeeId = await getPayeeId(tx.payeeName);

       String? catId;
       if (tx.categoryGroupName != null && tx.categoryName != null) {
          final key = '${tx.categoryGroupName}:${tx.categoryName}';
          catId = categoryNameMap[key];
       }

       if (tx.splits.isNotEmpty) {
          // Parent transaction
          final parentId = const Uuid().v4();

          transactionsToInsert.add(Transaction(
            id: parentId,
            accountId: accId,
            date: tx.date,
            amount: tx.amount,
            payeeId: payeeId,
            categoryId: null,
            memo: tx.memo,
            cleared: tx.reconciled ? TransactionClearStatus.reconciled : (tx.cleared ? TransactionClearStatus.cleared : TransactionClearStatus.uncleared),
            approved: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));

          // Insert Children
          for (final split in tx.splits) {
             String? splitCatId;
             if (split.categoryGroupName != null && split.categoryName != null) {
                final key = '${split.categoryGroupName}:${split.categoryName}';
                splitCatId = categoryNameMap[key];
             }

             final splitPayeeId = await getPayeeId(split.payeeName) ?? payeeId;

             transactionsToInsert.add(Transaction(
               id: const Uuid().v4(),
               accountId: accId,
               date: tx.date,
               amount: split.amount,
               payeeId: splitPayeeId,
               categoryId: splitCatId,
               memo: split.memo,
               cleared: tx.reconciled ? TransactionClearStatus.reconciled : (tx.cleared ? TransactionClearStatus.cleared : TransactionClearStatus.uncleared),
               approved: true,
               parentTransactionId: parentId,
               createdAt: DateTime.now(),
               updatedAt: DateTime.now(),
             ));
          }
       } else {
          String? transferAccId;
          if (tx.transferAccountId != null) {
             transferAccId = accountMap[tx.transferAccountId];
          }

          transactionsToInsert.add(Transaction(
            id: const Uuid().v4(),
            accountId: accId,
            date: tx.date,
            amount: tx.amount,
            payeeId: payeeId,
            categoryId: catId,
            memo: tx.memo,
            cleared: tx.reconciled ? TransactionClearStatus.reconciled : (tx.cleared ? TransactionClearStatus.cleared : TransactionClearStatus.uncleared),
            approved: true,
            transferAccountId: transferAccId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
       }
    }

    // Batch insert
    await _transactionRepo.batchCreateTransactions(transactionsToInsert);
  }

  Future<void> _importScheduledTransactions(
      YnabImportData data,
      Map<String, String> accountMap,
      Map<String, String> categoryNameMap
  ) async {
      final toInsert = <ScheduledTransaction>[];
      final existingPayees = await _payeeRepo.getAllPayees();
      final payeeNameMap = {for (var p in existingPayees) p.name.toLowerCase(): p.id};

      Future<String?> getPayeeId(String? name) async {
        if (name == null || name.isEmpty) {
          return null;
        }
        final lower = name.toLowerCase();
        if (payeeNameMap.containsKey(lower)) {
          return payeeNameMap[lower]!;
        }
        final id = const Uuid().v4();
        await _payeeRepo.createPayee(
          Payee(id: id, name: name, createdAt: DateTime.now()),
        );
         payeeNameMap[lower] = id;
         return id;
      }

      for (final sch in data.scheduledTransactions) {
        final accId = accountMap[sch.accountId];
        if (accId == null) {
          continue;
        }

        final payeeId = await getPayeeId(sch.payeeName);

         String? catId;
         if (sch.categoryGroupName != null && sch.categoryName != null) {
            final key = '${sch.categoryGroupName}:${sch.categoryName}';
            catId = categoryNameMap[key];
         }

         toInsert.add(ScheduledTransaction(
           id: const Uuid().v4(),
           accountId: accId,
           payeeId: payeeId,
           categoryId: catId,
           amount: sch.amount,
           frequency: sch.frequency,
           nextDate: sch.nextDate,
           endDate: null,
           autoApprove: false,
           createdAt: DateTime.now(),
         ));
      }

      for (final st in toInsert) {
         await _scheduledTransactionRepo.createScheduledTransaction(st);
      }
  }

  Future<void> _importBudgets(YnabImportData data, Map<String, String> categoryNameMap) async {
    for (final entry in data.budgetEntries) {
      final key = '${entry.categoryGroupName}:${entry.categoryName}';
      final catId = categoryNameMap[key];
      if (catId == null) {
        continue;
      }

      // Use DateFormat for string key
        final monthStr = DateFormat('yyyy-MM').format(entry.month);

        // Check if budget exists
        final existing = await _budgetRepo.getBudgetByCategoryAndMonth(catId, monthStr);
        if (existing != null) {
           await _budgetRepo.updateBudget(existing.copyWith(budgeted: entry.budgeted));
        } else {
           await _budgetRepo.createBudget(Budget(
             id: const Uuid().v4(),
             categoryId: catId,
             month: monthStr,
             budgeted: entry.budgeted,
             activity: 0,
             available: 0,
             createdAt: DateTime.now(),
             updatedAt: DateTime.now(),
           ));
        }
     }
  }
}
