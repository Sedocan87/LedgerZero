import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/split_editor.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';

/// Why the form cannot be turned into a [TransactionInput].
enum TransactionFormError {
  invalidAmount,
  missingAccount,
  missingTransferAccount,
  sameTransferAccount,
  splitLineInvalid,
  splitSumMismatch,
}

/// State of the add/edit transaction form.
///
/// Holds ids (not entity objects) for account, payee and category, so the
/// widgets resolve display names from whatever lists are loaded at build
/// time and nothing is lost when a list loads late. All ledger logic
/// (transfer counterparts, split children, deletes) lives in
/// `TransactionService`; this class only converts between form fields and
/// `TransactionInput`.
class TransactionFormController extends ChangeNotifier {
  TransactionFormController({DateTime? today})
    : date = today ?? CalendarDate.today();

  final amountController = TextEditingController();
  final memoController = TextEditingController();
  final payeeController = TextEditingController();

  TransactionFormType formType = TransactionFormType.expense;

  /// Calendar day (UTC midnight).
  DateTime date;
  String? accountId;
  String? transferAccountId;

  /// Selected existing payee; `null` means the payee text (if any) is a new
  /// name.
  String? payeeId;
  String? _payeeIdName;
  String? categoryId;
  TransactionClearStatus cleared = TransactionClearStatus.uncleared;

  /// Cleared status of the transfer's other leg (the "To" account).
  TransactionClearStatus counterpartCleared = TransactionClearStatus.uncleared;

  /// Whether the row is approved. Loaded from the stored row, so an edit
  /// never approves a captured or scheduled row by accident; new rows are
  /// approved.
  bool approved = true;

  bool isSplit = false;
  final List<SplitItem> splits = [];

  bool isRecurring = false;
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly;

  /// Id of the row being edited (for a transfer: its outflow leg).
  String? editingId;

  /// Cleared status the edited row had when it was loaded.
  TransactionClearStatus? loadedCleared;

  /// Cleared status the counterpart leg had when it was loaded.
  TransactionClearStatus? loadedCounterpartCleared;

  /// The accounts of the edited row and of its counterpart when loaded.
  /// A reconciled status belongs to the reconciliation of that account: a
  /// leg moved to another account is not reconciled there (see
  /// [pickAccount]).
  String? loadedAccountId;
  String? loadedTransferAccountId;

  /// The category the form had before it became an inflow (see
  /// [setFormType]); it comes back when the form leaves inflow without a
  /// category.
  String? _categoryBeforeInflow;

  bool get isTransfer => formType == TransactionFormType.transfer;
  bool get isInflow => formType == TransactionFormType.income;
  bool get isEditing => editingId != null;

  /// Whether the transaction can have a category, given [accounts] (id ->
  /// account). Categories only exist in the budget: a transaction of an
  /// off-budget account has none, and a transfer has one only when it moves
  /// money out of or into the budget (exactly one side off budget).
  bool categoryAllowed(Map<String, Account> accounts) {
    bool? onBudget(String? id) => accounts[id]?.onBudget;
    if (isTransfer) {
      final from = onBudget(accountId);
      final to = onBudget(transferAccountId);
      return from != null && to != null && from != to;
    }
    return onBudget(accountId) ?? true;
  }

  /// Notifies listeners after a field changed.
  void changed() => notifyListeners();

  /// Switches between outflow, inflow and transfer.
  ///
  /// Income belongs in To Be Budgeted: only an inflow without a category
  /// reaches it. A category carried over from the outflow the form showed
  /// before (the Settings default, a payee's, or one picked for the
  /// outflow) would book the income into that category unnoticed, so
  /// becoming an inflow drops it. A refund gets its category picked while
  /// the form is an inflow.
  void setFormType(TransactionFormType type) {
    final wasInflow = isInflow;
    formType = type;
    if (type == TransactionFormType.transfer) {
      isSplit = false;
    }
    if (isInflow && !wasInflow) {
      _categoryBeforeInflow = categoryId;
      categoryId = null;
    } else if (wasInflow && !isInflow) {
      categoryId ??= _categoryBeforeInflow;
      _categoryBeforeInflow = null;
    }
    notifyListeners();
  }

  void setSplit(bool value) {
    isSplit = value;
    if (value) {
      isRecurring = false;
      while (splits.length < 2) {
        splits.add(SplitItem());
      }
    }
    notifyListeners();
  }

  void setCleared(bool value) {
    cleared = _toggled(
      value,
      accountId == loadedAccountId ? loadedCleared : null,
    );
    notifyListeners();
  }

  /// The switch of the transfer's other leg.
  void setCounterpartCleared(bool value) {
    counterpartCleared = _toggled(
      value,
      transferAccountId == loadedTransferAccountId
          ? loadedCounterpartCleared
          : null,
    );
    notifyListeners();
  }

