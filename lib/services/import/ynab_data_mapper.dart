import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:uuid/uuid.dart';

/// Writes parsed YNAB data ([YnabImportData]) into LedgerZero.
///
/// The whole import runs in one [UnitOfWork]: it is committed completely or
/// not at all. The result follows the budget rule (decision D3):
///
/// * Every on-budget account is imported, closed ones as closed accounts
///   with their transactions, so history and transfer counterparts are
///   complete. All new accounts get the currency passed to [importData]
///   (the user's choice on the import screen, default: the app's default
///   currency); YNAB exports carry no currency.
/// * Tracking (off-budget) accounts are not imported (yet; LedgerZero has
///   off-budget accounts since schema v19, see ROADMAP.md). Their own
///   transactions are skipped. A transfer between an
///   on-budget and a tracking account is the moment money leaves or enters
///   the budget, so its on-budget leg is imported as a normal row: with
///   YNAB's category if it had one (YNAB requires one for such outflows),
///   otherwise uncategorised (counting towards To Be Budgeted); its memo
///   names the transfer. [YnabImportSummary.trackingAccountsSkipped] reports
///   how many accounts were left out.
/// * Hidden YNAB category groups and categories are imported as hidden
///   categories (groups cannot be hidden in LedgerZero, so every category of
///   a hidden group is hidden), so their transactions keep their category.
/// * Accounts are created with a starting balance of 0. YNAB's own
///   "Starting Balance" row (category "Inflow: Ready to Assign" /
///   "Inflow: To be Budgeted") is imported as an uncategorised transaction,
///   so it counts towards To Be Budgeted exactly once; a credit card's
///   negative starting balance reduces it the same way.
/// * Transfers become two legs linked both ways (decision D4); see
///   [_pairTransfers]. A transfer row whose other leg is missing (e.g. its
///   account was skipped) or that carries a category is imported as a
///   normal row without a transfer link.
/// * A split becomes a parent (account-side amount, no category, no
///   transfer link) plus one child per line. Children always add up to
///   their parent; a difference is put into an uncategorised child.
///   LedgerZero split children cannot be transfer legs, so a split line
///   that is a YNAB transfer becomes an uncategorised child whose memo
///   names the transfer ("Transfer : Savings"); its counterpart in the
///   other account is then unpaired and imported as a normal
///   (uncategorised) row. Balances and To Be Budgeted stay correct; only
///   the link between the two rows is lost.
/// * Scheduled transfers: LedgerZero's scheduled transactions have no
///   transfer target, so a YNAB scheduled transfer is imported as a normal
///   scheduled transaction of the source account (same signed amount, no
///   payee, category only if YNAB had one) whose memo names the transfer
///   ("Transfer : Savings"). The user can turn generated occurrences into
///   transfers; we do not invent a second schedule for the other account.
/// * Budget rows use the deterministic id of their category and month
///   (decision D7); existing rows are updated.
class YnabDataMapper {
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final PayeeRepository _payeeRepo;
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;
  final ScheduledTransactionRepository _scheduledTransactionRepo;
  final UnitOfWork _unitOfWork;

  YnabDataMapper({
    required this._accountRepo,
    required this._categoryRepo,
    required this._payeeRepo,
    required this._transactionRepo,
    required this._budgetRepo,
    required this._scheduledTransactionRepo,
    required this._unitOfWork,
  });

  /// Whether a YNAB category is the "Ready to Assign" / "To be Budgeted"
  /// inflow pseudo-category, which maps to "no category" (the amount counts
  /// towards To Be Budgeted).
  static bool isReadyToAssignCategory(String? groupName, String? name) {
    final group = groupName?.trim().toLowerCase() ?? '';
    final category = name?.trim().toLowerCase() ?? '';
    return group == 'inflow' ||
        group == 'internal master category' ||
        category.startsWith('inflow:') ||
        category == 'ready to assign' ||
        category == 'to be budgeted';
  }

