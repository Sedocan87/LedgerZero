import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/form_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_dialogs.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_form_body.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_form_controller.dart';
import 'package:ledger_zero/presentation/screens/transactions/transaction_tutorial_manager.dart';
import 'package:uuid/uuid.dart';

export 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart'
    show TransactionDraft, TransactionFormType;

/// Adds or edits a normal, transfer or split transaction.
///
/// The screen only collects input; every write goes through
/// [TransactionService] (transfer counterparts, split children, undo,
/// reconciled-change confirmation). For an existing transfer the form
/// always edits the outflow leg (opening the inflow leg follows its link),
/// so "From" and "To" keep their meaning and the direction is preserved.
class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? initialAccountId;

  /// Pre-filled values (e.g. from quick-add's "Edit details").
  final TransactionDraft? draft;

  const AddEditTransactionScreen({
    super.key,
    this.transactionId,
    this.initialAccountId,
    this.draft,
  });

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  static const _draftKey = 'draft_transaction_new';

  final _formKey = GlobalKey<FormState>();
  final _form = TransactionFormController();
  final _payeeFocus = FocusNode();
  final _tutorialKeys = TransactionTutorialKeys();
  Timer? _autosaveTimer;
  bool _saving = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _payeeFocus.addListener(_onPayeeFocusChanged);
    if (_isEditing) {
      _load(widget.transactionId!);
    } else {
      _form.accountId = widget.initialAccountId;
      final draft = widget.draft ?? _readAutosavedDraft();
      if (draft != null) {
        _form.applyDraft(draft);
      }
      _form.addListener(_scheduleAutosave);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TransactionTutorialManager.showTutorial(context, ref, _tutorialKeys);
      }
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _payeeFocus.dispose();
    _form.dispose();
    super.dispose();
  }

  // --- Loading -----------------------------------------------------------

  Future<void> _load(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    var t = await repo.getTransactionById(id);
    if (t != null && t.transferTransactionId != null && t.amount > 0) {
      // Edit transfers from their outflow leg ("From" -> "To").
      t = await repo.getTransactionById(t.transferTransactionId!) ?? t;
    }
    if (t == null || !mounted) {
      return;
    }
    if (t.parentTransactionId != null) {
      // A split line is edited as part of its split.
      t = await repo.getTransactionById(t.parentTransactionId!) ?? t;
    }
    // A transfer's category sits on its on-budget leg, which is the inflow
    // leg when money comes in from an off-budget account.
    final counterpartCategory =
        t.transferTransactionId != null && t.categoryId == null
        ? (await repo.getTransactionById(t.transferTransactionId!))?.categoryId
        : null;
    final children = await repo.getSplitTransactions(t.id);
    final payee = t.payeeId == null
        ? null
        : await ref.read(payeeRepositoryProvider).getPayeeById(t.payeeId!);
    if (!mounted) {
      return;
    }
    _form.load(
      t,
      children: children,
      payeeName: payee?.name,
      fmt: ref.read(appFormatterProvider),
    );
    if (counterpartCategory != null) {
      _form.categoryId = counterpartCategory;
      _form.changed();
    }
  }

  // --- Draft autosave (new transactions) ---------------------------------

  TransactionDraft? _readAutosavedDraft() {
    try {
      final json = ref.read(sharedPreferencesProvider).getString(_draftKey);
      return json == null
          ? null
          : TransactionDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      Logger.warning('Ignoring unreadable transaction draft: $e');
      return null;
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      ref
          .read(sharedPreferencesProvider)
          .setString(_draftKey, jsonEncode(_form.toDraft().toJson()));
    });
  }

  Future<void> _clearDraft() async {
    _autosaveTimer?.cancel();
    await ref.read(sharedPreferencesProvider).remove(_draftKey);
  }

  // --- Suggestions --------------------------------------------------------

  Future<void> _onPayeeSelected(Payee payee) async {
    _form.selectPayee(payee);
    if (!_isEditing &&
        _form.accountId == null &&
        payee.defaultAccountId != null) {
      _form.accountId = payee.defaultAccountId;
      _form.changed();
    }
    if (_form.categoryId == null && !_form.isSplit) {
      if (payee.autoCategoryId != null) {
        _form.categoryId = payee.autoCategoryId;
        _form.changed();
      } else {
        await _suggestFromRules(payee.name);
      }
    }
  }

  void _onPayeeFocusChanged() {
    final name = _form.payeeController.text.trim();
    if (!_payeeFocus.hasFocus &&
        _form.payeeId == null &&
        name.isNotEmpty &&
        _form.categoryId == null &&
        !_form.isSplit &&
        !_form.isTransfer) {
      _suggestFromRules(name);
    }
  }

  /// Pre-fills empty fields from the user's rules; never overrides what the
  /// user chose.
  Future<void> _suggestFromRules(String payeeName) async {
    final fmt = ref.read(appFormatterProvider);
    final suggestion = await ref
        .read(transactionServiceProvider)
        .suggestWithRules(
          Transaction(
            id: 'draft',
            accountId: _form.accountId ?? '',
            date: _form.date,
            amount: _form.signedAmount(fmt) ?? 0,
            payeeId: _form.payeeId,
            categoryId: _form.categoryId,
            memo: _form.memoController.text.isEmpty
                ? null
                : _form.memoController.text,
          ),
          payeeName: payeeName,
        );
    if (!mounted) {
      return;
    }
    if (_form.categoryId == null && suggestion.categoryId != null) {
      _form.categoryId = suggestion.categoryId;
    }
    if (_form.memoController.text.isEmpty && suggestion.memo != null) {
      _form.memoController.text = suggestion.memo!;
    }
    _form.changed();
  }

  // --- Saving -------------------------------------------------------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit({bool popAfterSave = true}) async {
    if (_saving) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      FormUtils.focusFirstError(context);
      return;
    }
    final accounts = <String, Account>{
      for (final a in ref.read(accountsProvider).valueOrNull ?? const [])
        a.id: a,
    };
    final built = _form.buildInput(
      ref.read(appFormatterProvider),
      categoryAllowed: _form.categoryAllowed(accounts),
    );
    final input = built.input;
    if (input == null) {
      _showMessage(switch (built.error!) {
        TransactionFormError.invalidAmount => l10n.invalidAmount,
        TransactionFormError.missingAccount ||
        TransactionFormError.missingTransferAccount => l10n.selectAccount,
        TransactionFormError.sameTransferAccount => l10n.txTransferSameAccount,
        TransactionFormError.splitLineInvalid => l10n.txSplitLineZero,
        TransactionFormError.splitSumMismatch => l10n.txSplitSumMismatch,
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = _form.isRecurring && !_isEditing
          ? await _saveRecurring(input)
          : await _save(input);
      if (!saved || !mounted) {
        return;
      }
      if (!_isEditing) {
        await _clearDraft();
      }
      if (!mounted) {
        return;
      }
      _showMessage(
        _form.isRecurring ? l10n.txScheduledCreated : l10n.transactionSaved,
      );
      if (popAfterSave) {
        context.pop();
      } else {
        _form.resetForNext();
      }
    } on ValidationException catch (e) {
      if (mounted) {
        _showMessage(transactionValidationMessage(l10n, e));
      }
    } catch (e, stackTrace) {
      Logger.error('Saving the transaction failed', e, stackTrace);
      if (mounted) {
        _showMessage(l10n.txSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Saves through the service; asks first if a reconciled row changes.
  Future<bool> _save(TransactionInput input) async {
    final service = ref.read(transactionServiceProvider);
    try {
      await service.save(input);
      return true;
    } on ReconciledTransactionException {
      if (!mounted || !await confirmReconciledChange(context)) {
        return false;
      }
      await service.save(input, allowReconciledChange: true);
      return true;
    }
  }

  Future<bool> _saveRecurring(TransactionInput input) async {
    final l10n = AppLocalizations.of(context)!;
    if (input.isSplit) {
      _showMessage(l10n.txRecurringSplitUnsupported);
      return false;
    }
    if (input.isTransfer) {
      _showMessage(l10n.txRecurringTransferUnsupported);
      return false;
    }
    final payeeId = await ref
        .read(transactionServiceProvider)
        .resolvePayee(payeeId: input.payeeId, name: input.newPayeeName);
    await ref
        .read(scheduledTransactionRepositoryProvider)
        .createScheduledTransaction(
          ScheduledTransaction(
            id: const Uuid().v4(),
            accountId: input.accountId,
            amount: input.amount,
            payeeId: payeeId,
            categoryId: input.categoryId,
            memo: input.memo,
            frequency: _form.frequency,
            nextDate: input.date,
            anchorDay: input.date.day,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    return true;
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _submit,
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing ? l10n.editTransaction : l10n.addTransaction,
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                key: _tutorialKeys.save,
                icon: const Icon(Icons.check),
                tooltip: l10n.save,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: TransactionFormBody(
                controller: _form,
                tutorialKeys: _tutorialKeys,
                payeeFocus: _payeeFocus,
                onSubmit: _submit,
                onPayeeSelected: _onPayeeSelected,
                onSaveAndAddAnother: _isEditing
                    ? null
                    : () => _submit(popAfterSave: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