  /// The user picked the (From) account [id]. A reconciled row moved to
  /// another account starts uncleared there; moved back, it gets its
  /// loaded status again.
  void pickAccount(String id) {
    accountId = id;
    cleared = _statusAfterMove(
      cleared,
      moved: id != loadedAccountId,
      loaded: loadedCleared,
    );
    notifyListeners();
  }

  /// The user picked the To account [id] of a transfer; its leg is treated
  /// like the row in [pickAccount].
  void pickTransferAccount(String id) {
    transferAccountId = id;
    counterpartCleared = _statusAfterMove(
      counterpartCleared,
      moved: id != loadedTransferAccountId,
      loaded: loadedCounterpartCleared,
    );
    notifyListeners();
  }

  TransactionClearStatus _statusAfterMove(
    TransactionClearStatus current, {
    required bool moved,
    required TransactionClearStatus? loaded,
  }) {
    if (!isEditing) {
      return current;
    }
    if (moved) {
      return current == TransactionClearStatus.reconciled
          ? TransactionClearStatus.uncleared
          : current;
    }
    return loaded ?? current;
  }

  /// Switching on returns to `reconciled` when the row was reconciled.
  static TransactionClearStatus _toggled(
    bool value,
    TransactionClearStatus? loaded,
  ) => !value
      ? TransactionClearStatus.uncleared
      : (loaded == TransactionClearStatus.reconciled
            ? TransactionClearStatus.reconciled
            : TransactionClearStatus.cleared);

  /// The user picked [payee] from the suggestions.
  void selectPayee(Payee payee) {
    payeeId = payee.id;
    _payeeIdName = payee.name;
    if (payeeController.text != payee.name) {
      payeeController.text = payee.name;
    }
    notifyListeners();
  }

  /// The payee text changed by typing: a selected payee is forgotten as
  /// soon as the text no longer is its name (so it can be cleared or
  /// replaced).
  void payeeTextChanged(String text) {
    if (payeeId != null && text.trim() != _payeeIdName) {
      payeeId = null;
      _payeeIdName = null;
    }
    notifyListeners();
  }

  /// Shows [name] for the already selected [id] (edit mode, drafts).
  void setPayee(String? id, String? name) {
    payeeId = id;
    _payeeIdName = id == null ? null : name;
    payeeController.text = name ?? '';
  }

  /// Whether the form holds something the user typed (see
  /// [TransactionDraft.hasContent]): what makes a new transaction worth a
  /// draft, and worth asking before it is thrown away.
  bool get hasContent => toDraft().hasContent;

  /// Every value the user can change, as one string: two equal fingerprints
  /// mean nothing was edited in between.
  String fingerprint() => jsonEncode({
    ...toDraft().toJson(),
    'date': date.toIso8601String(),
    'cleared': cleared.index,
    'counterpartCleared': counterpartCleared.index,
    'approved': approved,
  });

  /// Fills the form from the autosaved draft of a new transaction that was
  /// interrupted (the app was closed while the form was open).
  ///
  /// Unlike [applyDraft] it keeps the form's date (today: a draft from last
  /// week must not backdate what is entered now) and an account the form
  /// already has (the caller opened it from that account's screen).
  void restoreDraft(TransactionDraft draft) {
    final today = date;
    final account = accountId;
    applyDraft(draft);
    date = today;
    if (account != null) {
      accountId = account;
      if (transferAccountId == account) {
        transferAccountId = null;
      }
    }
    notifyListeners();
  }

  /// An empty new transaction in [accountId], dated today.
  void reset({String? accountId}) {
    date = CalendarDate.today();
    this.accountId = accountId;
    formType = TransactionFormType.expense;
    frequency = RecurrenceFrequency.monthly;
    resetForNext();
  }

  /// Fills the form from the quick-add hand-off.
  void applyDraft(TransactionDraft draft) {
    amountController.text = draft.amountText;
    memoController.text = draft.memo ?? '';
    if (draft.date != null) {
      date = CalendarDate.normalize(draft.date!);
    }
    accountId = draft.accountId ?? accountId;
    transferAccountId = draft.transferAccountId;
    setPayee(draft.payeeId, draft.payeeName);
    categoryId = draft.categoryId;
    formType = draft.formType;
    _replaceSplits(draft.splits.map(SplitItem.fromDraft));
    isSplit = draft.isSplit;
    isRecurring = draft.isRecurring;
    frequency = draft.frequency;
    notifyListeners();
  }

  /// The form as the autosaved draft. Without the date: a draft is
  /// restored on another day, and the date it was typed on is not the date
  /// of what is entered then.
  TransactionDraft toDraft() => TransactionDraft(
    amountText: amountController.text,
    memo: memoController.text.isEmpty ? null : memoController.text,
    accountId: accountId,
    payeeId: payeeId,
    payeeName: payeeController.text.isEmpty ? null : payeeController.text,
    categoryId: categoryId,
    formType: formType,
    transferAccountId: transferAccountId,
    splits: isSplit ? [for (final s in splits) s.toDraft()] : const [],
    isRecurring: isRecurring,
    frequency: frequency,
  );