  /// Imports [data]; new accounts get [currency] (ISO code).
  Future<YnabImportSummary> importData(
    YnabImportData data, {
    required String currency,
  }) async {
    Logger.info('Starting YNAB import...');

    final summary = await _unitOfWork.run(() async {
      // 1. Categories & Groups: "Group:Category" -> LedgerZero id
      final categoryNameMap = await _importCategories(data);

      // 2. Accounts (tracking accounts are skipped)
      final accountIdMap = await _importAccounts(data, currency);

      // 3. Transactions (and Payees)
      final payees = _PayeeResolver(
        _payeeRepo,
        await _payeeRepo.getAllPayees(),
      );
      await _importTransactions(data, accountIdMap, categoryNameMap, payees);

      // 4. Scheduled Transactions
      await _importScheduledTransactions(
        data,
        accountIdMap,
        categoryNameMap,
        payees,
      );

      // 5. Budget Allocations
      await _importBudgets(data, categoryNameMap);

      final onBudget = data.accounts.where((a) => a.onBudget).toList();
      return YnabImportSummary(
        accounts: onBudget.length,
        categories: data.categories.length,
        transactions: data.transactions
            .where((t) => accountIdMap.containsKey(t.accountId))
            .length,
        trackingAccountsSkipped: data.accounts.length - onBudget.length,
      );
    });

    Logger.info('YNAB import completed.');
    return summary;
  }

  /// The LedgerZero category of a YNAB group/category pair, or `null` for
  /// none (empty, unknown or the Ready to Assign inflow).
  static String? _categoryFor(
    String? groupName,
    String? name,
    Map<String, String> categoryNameMap,
  ) {
    if (groupName == null ||
        name == null ||
        groupName.isEmpty ||
        name.isEmpty ||
        isReadyToAssignCategory(groupName, name)) {
      return null;
    }
    return categoryNameMap['$groupName:$name'];
  }

  static TransactionClearStatus _clearStatus(YnabTransaction tx) =>
      tx.reconciled
      ? TransactionClearStatus.reconciled
      : (tx.cleared
            ? TransactionClearStatus.cleared
            : TransactionClearStatus.uncleared);

  static String? _nonEmpty(String? text) =>
      text == null || text.trim().isEmpty ? null : text;

