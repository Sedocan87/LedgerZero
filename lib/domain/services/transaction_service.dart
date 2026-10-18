import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/services/transaction_service_types.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/domain/undo/transaction_undo_actions.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:uuid/uuid.dart';

export 'package:ledger_zero/domain/services/transaction_service_types.dart';

/// Runs after a transaction save committed (see [TransactionService.save]).
typedef TransactionSavedHook =
    Future<void> Function(TransactionChangeSetAction change);

/// The single entry point for writing transactions (decision D4).
///
/// Screens never write transaction rows through repositories directly; they
/// call this service, which keeps the ledger consistent:
///
/// * Transfers are two rows linked both ways (`transferTransactionId` on
///   each, `transferAccountId` pointing at the other account). The
///   counterpart is always derived from the edited leg (`-amount`, the
///   other account), so editing either leg keeps its direction.
///   Converting a normal transaction into a transfer creates the
///   counterpart; converting back deletes it.
/// * A split is a parent (account-side amount, no category) plus children
///   (categories) whose amounts add up to the parent. Children are diffed
///   by id on edit (their cleared/reconciled state and ids survive).
/// * Split parents never carry a category. A transfer carries one only
///   when it crosses the budget boundary (one account on budget, the other
///   off budget, see docs/BUDGETING_RULES.md): then the input's category is
///   stored on the on-budget leg, so the money moves from that category
///   instead of To Be Budgeted. Any other transfer has no category.
/// * Deleting any row of a transfer or split deletes the whole group;
///   undo restores the whole group.
/// * Categories exist only in the budget: a row in an off-budget account
///   is stored without a category (quick-add and card capture may pass
///   one), except for the cross-budget transfer rule above.
/// * A transfer between accounts of different currencies is rejected
///   ([TransactionValidationError.currencyMismatch]).
/// * Only rows whose content actually changed are written (and recorded
///   for undo): editing the memo of a split leaves its children's
///   `updatedAt` alone, so a concurrent edit on the partner's phone is not
///   overwritten by last-writer-wins sync.
/// * Changing or deleting a reconciled row requires
///   `allowReconciledChange: true` (the UI asks the user first), otherwise
///   [ReconciledTransactionException] is thrown; a reconciled row that the
///   edit does not touch (e.g. the other transfer leg when only this leg's
///   cleared flag changes) needs no confirmation.
/// * Every write runs in one [UnitOfWork] and records one undo action.
class TransactionService {
  TransactionService({
    required this._transactionRepository,
    required this._payeeRepository,
    required this._accountRepository,
    required this._undoService,
    required this._unitOfWork,
    this._ruleMatchingService,
    this._uuid = const Uuid(),
    this._onSaved,
  });

  final TransactionRepository _transactionRepository;
  final PayeeRepository _payeeRepository;
  final AccountRepository _accountRepository;
  final UndoService _undoService;
  final UnitOfWork _unitOfWork;
  final RuleMatchingService? _ruleMatchingService;
  final Uuid _uuid;

  /// Called after every successful [save] with the recorded change (e.g.
  /// the budget alert check). Its errors are logged and never fail the
  /// save.
  final TransactionSavedHook? _onSaved;

  // ---------------------------------------------------------------------
  // Create / update
  // ---------------------------------------------------------------------

