import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
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

/// Commits reviewed bank-import rows (CSV import) as transactions of one
/// account.
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

  /// Imports [rows] into [accountId] in one unit of work (all rows or none)
  /// and returns the number of transactions created.
  ///
  /// Each row becomes a cleared, approved transaction on its calendar day.
  /// Fields are filled in this order, each step only filling what is still
  /// empty:
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
  Future<int> importTransactions(
    List<ImportTransaction> rows,
    String accountId,
  ) async {
    if (rows.isEmpty) {
      return 0;
    }
    return _unitOfWork.run(() async {
      final rules = await _ruleMatchingService.loadActiveRules();
      final existing = await _payeeRepository.getAllPayees();
      final payeesById = {for (final p in existing) p.id: p};
      final payeesByName = {for (final p in existing) _normalize(p.name): p};
      final now = DateTime.now().toUtc();

      final transactions = <Transaction>[];
      for (final row in rows) {
        final payeeName = _nonEmpty(row.payeeName?.trim());
        var transaction = Transaction(
          id: const Uuid().v4(),
          accountId: accountId,
          date: CalendarDate.normalize(row.date),
          amount: row.amount,
          categoryId: row.categoryId,
          memo: _nonEmpty(row.memo),
          cleared: TransactionClearStatus.cleared,
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

  /// Flags the rows of [rows] that already exist in [accountId] (same day,
  /// amount and payee name) as duplicates and deselects them.
  ///
  /// Call it again whenever the target account changes: only the chosen
  /// account's transactions count, and rows that were duplicates of the
  /// previous account are selected again.
  Future<void> markDuplicates(
    List<ImportTransaction> rows,
    String accountId,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    final wasDuplicate = [for (final r in rows) r.isDuplicate];
    for (final r in rows) {
      r.isDuplicate = false;
    }
    var first = rows.first.date;
    var last = rows.first.date;
    for (final r in rows) {
      if (r.date.isBefore(first)) {
        first = r.date;
      }
      if (r.date.isAfter(last)) {
        last = r.date;
      }
    }
    final existing = await _transactionRepository.getTransactions(
      filter: TransactionFilter(
        accountIds: [accountId],
        startDate: first.subtract(const Duration(days: 1)),
        endDate: last.add(const Duration(days: 1)),
        excludeSplitChildren: true,
      ),
    );
    final payees = await _payeeRepository.getAllPayees();
    CsvImportService().checkForDuplicates(
      imported: rows,
      existing: existing,
      payeeMap: {for (final p in payees) p.id: p.name},
    );
    for (var i = 0; i < rows.length; i++) {
      if (wasDuplicate[i] && !rows[i].isDuplicate) {
        rows[i].isSelected = true;
      }
    }
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