  /// Returns a map of "CategoryGroupName:CategoryName" -> CategoryID
  Future<Map<String, String>> _importCategories(YnabImportData data) async {
    final existingGroups = await _categoryRepo.getAllCategoryGroups();
    final groupNameMap = {for (var g in existingGroups) g.name: g.id};

    // 1. Groups
    for (final yGroup in data.categoryGroups) {
      if (yGroup.name == 'Internal Master Category' ||
          yGroup.name.trim().toLowerCase() == 'inflow') {
        continue;
      }
      if (!groupNameMap.containsKey(yGroup.name)) {
        final groupId = const Uuid().v4();
        await _categoryRepo.createCategoryGroup(
          CategoryGroup(
            id: groupId,
            name: yGroup.name,
            sortOrder: 0,
            createdAt: DateTime.now().toUtc(),
          ),
        );
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

      if (yCat.name == 'Uncategorized' ||
          isReadyToAssignCategory(sourceGroup.name, yCat.name)) {
        continue;
      }

      final targetGroupId = groupNameMap[sourceGroup.name];
      if (targetGroupId == null) {
        continue;
      }

      final key = '${sourceGroup.name}:${yCat.name}';

      if (!catNameMap.containsKey(key)) {
        final catId = const Uuid().v4();
        await _categoryRepo.createCategory(
          Category(
            id: catId,
            name: yCat.name,
            categoryGroupId: targetGroupId,
            isHidden: yCat.isHidden || sourceGroup.isHidden,
            color: 0xFF000000,
            icon: null, // Icon is String? in Category
            createdAt: DateTime.now().toUtc(),
            goalType: null,
            targetAmount: null,
            targetDate: null,
          ),
        );
        catNameMap[key] = catId;
      }
    }

    return catNameMap;
  }

  Future<Map<String, String>> _importAccounts(
    YnabImportData data,
    String currency,
  ) async {
    final mapping = <String, String>{};

    final existingAccounts = await _accountRepo.getAllAccounts();
    final accNameMap = {for (var a in existingAccounts) a.name: a.id};

    for (final yAcc in data.accounts) {
      if (!yAcc.onBudget) {
        // Tracking account: not imported (see the class comment).
        continue;
      }
      // Closed accounts are imported too (as closed), with their
      // transactions: they hold history and the other legs of transfers.
      String accId;
      if (accNameMap.containsKey(yAcc.name)) {
        accId = accNameMap[yAcc.name]!;
      } else {
        accId = const Uuid().v4();
        await _accountRepo.createAccount(
          Account(
            id: accId,
            name: yAcc.name,
            type: yAcc.type,
            currency: currency,
            startingBalance: 0,
            isClosed: yAcc.isClosed,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
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
    _PayeeResolver payees,
  ) async {
    final now = DateTime.now().toUtc();
    final transactions = data.transactions;
    final partnerOf = _pairTransfers(data, accountMap, categoryNameMap);
    final legIds = {for (final i in partnerOf.keys) i: const Uuid().v4()};

    final transactionsToInsert = <Transaction>[];

    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final accId = accountMap[tx.accountId];
      if (accId == null) {
        continue;
      }
      final cleared = _clearStatus(tx);

      final partner = partnerOf[i];
      if (partner != null) {
        // Transfer leg (decision D4): no payee, no category, linked to the
        // other leg both ways.
        transactionsToInsert.add(
          Transaction(
            id: legIds[i]!,
            accountId: accId,
            date: tx.date,
            amount: tx.amount,
            memo: _nonEmpty(tx.memo),
            cleared: cleared,
            approved: true,
            transferAccountId: accountMap[transactions[partner].accountId],
            transferTransactionId: legIds[partner],
            createdAt: now,
            updatedAt: now,
          ),
        );
        continue;
      }

      // A YNAB transfer without an importable other leg becomes a normal
      // row; its "Transfer : X" payee is kept as the memo, not as a payee.
      final isUnpairedTransfer = _transferTargetOf(tx, data) != null;
      final payeeId = isUnpairedTransfer
          ? null
          : await payees.resolve(tx.payeeName);
      final memo = isUnpairedTransfer
          ? _withTransferNote(tx.memo, _nonEmpty(tx.payeeName))
          : _nonEmpty(tx.memo);

      if (tx.splits.isNotEmpty) {
        // Parent: account-side amount, never categorised.
        final parentId = const Uuid().v4();
        transactionsToInsert.add(
          Transaction(
            id: parentId,
            accountId: accId,
            date: tx.date,
            amount: tx.amount,
            payeeId: payeeId,
            memo: memo,
            cleared: cleared,
            approved: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        Transaction child({
          required int amount,
          String? categoryId,
          String? payeeId,
          String? memo,
        }) => Transaction(
          id: const Uuid().v4(),
          accountId: accId,
          date: tx.date,
          amount: amount,
          payeeId: payeeId,
          categoryId: categoryId,
          memo: memo,
          cleared: cleared,
          approved: true,
          parentTransactionId: parentId,
          createdAt: now,
          updatedAt: now,
        );

        for (final split in tx.splits) {
          // A transfer line cannot be a split child transfer leg; it stays
          // an (uncategorised) child and its memo names the transfer.
          final target = split.transferAccountId;
          transactionsToInsert.add(
            child(
              amount: split.amount,
              categoryId: _categoryFor(
                split.categoryGroupName,
                split.categoryName,
                categoryNameMap,
              ),
              payeeId: await payees.resolve(split.payeeName) ?? payeeId,
              memo: target == null
                  ? _nonEmpty(split.memo)
                  : _withTransferNote(
                      split.memo,
                      _transferNote(_accountName(target, data)),
                    ),
            ),
          );
        }

        // Children must add up to the parent, or balances and category
        // activity would disagree.
        final remainder = tx.amount - Money.sum(tx.splits.map((s) => s.amount));
        if (remainder != 0) {
          Logger.warning(
            'YNAB split ${tx.id}: children do not add up to the parent '
            '(difference $remainder minor units); importing the difference '
            'as an uncategorised split line.',
          );
          transactionsToInsert.add(child(amount: remainder, payeeId: payeeId));
        }
      } else {
        transactionsToInsert.add(
          Transaction(
            id: const Uuid().v4(),
            accountId: accId,
            date: tx.date,
            amount: tx.amount,
            payeeId: payeeId,
            categoryId: _categoryFor(
              tx.categoryGroupName,
              tx.categoryName,
              categoryNameMap,
            ),
            memo: memo,
            cleared: cleared,
            approved: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    await _transactionRepo.batchCreateTransactions(transactionsToInsert);
  }

  /// The name of the YNAB account [idOrName] (YNAB4 id or CSV name); the
  /// value itself when it is not part of the data.
  static String _accountName(String idOrName, YnabImportData data) {
    for (final account in data.accounts) {
      if (account.id == idOrName) {
        return account.name;
      }
    }
    return idOrName;
  }

  /// YNAB's own transfer payee text, kept in memos of rows that cannot be
  /// imported as linked transfers. It is data from the export (YNAB's
  /// wording), not an app string.
  static String _transferNote(String accountName) => 'Transfer : $accountName';

  /// [note] followed by the row's own [memo] (when both are present).
  static String? _withTransferNote(String? memo, String? note) {
    final own = _nonEmpty(memo)?.trim();
    if (note == null) {
      return own;
    }
    return own == null ? note : '$note - $own';
  }

  /// The YNAB account id a transfer row points at, or `null` if [tx] is not
  /// a transfer. Uses the explicit target (YNAB4 `targetAccountId`, CSV
  /// parser) and falls back to a `Transfer : <Account Name>` payee.
  static String? _transferTargetOf(YnabTransaction tx, YnabImportData data) {
    if (tx.transferAccountId != null) {
      return tx.transferAccountId;
    }
    final name = YnabImportService.transferTargetName(tx.payeeName);
    if (name == null) {
      return null;
    }
    for (final account in data.accounts) {
      if (account.name == name) {
        return account.id;
      }
    }
    // A transfer to an account that is not part of the data.
    return name;
  }

  /// Pairs the two legs of every transfer: index -> index of the other leg.
  ///
  /// Candidates are unsplit, uncategorised rows whose account and target
  /// account are both imported (and differ). Two candidates form a pair
  /// when they are on the same day, have opposite amounts and their
  /// accounts point at each other; pairing is greedy and one-to-one, in
  /// data order. Rows left without a partner are imported as normal rows.
  static Map<int, int> _pairTransfers(
    YnabImportData data,
    Map<String, String> accountMap,
    Map<String, String> categoryNameMap,
  ) {
    final partnerOf = <int, int>{};
    // Unpaired candidates by "account|target|day|amount".
    final waiting = <String, List<int>>{};
    String key(String account, String target, DateTime day, int amount) =>
        '$account|$target|${day.toIso8601String()}|$amount';

    for (var i = 0; i < data.transactions.length; i++) {
      final tx = data.transactions[i];
      final target = _transferTargetOf(tx, data);
      if (target == null || tx.splits.isNotEmpty) {
        continue;
      }
      final accId = accountMap[tx.accountId];
      final targetId = accountMap[target];
      if (accId == null || targetId == null || accId == targetId) {
        continue;
      }
      if (_categoryFor(
            tx.categoryGroupName,
            tx.categoryName,
            categoryNameMap,
          ) !=
          null) {
        continue;
      }
      final day = CalendarDate.normalize(tx.date);
      final counterpart = waiting[key(targetId, accId, day, -tx.amount)];
      if (counterpart != null && counterpart.isNotEmpty) {
        final other = counterpart.removeAt(0);
        partnerOf[i] = other;
        partnerOf[other] = i;
      } else {
        waiting
            .putIfAbsent(key(accId, targetId, day, tx.amount), () => [])
            .add(i);
      }
    }
    return partnerOf;
  }

  Future<void> _importScheduledTransactions(
    YnabImportData data,
    Map<String, String> accountMap,
    Map<String, String> categoryNameMap,
    _PayeeResolver payees,
  ) async {
    for (final sch in data.scheduledTransactions) {
      final accId = accountMap[sch.accountId];
      if (accId == null) {
        continue;
      }

      // Scheduled transfers: the scheduled-transaction model has no
      // transfer target, so the schedule is imported as a normal one for
      // the source account (same signed amount, no payee) whose memo names
      // the transfer. See the class comment.
      final target = sch.transferAccountId;
      final isTransfer = target != null && target != sch.accountId;

      await _scheduledTransactionRepo.createScheduledTransaction(
        ScheduledTransaction(
          id: const Uuid().v4(),
          accountId: accId,
          payeeId: isTransfer ? null : await payees.resolve(sch.payeeName),
          categoryId: _categoryFor(
            sch.categoryGroupName,
            sch.categoryName,
            categoryNameMap,
          ),
          amount: sch.amount,
          frequency: sch.frequency,
          interval: sch.interval,
          occurrenceCount: sch.occurrenceCount,
          nextDate: sch.nextDate,
          endDate: null,
          autoApprove: false,
          memo: isTransfer
              ? _withTransferNote(
                  sch.memo,
                  _transferNote(_accountName(target, data)),
                )
              : _nonEmpty(sch.memo),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  /// Budget rows are found by their natural key (category + month) and
  /// updated, or created with the deterministic id (decision D7).
  Future<void> _importBudgets(
    YnabImportData data,
    Map<String, String> categoryNameMap,
  ) async {
    final now = DateTime.now().toUtc();
    for (final entry in data.budgetEntries) {
      final catId = _categoryFor(
        entry.categoryGroupName,
        entry.categoryName,
        categoryNameMap,
      );
      if (catId == null) {
        continue;
      }

      final monthKey = CalendarDate.monthKey(entry.month);
      final existing = await _budgetRepo.getBudgetByCategoryAndMonth(
        catId,
        monthKey,
      );
      if (existing != null) {
        await _budgetRepo.updateBudget(
          existing.copyWith(budgeted: entry.budgeted, updatedAt: now),
        );
      } else {
        await _budgetRepo.createBudget(
          Budget(
            id: DeterministicId.budgetForKey(catId, monthKey),
            categoryId: catId,
            month: monthKey,
            budgeted: entry.budgeted,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }
}

/// Finds payees by name (case-insensitive, trimmed) and creates missing
/// ones. YNAB transfer payees ("Transfer : X") never become payees.
class _PayeeResolver {
  _PayeeResolver(this._repository, Iterable<Payee> existing)
    : _idsByName = {for (final p in existing) _normalize(p.name): p.id};

  final PayeeRepository _repository;
  final Map<String, String> _idsByName;

  static String _normalize(String name) => name.trim().toLowerCase();

  Future<String?> resolve(String? name) async {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty ||
        YnabImportService.transferTargetName(trimmed) != null) {
      return null;
    }
    final key = _normalize(trimmed);
    final known = _idsByName[key];
    if (known != null) {
      return known;
    }
    final id = const Uuid().v4();
    await _repository.createPayee(
      Payee(id: id, name: trimmed, createdAt: DateTime.now().toUtc()),
    );
    _idsByName[key] = id;
    return id;
  }
}

/// What a YNAB import wrote (shown on the result screen).
class YnabImportSummary {
  const YnabImportSummary({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.trackingAccountsSkipped,
  });

  /// Imported (on-budget) accounts.
  final int accounts;
  final int categories;

  /// Transactions of imported accounts (a split counts once).
  final int transactions;

  /// Tracking (off-budget) accounts that were not imported.
  final int trackingAccountsSkipped;
}
