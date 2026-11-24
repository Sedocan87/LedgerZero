import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/import/import_undo_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:uuid/uuid.dart';

/// Commits reviewed bank-import rows (CSV import) as transactions.
class TransactionImportService {
  TransactionImportService({
    required this._transactionRepository,
    required this._payeeRepository,
    required this._ruleMatchingService,
    required this._unitOfWork,
    this._accountRepository,
    this._lastImportStore,
  });

  final TransactionRepository _transactionRepository;
  final PayeeRepository _payeeRepository;
  final RuleMatchingService _ruleMatchingService;
  final UnitOfWork _unitOfWork;
  final AccountRepository? _accountRepository;

  /// Where the created transactions are recorded for "undo last import"
  /// (see [ImportUndoService]); `null`: not recorded.
  final LastImportStore? _lastImportStore;

  /// Imports [rows] in one unit of work (all rows or none) and returns the
  /// number of transactions created.
  ///
  /// A row goes into [ImportTransaction.accountId] when set ("account from
  /// file" on the review screen), else into [accountId].
  ///
  /// Each row becomes a transaction on its calendar day, approved and
  /// cleared unless the file's Approved or Cleared column said otherwise. Fields are filled in
  /// this order, each step only filling what is still empty:
  ///
  /// 1. The row's own values (amount, memo, and the category of the file's
  ///    Category column when it matched an existing category, see
  ///    `CsvImportService.assignCategories`).
  /// 2. The user's rules, through the shared [RuleMatchingService] in
  ///    [RuleApplyMode.automatic] (priority convention and condition
  ///    semantics are documented there). The payee condition sees the
  ///    row's payee name and the description condition also sees the bank's
  ///    original description. A rule's "set payee" action wins over the
  ///    payee name of the row.
  /// 3. The payee: when no rule set one, the payee is found by name
  ///    (trimmed, case-insensitive) or created.
  /// 4. The payee's default category (`autoCategoryId`), only if neither
  ///    the row nor a rule set a category: rules are explicit user
  ///    configuration and take precedence over the learned payee default.
  ///
  /// Transfers: a row whose [ImportTransaction.transferAccountName] names
  /// an account of [accountIdsByName] (normalised names -> ids) is a
  /// transfer leg. Two legs of the same day with opposite amounts whose
  /// accounts point at each other become one linked transfer (no payee;
  /// the rows' categories are kept, which matters only for a transfer that
  /// crosses the budget boundary). A leg without counterpart is imported as
  /// a normal row.
  ///
  /// With [adjustStartingBalances], the rows dated before their account
  /// starts ([startingBalanceOverlaps]) are taken out of its starting
  /// balance, which already holds them; the undo of the import puts them
  /// back.
  Future<int> importTransactions(
    List<ImportTransaction> rows,
    String accountId, {
    Map<String, String> accountIdsByName = const {},
    bool adjustStartingBalances = false,
  }) async {
    if (rows.isEmpty) {
      return 0;
    }
    final startingBalanceRows = <String, List<String>>{};
    final created = await _unitOfWork.run(() async {
      final rules = await _ruleMatchingService.loadActiveRules();
      final existing = await _payeeRepository.getAllPayees();
      final payeesById = {for (final p in existing) p.id: p};
      final payeesByName = {for (final p in existing) _normalize(p.name): p};
      final allAccounts = _accountRepository == null
          ? const <Account>[]
          : await _accountRepository.getAllAccounts();
      final accountsById = {for (final a in allAccounts) a.id: a};
      final paymentCategoryIds = CardPayments.categoryIds(allAccounts);
      final now = DateTime.now().toUtc();
      final partnerOf = pairTransfers(
        rows,
        accountId,
        accountIdsByName,
        accountsById: accountsById,
      );
      final ids = [for (final _ in rows) const Uuid().v4()];

      String? sanitizeCategory(String? categoryId, Account? account) {
        if (categoryId == null) {
          return null;
        }
        if (paymentCategoryIds.contains(categoryId)) {
          return null;
        }
        if (account != null && !account.onBudget) {
          return null;
        }
        return categoryId;
      }

      final transactions = <Transaction>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final target = row.accountId ?? accountId;
        final account = accountsById[target];
        final partner = partnerOf[i];
        if (partner != null) {
          final transferAccountId = rows[partner].accountId ?? accountId;
          final otherAccount = accountsById[transferAccountId];
          // Only transfers crossing the budget boundary may carry a category,
          // and only on the on-budget leg.
          final crossesBoundary =
              account != null &&
              otherAccount != null &&
              account.onBudget != otherAccount.onBudget;
          final transferCategory = crossesBoundary && account.onBudget
              ? sanitizeCategory(row.categoryId, account)
              : (account == null || otherAccount == null
                    ? sanitizeCategory(row.categoryId, account)
                    : null);
          transactions.add(
            Transaction(
              id: ids[i],
              accountId: target,
              date: CalendarDate.normalize(row.date),
              amount: row.amount,
              categoryId: transferCategory,
              memo: _nonEmpty(row.memo),
              cleared: row.cleared ?? TransactionClearStatus.cleared,
              approved: row.approved ?? true,
              transferAccountId: transferAccountId,
              transferTransactionId: ids[partner],
              createdAt: now,
              updatedAt: now,
            ),
          );
          continue;
        }

        final payeeName = _nonEmpty(row.payeeName?.trim());
        var transaction = Transaction(
          id: ids[i],
          accountId: target,
          date: CalendarDate.normalize(row.date),
          amount: row.amount,
          categoryId: sanitizeCategory(row.categoryId, account),
          memo: _nonEmpty(row.memo),
          cleared: row.cleared ?? TransactionClearStatus.cleared,
          approved: row.approved ?? true,
          createdAt: now,
          updatedAt: now,
        );

        transaction = await _ruleMatchingService.apply(
          transaction,
          rules,
          mode: RuleApplyMode.automatic,
          payeeName: payeeName,
          description: _nonEmpty(row.originalDescription),
        );

        Payee? payee;
        if (transaction.payeeId != null) {
          final id = transaction.payeeId!;
          payee = payeesById[id] ?? await _payeeRepository.getPayeeById(id);
        } else if (payeeName != null) {
          payee = payeesByName[_normalize(payeeName)];
          if (payee == null) {
            payee = Payee(
              id: const Uuid().v4(),
              name: payeeName,
              createdAt: now,
            );
            await _payeeRepository.createPayee(payee);
            payeesById[payee.id] = payee;
            payeesByName[_normalize(payeeName)] = payee;
          }
          transaction = transaction.copyWith(payeeId: payee.id);
        }

        final finalAccount = accountsById[transaction.accountId] ?? account;
        final defaultCategory = payee?.autoCategoryId;
        if (transaction.categoryId == null && defaultCategory != null) {
          final safeDefault = sanitizeCategory(defaultCategory, finalAccount);
          if (safeDefault != null) {
            transaction = transaction.copyWith(categoryId: safeDefault);
          }
        } else if (transaction.categoryId != null) {
          final safeCategory = sanitizeCategory(
            transaction.categoryId,
            finalAccount,
          );
          if (safeCategory != transaction.categoryId) {
            transaction = Transaction(
              id: transaction.id,
              accountId: transaction.accountId,
              date: transaction.date,
              amount: transaction.amount,
              payeeId: transaction.payeeId,
              categoryId: null,
              memo: transaction.memo,
              cleared: transaction.cleared,
              approved: transaction.approved,
              transferAccountId: transaction.transferAccountId,
              transferTransactionId: transaction.transferTransactionId,
              parentTransactionId: transaction.parentTransactionId,
              isDeleted: transaction.isDeleted,
              createdAt: transaction.createdAt,
              updatedAt: transaction.updatedAt,
            );
          }
        }
        transactions.add(transaction);
      }

      // Before the rows are written: they would move the start.
      if (adjustStartingBalances && _accountRepository != null) {
        final overlaps = startingBalanceOverlaps(
          rows,
          accountId,
          accountsById,
          await accountStarts(allAccounts),
        );
        for (final overlap in overlaps) {
          await _accountRepository.updateAccount(
            overlap.account.copyWith(
              startingBalance: overlap.adjustedStartingBalance,
              updatedAt: now,
            ),
          );
          startingBalanceRows[overlap.account.id] = [
            for (final i in overlap.rowIndexes) ids[i],
          ];
        }
      }

      await _transactionRepository.batchCreateTransactions(transactions);
      return transactions;
    });
    final store = _lastImportStore;
    if (store != null) {
      await ImportUndoService.record(
        store,
        created,
        DateTime.now().toUtc(),
        startingBalanceRows: startingBalanceRows,
      );
    }
    return created.length;
  }

  /// The day each of [accounts] with a starting balance starts (see
  /// `BudgetingService.accountStart`); for an account without a creation
  /// time, the day of its first transaction. Accounts with neither, or
  /// without a starting balance, are left out.
  Future<Map<String, DateTime>> accountStarts(
    Iterable<Account> accounts,
  ) async {
    final result = <String, DateTime>{};
    for (final account in accounts) {
      if (account.startingBalance == 0) {
        continue;
      }
      DateTime? first;
      for (final t in await _transactionRepository.getTransactionsByAccount(
        account.id,
      )) {
        if (!t.isDeleted && (first == null || t.date.isBefore(first))) {
          first = t.date;
        }
      }
      final start =
          BudgetingService.accountStart(account, first) ??
          (first == null ? null : CalendarDate.normalize(first));
      if (start != null) {
        result[account.id] = start;
      }
    }
    return result;
  }

  /// The rows of [rows] dated before their account starts ([starts], see
  /// [accountStarts]), by account, for the accounts with a starting
  /// balance. The starting balance is the balance at the start (the
  /// account form asks for the current balance), so it already holds
  /// these rows: imported as well, they would count twice. A row goes
  /// into its own [ImportTransaction.accountId], else into [accountId].
  static List<StartingBalanceOverlap> startingBalanceOverlaps(
    List<ImportTransaction> rows,
    String? accountId,
    Map<String, Account> accountsById,
    Map<String, DateTime> starts,
  ) {
    final indexes = <String, List<int>>{};
    for (var i = 0; i < rows.length; i++) {
      final target = rows[i].accountId ?? accountId;
      final start = starts[target];
      final account = accountsById[target];
      if (start == null ||
          account == null ||
          account.startingBalance == 0 ||
          !CalendarDate.normalize(rows[i].date).isBefore(start)) {
        continue;
      }
      indexes.putIfAbsent(target!, () => []).add(i);
    }
    return [
      for (final MapEntry(key: id, value: rowIndexes) in indexes.entries)
        StartingBalanceOverlap(
          account: accountsById[id]!,
          start: starts[id]!,
          rowIndexes: rowIndexes,
          net: Money.sum(rowIndexes.map((i) => rows[i].amount)),
        ),
    ];
  }

  /// Pairs the transfer legs among [rows]: index -> index of the other leg
  /// (see [importTransactions]). Greedy and one-to-one, in row order.
  static Map<int, int> pairTransfers(
    List<ImportTransaction> rows,
    String accountId,
    Map<String, String> accountIdsByName, {
    Map<String, Account> accountsById = const {},
  }) {
    final partnerOf = <int, int>{};
    final waiting = <String, List<int>>{};
    String key(String account, String target, DateTime day, int amount) =>
        '$account|$target|${CalendarDate.normalize(day).toIso8601String()}|'
        '$amount';

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = row.transferAccountName;
      if (name == null) {
        continue;
      }
      final own = row.accountId ?? accountId;
      final target = accountIdsByName[CsvImportService.normalizePayee(name)];
      if (target == null || target == own) {
        continue;
      }
      final ownAccount = accountsById[own];
      final targetAccount = accountsById[target];
      if (ownAccount != null && targetAccount != null) {
        if (ownAccount.isPartners ||
            targetAccount.isPartners ||
            ownAccount.currency != targetAccount.currency) {
          continue;
        }
      }
      final counterpart = waiting[key(target, own, row.date, -row.amount)];
      if (counterpart != null && counterpart.isNotEmpty) {
        final other = counterpart.removeAt(0);
        partnerOf[i] = other;
        partnerOf[other] = i;
      } else {
        waiting
            .putIfAbsent(key(own, target, row.date, row.amount), () => [])
            .add(i);
      }
    }
    return partnerOf;
  }

  /// Flags the rows of [rows] that already exist in their account and
  /// deselects them: duplicates (same day, amount and payee name, the
  /// file's or the one a rule would set) and possible duplicates (same
  /// amount within a few days, whatever the payee); see
  /// `CsvImportService.checkForDuplicates`.
  ///
  /// Call it again whenever the target account changes: only the chosen
  /// account's transactions count (a row's own
  /// [ImportTransaction.accountId] wins over [accountId]), and rows that
  /// were duplicates of the previous account are selected again.
  Future<void> markDuplicates(
    List<ImportTransaction> rows,
    String accountId,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    final wasFlagged = [
      for (final r in rows) r.isDuplicate || r.isPossibleDuplicate,
    ];
    for (final r in rows) {
      r.isDuplicate = false;
      r.isPossibleDuplicate = false;
      r.possibleDuplicateDate = null;
      r.possibleDuplicatePayee = null;
    }

    final rules = await _ruleMatchingService.loadActiveRules();
    final payees = await _payeeRepository.getAllPayees();
    final payeeNames = {for (final p in payees) p.id: p.name};
    if (rules.isNotEmpty) {
      for (final r in rows) {
        r.rulePayeeName = await _rulePayeeName(r, rules, payeeNames);
      }
    }

    final byAccount = <String, List<ImportTransaction>>{};
    for (final r in rows) {
      byAccount.putIfAbsent(r.accountId ?? accountId, () => []).add(r);
    }
    for (final entry in byAccount.entries) {
      final group = entry.value;
      var first = group.first.date;
      var last = group.first.date;
      for (final r in group) {
        if (r.date.isBefore(first)) {
          first = r.date;
        }
        if (r.date.isAfter(last)) {
          last = r.date;
        }
      }
      // The possible-duplicate rule looks a few days around each row.
      const margin = Duration(
        days: CsvImportService.possibleDuplicateWindowDays + 1,
      );
      final existing = await _transactionRepository.getTransactions(
        filter: TransactionFilter(
          accountIds: [entry.key],
          startDate: first.subtract(margin),
          endDate: last.add(margin),
          excludeSplitChildren: true,
        ),
      );
      CsvImportService().checkForDuplicates(
        imported: group,
        existing: existing,
        payeeMap: payeeNames,
      );
    }
    for (var i = 0; i < rows.length; i++) {
      if (wasFlagged[i] &&
          !rows[i].isDuplicate &&
          !rows[i].isPossibleDuplicate) {
        rows[i].isSelected = true;
      }
    }
  }

  /// The payee name a rule's "set payee" action gives [row], or `null`.
  Future<String?> _rulePayeeName(
    ImportTransaction row,
    List<Rule> rules,
    Map<String, String> payeeNames,
  ) async {
    final applied = await _ruleMatchingService.apply(
      Transaction(
        id: '',
        accountId: '',
        date: CalendarDate.normalize(row.date),
        amount: row.amount,
        categoryId: row.categoryId,
        memo: _nonEmpty(row.memo),
      ),
      rules,
      mode: RuleApplyMode.automatic,
      payeeName: _nonEmpty(row.payeeName?.trim()),
      description: _nonEmpty(row.originalDescription),
    );
    return applied.payeeId == null ? null : payeeNames[applied.payeeId];
  }

  static String _normalize(String name) => name.trim().toLowerCase();

  static String? _nonEmpty(String? text) =>
      text == null || text.isEmpty ? null : text;
}

final transactionImportServiceProvider = Provider<TransactionImportService>((
  ref,
) {
  return TransactionImportService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    payeeRepository: ref.watch(payeeRepositoryProvider),
    ruleMatchingService: ref.watch(ruleMatchingServiceProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    lastImportStore: ref.watch(lastImportStoreProvider),
  );
});

/// Rows of an import dated before their account starts, while the account
/// has a starting balance (see
/// [TransactionImportService.startingBalanceOverlaps]).
class StartingBalanceOverlap {
  const StartingBalanceOverlap({
    required this.account,
    required this.start,
    required this.rowIndexes,
    required this.net,
  });

  final Account account;

  /// The day the account starts.
  final DateTime start;

  /// Indexes of the rows in the list that was checked.
  final List<int> rowIndexes;

  /// The sum of those rows (minor units).
  final int net;

  /// The starting balance that keeps today's balance when the rows are
  /// imported.
  int get adjustedStartingBalance => account.startingBalance - net;
}