  /// Fills the form from a stored transaction (the outflow leg for a
  /// transfer, with its [counterpart]) and its split [children].
  void load(
    Transaction t, {
    required List<Transaction> children,
    required String? payeeName,
    required AppFormatter fmt,
    Transaction? counterpart,
  }) {
    editingId = t.id;
    loadedCleared = t.cleared;
    loadedCounterpartCleared = counterpart?.cleared;
    loadedAccountId = t.accountId;
    loadedTransferAccountId = counterpart?.accountId;
    counterpartCleared =
        counterpart?.cleared ?? TransactionClearStatus.uncleared;
    approved = t.approved;
    formType = t.transferAccountId != null
        ? TransactionFormType.transfer
        : (t.amount > 0
              ? TransactionFormType.income
              : TransactionFormType.expense);
    final sign = t.amount > 0 ? 1 : -1;
    amountController.text = fmt.formatAmountForInput(t.amount.abs());
    memoController.text = t.memo ?? '';
    date = CalendarDate.normalize(t.date);
    accountId = t.accountId;
    transferAccountId = t.transferAccountId;
    setPayee(t.payeeId, payeeName);
    categoryId = t.categoryId;
    cleared = t.cleared;
    isSplit = children.isNotEmpty;
    _replaceSplits(
      children.map(
        (c) => SplitItem(
          id: c.id,
          categoryId: c.categoryId,
          // Shown relative to the transaction's direction.
          amountText: fmt.formatAmountForInput(c.amount * sign),
          memo: c.memo,
        ),
      ),
    );
    notifyListeners();
  }

  void _replaceSplits(Iterable<SplitItem> items) {
    for (final s in splits) {
      s.dispose();
    }
    splits
      ..clear()
      ..addAll(items);
  }

  /// Clears the form for the next entry, keeping account and date.
  void resetForNext() {
    amountController.clear();
    memoController.clear();
    setPayee(null, null);
    categoryId = null;
    _categoryBeforeInflow = null;
    transferAccountId = null;
    cleared = TransactionClearStatus.uncleared;
    counterpartCleared = TransactionClearStatus.uncleared;
    approved = true;
    isSplit = false;
    isRecurring = false;
    _replaceSplits(const []);
    notifyListeners();
  }

  /// The signed amount the form describes, or `null` if not parseable.
  int? signedAmount(AppFormatter fmt) {
    final value = fmt.parseAmount(amountController.text)?.abs();
    if (value == null || value == 0) {
      return null;
    }
    return formType == TransactionFormType.income ? value : -value;
  }

  /// Converts the form into a service input, or returns the first problem.
  ///
  /// [categoryAllowed] is [TransactionFormController.categoryAllowed] for
  /// the current accounts; without it the category is dropped.
  ({TransactionInput? input, TransactionFormError? error}) buildInput(
    AppFormatter fmt, {
    bool categoryAllowed = true,
  }) {
    final amount = signedAmount(fmt);
    if (amount == null) {
      return (input: null, error: TransactionFormError.invalidAmount);
    }
    if (accountId == null) {
      return (input: null, error: TransactionFormError.missingAccount);
    }
    if (isTransfer) {
      if (transferAccountId == null) {
        return (
          input: null,
          error: TransactionFormError.missingTransferAccount,
        );
      }
      if (transferAccountId == accountId) {
        return (input: null, error: TransactionFormError.sameTransferAccount);
      }
    }
    final sign = amount > 0 ? 1 : -1;
    final lines = <SplitLineInput>[];
    if (isSplit && !isTransfer) {
      for (final item in splits) {
        final value = fmt.parseAmount(item.amountController.text);
        if (value == null || value == 0) {
          return (input: null, error: TransactionFormError.splitLineInvalid);
        }
        lines.add(
          SplitLineInput(
            id: item.id,
            amount: sign * value,
            categoryId: item.categoryId,
            memo: item.memoController.text.isEmpty
                ? null
                : item.memoController.text,
          ),
        );
      }
      if (Money.sum(lines.map((l) => l.amount)) != amount) {
        return (input: null, error: TransactionFormError.splitSumMismatch);
      }
    }
    final payeeName = payeeController.text.trim();
    return (
      input: TransactionInput(
        id: editingId,
        accountId: accountId!,
        date: date,
        amount: amount,
        payeeId: isTransfer ? null : payeeId,
        newPayeeName: isTransfer || payeeId != null || payeeName.isEmpty
            ? null
            : payeeName,
        categoryId: isSplit || !categoryAllowed ? null : categoryId,
        memo: memoController.text.isEmpty ? null : memoController.text,
        cleared: cleared,
        approved: approved,
        transferAccountId: isTransfer ? transferAccountId : null,
        counterpartCleared: isTransfer ? counterpartCleared : null,
        splits: lines,
      ),
      error: null,
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    memoController.dispose();
    payeeController.dispose();
    _replaceSplits(const []);
    super.dispose();
  }
}
