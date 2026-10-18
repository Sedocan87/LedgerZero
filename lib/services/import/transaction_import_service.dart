import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:uuid/uuid.dart';

/// Commits reviewed bank-import rows (CSV import) as transactions.
class TransactionImportService {
  TransactionImportService({
    required this._transactionRepository,
    required this._payeeRepository,
    required this._ruleMatchingService,
    required this._unitOfWork,
  });

  final TransactionRepository _transactionRepository;
  final PayeeRepository _payeeRepository;
  final RuleMatchingService _ruleMatchingService;
  final UnitOfWork _unitOfWork;

  /// Imports [rows] in one unit of work (all rows or none) and returns the
  /// number of transactions created.
  ///
  /// A row goes into [ImportTransaction.accountId] when set ("account from
  /// file" on the review screen), else into [accountId].
  ///
  /// Each row becomes an approved transaction on its calendar day, cleared
  /// unless the file's Cleared column said otherwise. Fields are filled in
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
  Future<int> importTransactions(
    List<ImportTransaction> rows,
    String accountId, {
    Map<String, String> accountIdsByName = const {},
  }) async {
    if (rows.isEmpty) {
      return 0;
    }
    return _unitOfWork.run(() async {
      final rules = await _ruleMatchingService.loadActiveRules();
      final existing = await _payeeRepository.getAllPayees();
      final payeesById = {for (final p in existing) p.id: p};
      final payeesByName = {for (final p in existing) _normalize(p.name): p};
      final now = DateTime.now().toUtc();
      final partnerOf = pairTransfers(rows, accountId, accountIdsByName);
      final ids = [for (final _ in rows) const Uuid().v4()];

      final transactions = <Transaction>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final target = row.accountId ?? accountId;
        final partner = partnerOf[i];
        if (partner != null) {
          transactions.add(
            Transaction(
              id: ids[i],
              accountId: target,
              date: CalendarDate.normalize(row.date),
              amount: row.amount,
              categoryId: row.categoryId,
              memo: _nonEmpty(row.memo),
              cleared: row.cleared ?? TransactionClearStatus.cleared,
              approved: true,
              transferAccountId: rows[partner].accountId ?? accountId,
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
          categoryId: row.categoryId,
          memo: _nonEmpty(row.memo),
          cleared: row.cleared ?? TransactionClearStatus.cleared,
          approved: true,
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

        final defaultCategory = payee?.autoCategoryId;
        if (transaction.categoryId == null && defaultCategory != null) {
          transaction = transaction.copyWith(categoryId: defaultCategory);
        }
        transactions.add(transaction);
      }

      await _transactionRepository.batchCreateTransactions(transactions);
      return transactions.length;
    });
  }

  /// Pairs the transfer legs among [rows]: index -> index of the other leg
  /// (see [importTransactions]). Greedy and one-to-one, in row order.
  static Map<int, int> pairTransfers(
    List<ImportTransaction> rows,
    String accountId,
    Map<String, String> accountIdsByName,
  ) {
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

  /// Flags the rows of [rows] that already exist in their account (same
  /// day, amount and payee name, the file's or the one a rule would set;
  /// see `CsvImportService.checkForDuplicates`) as duplicates and deselects
  /// them; rows matching an existing transaction without payee by day and
  /// amount are marked as possible duplicates.
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
      final existing = await _transactionRepository.getTransactions(
        filter: TransactionFilter(
          accountIds: [entry.key],
          startDate: first.subtract(const Duration(days: 1)),
          endDate: last.add(const Duration(days: 1)),
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
  );
});