  /// Creates or updates a normal, transfer or split transaction.
  ///
  /// [recordUndo] is false for writes the user did not make in the UI
  /// (captured card notifications), so Undo never reverts them unseen.
  Future<TransactionSaveResult> save(
    TransactionInput input, {
    bool allowReconciledChange = false,
    bool recordUndo = true,
  }) async {
    _validate(input);
    try {
      final result = await _unitOfWork.run(
        () => _save(input, allowReconciledChange: allowReconciledChange),
      );
      if (recordUndo) {
        _undoService.addAction(result.action);
      }
      Logger.info('Transaction saved: ${result.id}');
      await _runSavedHook(result.action);
      return result;
    } catch (e, stackTrace) {
      if (e is! ReconciledTransactionException) {
        Logger.error('Failed to save transaction', e, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _runSavedHook(TransactionChangeSetAction change) async {
    final hook = _onSaved;
    if (hook == null) {
      return;
    }
    try {
      await hook(change);
    } catch (e, stackTrace) {
      Logger.error('Post-save hook failed', e, stackTrace);
    }
  }

  void _validate(TransactionInput input) {
    if (input.amount == 0) {
      throw ValidationException(
        'Transaction amount cannot be zero',
        TransactionValidationError.zeroAmount,
      );
    }
    if (input.isTransfer) {
      if (input.transferAccountId == input.accountId) {
        throw ValidationException(
          'Source and destination accounts must be different',
          TransactionValidationError.sameTransferAccount,
        );
      }
      if (input.isSplit) {
        throw ValidationException(
          'A transfer cannot be split',
          TransactionValidationError.splitTransfer,
        );
      }
    }
    if (input.isSplit) {
      if (input.splits.any((s) => s.amount == 0)) {
        throw ValidationException(
          'Split lines cannot be zero',
          TransactionValidationError.splitLineZero,
        );
      }
      final sum = Money.sum(input.splits.map((s) => s.amount));
      if (sum != input.amount) {
        throw ValidationException(
          'Split transactions sum $sum does not match parent amount '
          '${input.amount}',
          TransactionValidationError.splitSumMismatch,
        );
      }
    }
  }

  Future<TransactionSaveResult> _save(
    TransactionInput input, {
    required bool allowReconciledChange,
  }) async {
    final now = DateTime.now().toUtc();
    final date = CalendarDate.normalize(input.date);

    // Existing state (for updates).
    Transaction? existing;
    Transaction? counterpart;
    var children = const <Transaction>[];
    if (input.id != null) {
      existing = await _transactionRepository.getTransactionById(input.id!);
      if (existing == null) {
        throw ValidationException(
          'Transaction ${input.id} not found',
          TransactionValidationError.notFound,
        );
      }
      if (existing.transferTransactionId != null) {
        counterpart = await _transactionRepository.getTransactionById(
          existing.transferTransactionId!,
        );
      }
      children = await _transactionRepository.getSplitTransactions(existing.id);
    }
    await _ensureNotPartners([
      input.accountId,
      input.transferAccountId,
      existing?.accountId,
      existing?.transferAccountId,
    ]);
    final account = await _accountRepository.getAccountById(input.accountId);
    if (input.isTransfer) {
      await _ensureSameCurrency(account, input.transferAccountId!);
    }
    final before = <String, Transaction?>{
      ?existing?.id: existing,
      ?counterpart?.id: counterpart,
      for (final c in children) c.id: c,
    };

    final payeeId = input.isTransfer ? null : await _resolvePayee(input);
    final primaryId = existing?.id ?? _uuid.v4();
    final written = <Transaction>[];
    final transferCategory = await _transferCategory(input);
    // Categories only exist in the budget (an off-budget account's rows
    // never count as category activity, see docs/BUDGETING_RULES.md).
    final onBudget = account?.onBudget ?? true;
    final categoryId = onBudget ? input.categoryId : null;

    // Transfer counterpart.
    String? counterpartId;
    if (input.isTransfer) {
      counterpartId = counterpart?.id ?? _uuid.v4();
      final sameAccount = counterpart?.accountId == input.transferAccountId;
      written.add(
        Transaction(
          id: counterpartId,
          accountId: input.transferAccountId!,
          date: date,
          amount: -input.amount,
          memo: input.memo,
          // The cleared state belongs to the counterpart's own account.
          cleared:
              input.counterpartCleared ??
              (sameAccount
                  ? counterpart!.cleared
                  : TransactionClearStatus.uncleared),
          approved: input.approved,
          categoryId: transferCategory.counterpart,
          transferAccountId: input.accountId,
          transferTransactionId: primaryId,
          createdAt: counterpart?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } else if (counterpart != null) {
      written.add(_deleted(counterpart, now));
    }

    final primary = Transaction(
      id: primaryId,
      accountId: input.accountId,
      date: date,
      amount: input.amount,
      payeeId: payeeId,
      categoryId: input.isTransfer
          ? transferCategory.primary
          : (input.isSplit ? null : categoryId),
      memo: input.memo,
      cleared: input.cleared,
      approved: input.approved,
      transferAccountId: input.isTransfer ? input.transferAccountId : null,
      transferTransactionId: counterpartId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    written.insert(0, primary);

    // Split children, diffed by id.
    final existingChildren = {for (final c in children) c.id: c};
    final keptIds = <String>{};
    for (final line in input.splits) {
      final old = line.id == null ? null : existingChildren[line.id];
      final id = old?.id ?? _uuid.v4();
      keptIds.add(id);
      written.add(
        Transaction(
          id: id,
          accountId: input.accountId,
          date: date,
          amount: line.amount,
          payeeId: payeeId,
          categoryId: onBudget ? line.categoryId : null,
          memo: line.memo,
          cleared: input.cleared,
          approved: input.approved,
          parentTransactionId: primaryId,
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    for (final child in children) {
      if (!keptIds.contains(child.id)) {
        written.add(_deleted(child, now));
      }
    }

    // Only rows whose content changed are written and recorded for undo;
    // untouched rows keep their `updatedAt` (sync is last-writer-wins).
    final changed = [
      for (final t in written)
        if (!_sameContent(before[t.id], t)) t,
    ];
    if (!allowReconciledChange) {
      final reconciled = [
        for (final t in changed)
          if (before[t.id]?.cleared == TransactionClearStatus.reconciled) t.id,
      ];
      if (reconciled.isNotEmpty) {
        throw ReconciledTransactionException(reconciled);
      }
    }
    await _transactionRepository.upsertTransactions(changed);

    // Learning: on a new transaction the payee remembers the category used
    // with it. Edits do not relearn (a one-off correction must not replace
    // the payee's default), rules are never created implicitly and history
    // is never rewritten.
    if (existing == null && payeeId != null && primary.categoryId != null) {
      await _learnPayeeCategory(payeeId, primary.categoryId!);
    }

    final action = TransactionChangeSetAction(
      _transactionRepository,
      _unitOfWork,
      before: {for (final t in changed) t.id: before[t.id]},
      after: {for (final t in changed) t.id: t},
    );
    return TransactionSaveResult(primaryId, action);
  }

  /// Whether [stored] and [next] hold the same content (timestamps aside).
  static bool _sameContent(Transaction? stored, Transaction next) =>
      stored != null &&
      stored.accountId == next.accountId &&
      stored.date == next.date &&
      stored.amount == next.amount &&
      stored.payeeId == next.payeeId &&
      stored.categoryId == next.categoryId &&
      stored.memo == next.memo &&
      stored.cleared == next.cleared &&
      stored.approved == next.approved &&
      stored.isDeleted == next.isDeleted &&
      stored.transferAccountId == next.transferAccountId &&
      stored.transferTransactionId == next.transferTransactionId &&
      stored.parentTransactionId == next.parentTransactionId;

  /// Both accounts of a transfer must use the same currency: the app has
  /// no exchange rates, so the legs would carry the same number in two
  /// currencies.
  Future<void> _ensureSameCurrency(Account? from, String toId) async {
    final to = await _accountRepository.getAccountById(toId);
    if (from != null && to != null && from.currency != to.currency) {
      throw ValidationException(
        'Transfer between ${from.currency} and ${to.currency} accounts',
        TransactionValidationError.currencyMismatch,
      );
    }
  }

  /// Where the category of a transfer [input] goes: on the leg in the
  /// on-budget account when exactly one of the two accounts is on budget;
  /// nowhere otherwise (and for anything that is not a transfer).
  Future<({String? primary, String? counterpart})> _transferCategory(
    TransactionInput input,
  ) async {
    final categoryId = input.categoryId;
    if (!input.isTransfer || categoryId == null) {
      return (primary: null, counterpart: null);
    }
    final from = await _accountRepository.getAccountById(input.accountId);
    final to = await _accountRepository.getAccountById(
      input.transferAccountId!,
    );
    if (from == null || to == null || from.onBudget == to.onBudget) {
      return (primary: null, counterpart: null);
    }
    return from.onBudget
        ? (primary: categoryId, counterpart: null)
        : (primary: null, counterpart: categoryId);
  }

  Transaction _deleted(Transaction t, DateTime now) =>
      t.copyWith(isDeleted: true, updatedAt: now);

  Future<String?> _resolvePayee(TransactionInput input) =>
      resolvePayee(payeeId: input.payeeId, name: input.newPayeeName);

  /// [payeeId] if set; otherwise the id of the payee called [name]
  /// (case-insensitive), creating it when it does not exist yet; `null`
  /// when both are empty.
  Future<String?> resolvePayee({String? payeeId, String? name}) async {
    if (payeeId != null) {
      return payeeId;
    }
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final payees = await _payeeRepository.getAllPayees();
    final existing = payees
        .where((p) => p.name.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      return existing.id;
    }
    final payee = Payee(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    await _payeeRepository.createPayee(payee);
    return payee.id;
  }

  Future<void> _learnPayeeCategory(String payeeId, String categoryId) async {
    final payee = await _payeeRepository.getPayeeById(payeeId);
    if (payee != null && payee.autoCategoryId != categoryId) {
      await _payeeRepository.updatePayee(
        payee.copyWith(autoCategoryId: categoryId),
      );
    }
  }

  /// Fills empty fields of [draft] from the user's rules
  /// ([RuleApplyMode.suggest]): category, payee and memo, never anything
  /// the user already set. Used to pre-fill the form and by quick-add.
  Future<Transaction> suggestWithRules(
    Transaction draft, {
    String? payeeName,
  }) async {
    final rules = _ruleMatchingService;
    if (rules == null) {
      return draft;
    }
    final active = await rules.loadActiveRules();
    if (active.isEmpty) {
      return draft;
    }
    return rules.apply(
      draft,
      active,
      mode: RuleApplyMode.suggest,
      payeeName: payeeName,
    );
  }

  // ---------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------

  /// All rows that belong together with [t]: the transfer counterpart, the
  /// split parent and all its children.
  Future<List<Transaction>> _linkedGroup(Transaction t) async {
    var root = t;
    if (t.parentTransactionId != null) {
      root =
          await _transactionRepository.getTransactionById(
            t.parentTransactionId!,
          ) ??
          t;
    }
    final group = <String, Transaction>{root.id: root, t.id: t};
    if (root.transferTransactionId != null) {
      final other = await _transactionRepository.getTransactionById(
        root.transferTransactionId!,
      );
      if (other != null) {
        group[other.id] = other;
      }
    }
    for (final child in await _transactionRepository.getSplitTransactions(
      root.id,
    )) {
      group[child.id] = child;
    }
    return group.values.toList();
  }

  Future<List<Transaction>> _groupsOf(Iterable<String> ids) async {
    final rows = <String, Transaction>{};
    for (final id in ids.toSet()) {
      if (rows.containsKey(id)) {
        continue;
      }
      final t = await _transactionRepository.getTransactionById(id);
      if (t == null) {
        continue;
      }
      for (final row in await _linkedGroup(t)) {
        rows[row.id] = row;
      }
    }
    return rows.values.toList();
  }

  /// The partner's personal accounts are read-only here: their
  /// transactions live on the partner's phone, so a transfer into one would
  /// have its other leg there.
  Future<void> _ensureNotPartners(Iterable<String?> accountIds) async {
    for (final id in accountIds.nonNulls.toSet()) {
      final account = await _accountRepository.getAccountById(id);
      if (account != null && account.isPartners) {
        throw ValidationException(
          'Account $id is the partner\'s personal account',
          TransactionValidationError.partnerAccount,
        );
      }
    }
  }

  /// Describes what deleting [ids] would delete.
  Future<DeletionPreview> previewDeletion(Iterable<String> ids) async {
    final rows = await _groupsOf(ids);
    return DeletionPreview(
      rowCount: rows.length,
      includesTransfer: rows.any((t) => t.transferTransactionId != null),
      includesSplit: rows.any((t) => t.parentTransactionId != null),
      includesReconciled: rows.any(
        (t) => t.cleared == TransactionClearStatus.reconciled,
      ),
    );
  }

  /// Soft-deletes a transaction together with its transfer counterpart or
  /// its whole split (deleting one split line deletes the split: a split
  /// whose lines do not add up to the parent would corrupt the balances).
  ///
  /// Returns the undo action (also pushed on the undo stack), or `null` if
  /// nothing was deleted.
  Future<TransactionChangeSetAction?> deleteTransaction(
    String id, {
    bool allowReconciledChange = false,
  }) => deleteMany([id], allowReconciledChange: allowReconciledChange);

  /// Soft-deletes several transactions and everything linked to them in
  /// one unit of work with one undo action.
  Future<TransactionChangeSetAction?> deleteMany(
    Iterable<String> ids, {
    bool allowReconciledChange = false,
  }) async {
    final action = await _unitOfWork.run(() async {
      final rows = await _groupsOf(ids);
      if (rows.isEmpty) {
        return null;
      }
      await _ensureNotPartners([
        for (final t in rows) ...[t.accountId, t.transferAccountId],
      ]);
      if (!allowReconciledChange) {
        final reconciled = rows
            .where((t) => t.cleared == TransactionClearStatus.reconciled)
            .map((t) => t.id)
            .toList();
        if (reconciled.isNotEmpty) {
          throw ReconciledTransactionException(reconciled);
        }
      }
      final now = DateTime.now().toUtc();
      final deleted = [for (final t in rows) _deleted(t, now)];
      await _transactionRepository.upsertTransactions(deleted);
      return TransactionChangeSetAction(
        _transactionRepository,
        _unitOfWork,
        before: {for (final t in rows) t.id: t},
        after: {for (final t in deleted) t.id: t},
      );
    });
    if (action != null) {
      _undoService.addAction(action);
      Logger.info('Transactions deleted: ${action.ids.length}');
    }
    return action;
  }

  /// Kept for older callers: deletes several transactions with their
  /// linked rows.
  Future<void> bulkDelete(List<String> ids) => deleteMany(ids);

  // ---------------------------------------------------------------------
  // Field updates
  // ---------------------------------------------------------------------

  Future<TransactionChangeSetAction?> _updateRows(
    Iterable<String> ids,
    Transaction? Function(Transaction t) change, {
    bool allowReconciledChange = false,
    bool includeSplitChildren = false,
  }) async {
    final action = await _unitOfWork.run(() async {
      final before = <String, Transaction>{};
      final after = <String, Transaction>{};
      final now = DateTime.now().toUtc();
      for (final id in ids.toSet()) {
        final t = await _transactionRepository.getTransactionById(id);
        if (t == null) {
          continue;
        }
        // A split changes as a whole: from a line (e.g. in a category's
        // activity list) the change reaches the parent and its siblings.
        final root = !includeSplitChildren || t.parentTransactionId == null
            ? t
            : (await _transactionRepository.getTransactionById(
                    t.parentTransactionId!,
                  ) ??
                  t);
        final targets = [
          root,
          if (includeSplitChildren)
            ...await _transactionRepository.getSplitTransactions(root.id),
        ];
        for (final row in targets) {
          final updated = change(row);
          if (updated == null || updated == row) {
            continue;
          }
          before[row.id] = row;
          after[row.id] = updated.copyWith(updatedAt: now);
        }
      }
      if (after.isEmpty) {
        return null;
      }
      if (!allowReconciledChange) {
        final reconciled = before.values
            .where((t) => t.cleared == TransactionClearStatus.reconciled)
            .map((t) => t.id)
            .toList();
        if (reconciled.isNotEmpty) {
          throw ReconciledTransactionException(reconciled);
        }
      }
      await _transactionRepository.upsertTransactions(after.values.toList());
      return TransactionChangeSetAction(
        _transactionRepository,
        _unitOfWork,
        before: before,
        after: after,
      );
    });
    if (action != null) {
      _undoService.addAction(action);
    }
    return action;
  }

  /// Sets the cleared status of one row (a split changes as a whole, also
  /// when one of its lines is given). Leaving `reconciled` needs
  /// [allowReconciledChange].
  Future<TransactionChangeSetAction?> updateClearingStatus(
    String id,
    TransactionClearStatus status, {
    bool allowReconciledChange = false,
  }) => _updateRows(
    [id],
    (t) => t.copyWith(cleared: status),
    allowReconciledChange: allowReconciledChange,
    includeSplitChildren: true,
  );

  /// Approves a transaction.
  Future<void> approveTransaction(String id) => bulkApprove([id]);

  /// Rejects a transaction (marks as unapproved).
  Future<void> rejectTransaction(String id) => bulkReject([id]);

  /// Approves multiple transactions (a split as a whole).
  Future<TransactionChangeSetAction?> bulkApprove(List<String> ids) =>
      _updateRows(
        ids,
        (t) => t.copyWith(approved: true),
        allowReconciledChange: true,
        includeSplitChildren: true,
      );

  /// Rejects (unapproves) multiple transactions (a split as a whole).
  Future<TransactionChangeSetAction?> bulkReject(List<String> ids) =>
      _updateRows(
        ids,
        (t) => t.copyWith(approved: false),
        allowReconciledChange: true,
        includeSplitChildren: true,
      );

  /// Sets the category of the given rows. Split parents are skipped (their
  /// lines carry the categories), and so are transfer legs unless the
  /// transfer crosses the budget boundary and the row is its on-budget leg
  /// (the leg that may carry a category, see [_transferCategory]).
  Future<TransactionChangeSetAction?> bulkCategorize(
    List<String> ids,
    String categoryId,
  ) async {
    final eligible = <String>[];
    for (final id in ids) {
      final t = await _transactionRepository.getTransactionById(id);
      if (t == null) {
        continue;
      }
      if (t.transferAccountId != null) {
        final from = await _accountRepository.getAccountById(t.accountId);
        final to = await _accountRepository.getAccountById(
          t.transferAccountId!,
        );
        if (from == null || to == null || !from.onBudget || to.onBudget) {
          continue;
        }
      }
      if (await _transactionRepository.isSplitParent(id)) {
        continue;
      }
      eligible.add(id);
    }
    return _updateRows(
      eligible,
      (t) => t.copyWith(categoryId: categoryId),
      allowReconciledChange: true,
    );
  }

  /// Marks a list of transactions as reconciled.
  Future<TransactionChangeSetAction?> markAsReconciled(List<String> ids) =>
      _updateRows(
        ids,
        (t) => t.copyWith(cleared: TransactionClearStatus.reconciled),
        allowReconciledChange: true,
        includeSplitChildren: true,
      );

  /// Whether the row or anything linked to it is reconciled.
  Future<bool> isReconciled(String id) async {
    final t = await _transactionRepository.getTransactionById(id);
    if (t == null) {
      return false;
    }
    final group = await _linkedGroup(t);
    return group.any((r) => r.cleared == TransactionClearStatus.reconciled);
  }

  // ---------------------------------------------------------------------
  // Reconciliation
  // ---------------------------------------------------------------------

  /// Reconciles [accountId] against a bank statement, in one unit of work:
  ///
  /// 1. every `cleared` transaction dated on or before [statementDate] is
  ///    marked `reconciled`;
  /// 2. the cleared balance up to [statementDate] (starting balance + all
  ///    cleared/reconciled rows up to that day) is compared with
  ///    [statementBalance];
  /// 3. if they differ, an uncategorised, reconciled adjustment with
  ///    [adjustmentMemo] is added on [statementDate] (it flows into To Be
  ///    Budgeted like any uncategorised row).
  ///
  /// [clearedBalanceUpTo] reads the cleared balance (the account
  /// repository's `getClearedBalance(id, upTo: ...)`).
  Future<ReconcileResult> reconcile({
    required String accountId,
    required DateTime statementDate,
    required int statementBalance,
    required String adjustmentMemo,
    required Future<int> Function(String accountId, DateTime upTo)
    clearedBalanceUpTo,
  }) async {
    final day = CalendarDate.normalize(statementDate);
    final result = await _unitOfWork.run(() async {
      final candidates = await _transactionRepository.getTransactions(
        filter: TransactionFilter(
          accountIds: [accountId],
          endDate: day,
          clearedStatuses: const [TransactionClearStatus.cleared],
        ),
      );
      final before = {for (final t in candidates) t.id: t};
      await _transactionRepository.markClearedAsReconciled(accountId, day);
      final after = <String, Transaction?>{
        for (final t in candidates)
          t.id: t.copyWith(cleared: TransactionClearStatus.reconciled),
      };

      final cleared = await clearedBalanceUpTo(accountId, day);
      final difference = statementBalance - cleared;
      String? adjustmentId;
      if (difference != 0) {
        final now = DateTime.now().toUtc();
        final adjustment = Transaction(
          id: _uuid.v4(),
          accountId: accountId,
          date: day,
          amount: difference,
          memo: adjustmentMemo,
          cleared: TransactionClearStatus.reconciled,
          createdAt: now,
          updatedAt: now,
        );
        await _transactionRepository.upsertTransactions([adjustment]);
        adjustmentId = adjustment.id;
        after[adjustment.id] = adjustment;
      }
      return ReconcileResult(
        reconciledCount: candidates.length,
        difference: difference,
        adjustmentId: adjustmentId,
        action: TransactionChangeSetAction(
          _transactionRepository,
          _unitOfWork,
          before: before,
          after: after,
        ),
      );
    });
    _undoService.addAction(result.action);
    return result;
  }

  // ---------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------

  /// Searches and filters transactions based on criteria.
  Future<List<Transaction>> searchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
  }) => _transactionRepository.getTransactions(filter: filter, sort: sort);

  /// Watches transactions based on criteria.
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
  }) => _transactionRepository.watchTransactions(filter: filter, sort: sort);

  /// Finds potential duplicates for a given transaction.
  ///
  /// Criteria for duplication:
  /// - Same amount
  /// - Date within +/- 3 days
  /// - Same payee (if set)
  /// - Not the same transaction ID
  Future<List<Transaction>> findPotentialDuplicates(
    Transaction transaction,
  ) async {
    final day = CalendarDate.normalize(transaction.date);
    final candidates = await _transactionRepository.getTransactions(
      filter: TransactionFilter(
        minAmount: transaction.amount,
        maxAmount: transaction.amount,
        startDate: DateTime.utc(day.year, day.month, day.day - 3),
        endDate: DateTime.utc(day.year, day.month, day.day + 3),
        payeeIds: transaction.payeeId != null ? [transaction.payeeId!] : null,
      ),
    );
    return candidates.where((t) => t.id != transaction.id).toList();
  }
}
