import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/import/import_undo_dialog.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/import/import_undo_service.dart';
import 'package:ledger_zero/services/import/transaction_import_service.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/utils/logger.dart';

/// The account dropdown value that imports each row into the account its
/// file names ([ImportTransaction.accountName]).
const importAccountFromFileValue = '__account_from_file__';

/// Review of parsed CSV rows: pick the target account (duplicates are
/// detected against that account and re-checked when it changes), see
/// which file categories matched, deselect rows, then import.
class ImportConfirmationScreen extends ConsumerStatefulWidget {
  final List<ImportTransaction> transactions;

  const ImportConfirmationScreen({super.key, required this.transactions});

  @override
  ConsumerState<ImportConfirmationScreen> createState() =>
      _ImportConfirmationScreenState();
}

class _ImportConfirmationScreenState
    extends ConsumerState<ImportConfirmationScreen> {
  late List<ImportTransaction> _transactions;
  List<Account>? _accounts;
  String? _accountId;
  bool _checkingDuplicates = false;
  bool _isImporting = false;

  /// Open accounts by normalised name (for the file's Account and Transfer
  /// columns).
  Map<String, String> _accountIdsByName = const {};

  /// The distinct account names of the file that name an open account.
  List<String> _fileAccountNames = const [];

  /// The distinct account names of the file that name no open account
  /// (unknown, renamed or closed since the export).
  List<String> _unknownAccountNames = const [];

  /// The file has an Account column but some rows leave it empty.
  bool _rowsWithoutAccountName = false;

  @override
  void initState() {
    super.initState();
    // Own copies: the route's objects are never mutated.
    _transactions = [for (final t in widget.transactions) t.copy()];
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts =
          (await ref.read(accountRepositoryProvider).getAllAccounts())
              .where((a) => !a.isClosed && !a.isPartners)
              .toList();
      if (!mounted) {
        return;
      }
      final byName = {
        for (final a in accounts) CsvImportService.normalizePayee(a.name): a.id,
      };
      final fileNames = {
        for (final t in _transactions)
          if (t.accountName != null) t.accountName!,
      };
      bool known(String name) =>
          byName.containsKey(CsvImportService.normalizePayee(name));
      final matched = fileNames.where(known).toList();
      final unknown = fileNames.where((n) => !known(n)).toList();
      final withoutName =
          fileNames.isNotEmpty &&
          _transactions.any((t) => t.accountName == null);
      setState(() {
        _accounts = accounts;
        _accountIdsByName = byName;
        _fileAccountNames = matched;
        _unknownAccountNames = unknown;
        _rowsWithoutAccountName = withoutName;
        // A file that names accounts is never put into one account
        // silently: when every name matches, each row goes into its own
        // account; otherwise the user has to choose (see the banner).
        _accountId = fileNames.isEmpty
            ? accounts.firstOrNull?.id
            : (unknown.isEmpty && !withoutName
                  ? importAccountFromFileValue
                  : null);
      });
      if (_accountId != null) {
        await _checkDuplicates(_accountId!);
      }
    } catch (e, st) {
      Logger.error('Loading accounts for the import failed', e, st);
      if (mounted) {
        setState(() => _accounts = const []);
      }
    }
  }

  /// Sets each row's own account for the "account from file" choice, or
  /// clears it so every row goes into the chosen account.
  void _applyRowAccounts(String accountId) {
    final fromFile = accountId == importAccountFromFileValue;
    for (final t in _transactions) {
      t.accountId = fromFile && t.accountName != null
          ? _accountIdsByName[CsvImportService.normalizePayee(t.accountName!)]
          : null;
    }
  }

  /// The account the rows go into. With "account from file" every
  /// imported row has its own account (rows without one are left out, see
  /// [_isLeftOut]), so the value only satisfies the service's signature.
  String? get _defaultAccountId => _accountId == importAccountFromFileValue
      ? _transactions.map((t) => t.accountId).nonNulls.firstOrNull
      : _accountId;

  /// With "account from file": the row's account name matches no open
  /// account (or the row has none), so the row is not imported.
  bool _isLeftOut(ImportTransaction t) =>
      _accountId == importAccountFromFileValue && t.accountId == null;

  /// The rows "account from file" leaves out: their account name matches
  /// no open account, or they have none.
  int get _unknownRowCount => _transactions
      .where(
        (t) =>
            t.accountName == null ||
            !_accountIdsByName.containsKey(
              CsvImportService.normalizePayee(t.accountName!),
            ),
      )
      .length;

  /// Duplicates only count within the account the rows go into.
  Future<void> _checkDuplicates(String accountId) async {
    setState(() => _checkingDuplicates = true);
    _applyRowAccounts(accountId);
    final defaultAccount = _defaultAccountId;
    try {
      for (final t in _transactions.where(_isLeftOut)) {
        t.isDuplicate = false;
        t.isPossibleDuplicate = false;
      }
      if (defaultAccount != null) {
        await ref.read(transactionImportServiceProvider).markDuplicates([
          for (final t in _transactions)
            if (!_isLeftOut(t)) t,
        ], defaultAccount);
      }
    } catch (e, st) {
      Logger.error('Duplicate check failed', e, st);
    } finally {
      if (mounted) {
        setState(() => _checkingDuplicates = false);
      }
    }
  }

  Future<void> _selectAccount(String? accountId) async {
    if (accountId == null || accountId == _accountId) {
      return;
    }
    setState(() => _accountId = accountId);
    await _checkDuplicates(accountId);
  }

  void _toggleSelection(int index) {
    setState(() {
      _transactions[index].isSelected = !_transactions[index].isSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fmt = ref.watch(appFormatterProvider);
    final categoryNames = ref.watch(categoryMapProvider).valueOrNull ?? {};
    final accounts = _accounts;
    final fromFile = _accountId == importAccountFromFileValue;
    final currency = accounts
        ?.where((a) => a.id == _defaultAccountId)
        .firstOrNull
        ?.currency;
    final selected = _transactions
        .where((t) => t.isSelected && !_isLeftOut(t))
        .toList();
    final unknownAccounts = [
      ..._unknownAccountNames,
      if (_rowsWithoutAccountName) l10n.importRowsWithoutAccount,
    ];
    final total = Money.sum(selected.map((t) => t.amount));
    final duplicateCount = _transactions.where((t) => t.isDuplicate).length;
    final possibleCount = _transactions
        .where((t) => t.isPossibleDuplicate)
        .length;
    final unmatchedCount = _transactions
        .where((t) => t.hasUnmatchedCategory)
        .length;
    final transferCount = fromFile
        ? _transactions.where((t) => t.transferAccountName != null).length
        : 0;
    final busy = _isImporting || _checkingDuplicates;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(l10n.confirmImport)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmImportDescription,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    if (accounts == null)
                      const LinearProgressIndicator()
                    else if (accounts.isEmpty)
                      Text(l10n.createFirstAccountMessage)
                    else
                      DropdownButtonFormField<String>(
                        key: const Key('import_account'),
                        isExpanded: true,
                        initialValue: _accountId,
                        hint: Text(l10n.selectAccount),
                        items: [
                          if (_fileAccountNames.isNotEmpty)
                            DropdownMenuItem(
                              value: importAccountFromFileValue,
                              child: Text(
                                l10n.importAccountFromFile(
                                  _fileAccountNames.join(', '),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          for (final a in accounts)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        onChanged: busy ? null : _selectAccount,
                        decoration: InputDecoration(labelText: l10n.account),
                      ),
                    if (accounts != null &&
                        accounts.isNotEmpty &&
                        unknownAccounts.isNotEmpty)
                      _Banner(
                        key: const Key('import_unknown_accounts'),
                        text: _fileAccountNames.isEmpty
                            ? l10n.importUnknownAccountsNone(
                                unknownAccounts.join(', '),
                              )
                            : l10n.importUnknownAccountsPartial(
                                unknownAccounts.join(', '),
                                _unknownRowCount,
                              ),
                      ),
                    if (duplicateCount > 0)
                      _Banner(text: l10n.deduplicationComplete(duplicateCount)),
                    if (possibleCount > 0)
                      _Banner(
                        text: l10n.importPossibleDuplicatesNearby(
                          possibleCount,
                          CsvImportService.possibleDuplicateWindowDays,
                        ),
                      ),
                    if (unmatchedCount > 0)
                      _Banner(
                        text: l10n.importUnmatchedCategories(unmatchedCount),
                      ),
                    if (transferCount > 0)
                      _Banner(
                        text: l10n.importTransferLegs(transferCount),
                        warning: false,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final category = tx.categoryId == null
                        ? null
                        : categoryNames[tx.categoryId];
                    final leftOut = _isLeftOut(tx);
                    final flagged =
                        leftOut || tx.isDuplicate || tx.isPossibleDuplicate;
                    return CheckboxListTile(
                      value: tx.isSelected && !leftOut,
                      onChanged: busy || leftOut
                          ? null
                          : (v) => _toggleSelection(index),
                      tileColor: flagged
                          ? theme.colorScheme.errorContainer.withValues(
                              alpha: 0.3,
                            )
                          : null,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tx.payeeName ??
                                  (tx.transferAccountName != null
                                      ? l10n.labelValue(
                                          l10n.transfer,
                                          tx.transferAccountName!,
                                        )
                                      : l10n.unknownPayee),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            fmt.formatMoney(tx.amount, currencyCode: currency),
                            style: TextStyle(
                              color: tx.amount < 0
                                  ? AppColors.expense
                                  : AppColors.income,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fromFile && tx.accountName != null
                                ? l10n.labelValue(
                                    fmt.formatDate(tx.date),
                                    tx.accountName!,
                                  )
                                : fmt.formatDate(tx.date),
                          ),
                          if (leftOut)
                            Text(
                              tx.accountName == null
                                  ? l10n.importRowNoAccount
                                  : l10n.importRowAccountNotFound(
                                      tx.accountName!,
                                    ),
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          if (category != null) Text(category),
                          if (tx.hasUnmatchedCategory)
                            Text(
                              l10n.importCategoryNotFound(
                                tx.categoryName!.trim(),
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          if (tx.isDuplicate)
                            Text(
                              l10n.duplicateWarning,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          if (tx.isPossibleDuplicate)
                            Text(
                              tx.possibleDuplicatePayee == null
                                  ? l10n.importPossibleDuplicateOfNoPayee(
                                      fmt.formatDate(
                                        tx.possibleDuplicateDate ?? tx.date,
                                      ),
                                    )
                                  : l10n.importPossibleDuplicateOf(
                                      tx.possibleDuplicatePayee!,
                                      fmt.formatDate(
                                        tx.possibleDuplicateDate ?? tx.date,
                                      ),
                                    ),
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      secondary: flagged || tx.hasUnmatchedCategory
                          ? const Icon(Icons.warning, color: Colors.amber)
                          : const Icon(Icons.receipt),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.importSelectedCount(selected.length),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            l10n.labelValue(
                              l10n.total,
                              fmt.formatMoney(total, currencyCode: currency),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed:
                          selected.isNotEmpty &&
                              !busy &&
                              _defaultAccountId != null
                          ? () => _performImport(selected, _defaultAccountId!)
                          : null,
                      child: Text(l10n.import),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isImporting)
          const ModalBarrier(dismissible: false, color: Colors.black54),
        if (_isImporting) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  /// Takes back the import just made (the success dialog's "Undo import")
  /// and stays on the review, so the user can correct and import again.
  Future<void> _undoImport() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isImporting = true);
    try {
      final done = await ref.read(importUndoServiceProvider).undo();
      if (done != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(undoneMessage(l10n, done))),
        );
      }
    } catch (e, st) {
      Logger.error('Undoing the import failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importUndoFailed)));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
    // The rows are importable again: nothing of them exists any more.
    final accountId = _accountId;
    if (mounted && accountId != null) {
      await _checkDuplicates(accountId);
    }
  }

  Future<void> _performImport(
    List<ImportTransaction> transactions,
    String accountId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final importService = ref.read(transactionImportServiceProvider);

    setState(() => _isImporting = true);

    try {
      // Payee matching, the user's rules and the payee default category are
      // applied by the service, atomically for all rows.
      final count = await importService.importTransactions(
        transactions,
        accountId,
        accountIdsByName: _accountIdsByName,
      );

      if (!mounted) {
        return;
      }
      setState(() => _isImporting = false);
      final undo = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importSuccess),
          content: Text(l10n.importedTransactions(count)),
          actions: [
            // Wrong account, wrong sign, wrong file: take it back at once.
            TextButton(
              key: const Key('import_undo'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.importUndoAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.transactions),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      if (undo == true) {
        await _undoImport();
        return;
      }
      // Navigate with the screen's context once the dialog is gone.
      context.go('/transactions');
    } catch (e, st) {
      Logger.error('Importing transactions failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importFailedGeneric)));
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, this.warning = true});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = warning
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = warning
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              warning ? Icons.warning : Icons.info_outline,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
