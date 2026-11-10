import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/transaction_service_types.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_dialogs.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Key of the quick-add "Create" button (for tests).
const quickAddCreateKey = Key('quick_add_create');

class NaturalLanguageInputScreen extends ConsumerStatefulWidget {
  const NaturalLanguageInputScreen({super.key});

  /// Pause after the last keystroke before the text is parsed.
  static const parseDelay = Duration(milliseconds: 300);

  @override
  ConsumerState<NaturalLanguageInputScreen> createState() =>
      _NaturalLanguageInputScreenState();
}

class _NaturalLanguageInputScreenState
    extends ConsumerState<NaturalLanguageInputScreen> {
  final TextEditingController _controller = TextEditingController();
  ParsedTransaction? _parsedTransaction;

  /// The text [_parsedTransaction] was parsed from.
  String? _parsedText;
  bool _isParsing = false;
  bool _isSaving = false;
  Account? _selectedAccount;
  bool _accountInitialized = false;

  /// Waits for a pause in typing (each parse reads payees and categories).
  Timer? _debounce;

  /// Number of the latest parse request; a slower, older parse that
  /// finishes later never overwrites a newer preview.
  int _parseRequest = 0;

  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _parseRequest++;
      setState(() {
        _parsedTransaction = null;
        _parsedText = null;
        _isParsing = false;
      });
      return;
    }
    _debounce = Timer(
      NaturalLanguageInputScreen.parseDelay,
      () => _parseInput(text),
    );
  }

  Future<void> _parseInput(String text) async {
    final request = ++_parseRequest;
    setState(() {
      _isParsing = true;
    });

    ParsedTransaction? result;
    try {
      result = await ref.read(transactionParserProvider).parse(text);
    } catch (e, stack) {
      Logger.error('Quick add: parsing failed', e, stack);
    }

    if (!mounted || request != _parseRequest) {
      return;
    }
    setState(() {
      _parsedTransaction = result;
      _parsedText = result == null ? null : text;
      _isParsing = false;
    });
  }

  /// Parses text typed since the last preview right away (skipping the
  /// debounce), so what is saved or handed on is what the field says.
  Future<void> _flushParse() async {
    final text = _controller.text;
    if (_parsedText == text) {
      return;
    }
    if (text.trim().isEmpty) {
      _onTextChanged(text);
      return;
    }
    _debounce?.cancel();
    await _parseInput(text);
  }

  Future<void> _createTransaction() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _flushParse();
      if (!mounted) {
        return;
      }
      await _save();
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transactionValidationMessage(AppLocalizations.of(context)!, e),
            ),
          ),
        );
      }
    } catch (e, stack) {
      Logger.error('Quick add: saving failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.txSaveFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_parsedTransaction == null ||
        _selectedAccount == null ||
        _parsedTransaction!.amount == null) {
      return;
    }

    final tx = _parsedTransaction!;
    final service = ref.read(transactionServiceProvider);
    final amount = tx.isIncome ? tx.amount! : -tx.amount!;
    final memo = tx.note ?? _controller.text;

    // Fill what the parser could not find from the user's rules (never
    // overriding what was parsed).
    final suggested = await service.suggestWithRules(
      Transaction(
        id: 'quick-add',
        accountId: _selectedAccount!.id,
        date: _calendarDay(tx.date),
        amount: amount,
        payeeId: tx.payeeId,
        categoryId: tx.categoryId,
        memo: memo,
      ),
      payeeName: tx.payeeName,
    );

    final result = await service.save(
      TransactionInput(
        accountId: _selectedAccount!.id,
        date: _calendarDay(tx.date),
        amount: amount,
        payeeId: suggested.payeeId,
        newPayeeName: suggested.payeeId == null ? tx.payeeName : null,
        categoryId: suggested.categoryId,
        memo: suggested.memo,
      ),
    );

    // Save parsing history (only after a successful save).
    try {
      final saved = await ref
          .read(transactionRepositoryProvider)
          .getTransactionById(result.id);
      await ref
          .read(parsingHistoryRepositoryProvider)
          .addHistory(_controller.text, saved?.payeeId, saved?.categoryId);
    } catch (_) {
      // Ignore history save errors
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.transactionSaved)),
      );
      context.pop();
    }
  }

  /// Hands the parsed values to the full editor and replaces this screen,
  /// so going back from the editor does not return to stale quick-add text.
  Future<void> _editDetails() async {
    await _flushParse();
    final parsed = _parsedTransaction;
    if (parsed == null || !mounted) {
      return;
    }
    final amount = parsed.amount;
    context.pushReplacementNamed(
      'add-transaction',
      extra: TransactionDraft(
        amountText: amount == null
            ? ''
            : ref.read(appFormatterProvider).formatAmountForInput(amount),
        memo: parsed.note ?? _controller.text,
        date: _calendarDay(parsed.date),
        accountId: _selectedAccount?.id,
        payeeId: parsed.payeeId,
        payeeName: parsed.payeeName,
        categoryId: parsed.categoryId,
        formType: parsed.isIncome
            ? TransactionFormType.income
            : TransactionFormType.expense,
      ),
    );
  }

  /// The calendar day (UTC midnight) of a parsed local date, or today.
  DateTime _calendarDay(DateTime? parsed) => parsed == null
      ? CalendarDate.today()
      : CalendarDate.fromLocalPick(parsed);

  /// ISO code for a currency symbol typed in the input, if unambiguous
  /// enough to display; otherwise `null` (falls back to the account).
  static String? _currencyCodeForSymbol(String? symbol) {
    return switch (symbol) {
      '€' => 'EUR',
      '£' => 'GBP',
      '\$' => 'USD',
      _ => null,
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Initialize account selection
    final accountsAsync = ref.watch(writableAccountsProvider);

    accountsAsync.whenData((accounts) {
      if (!_accountInitialized && accounts.isNotEmpty) {
        // The Settings default account, else the first checking account,
        // else the first account.
        final defaultId = ref.read(settingsProvider).defaultAccountId;
        final defaultAccount = accounts.firstWhere(
          (a) => a.id == defaultId && !a.isClosed,
          orElse: () => accounts.firstWhere(
            (a) => a.type == AccountType.checking,
            orElse: () => accounts.first,
          ),
        );

        // Use simple setState via a post-frame callback to avoid build errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedAccount == null) {
            setState(() {
              _selectedAccount = defaultAccount;
              _accountInitialized = true;
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quickAdd),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.quickAddTipsTooltip,
            onPressed: () => _showCheatSheet(context),
          ),
        ],
      ),
      // Scrolls so the preview and buttons stay reachable above the
      // keyboard on small phones.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.quickAddHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                suffixIcon: _isParsing
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onTextChanged('');
                        },
                      ),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Account Selector
            accountsAsync.when(
              // Keyed by id: the accounts stream emits new instances (e.g.
              // with the new balance right after saving), which must still
              // match the selection.
              data: (accounts) => DropdownButtonFormField<String>(
                initialValue: _selectedAccount?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.account,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _selectedAccount = accounts
                        .where((a) => a.id == id)
                        .firstOrNull;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) =>
                  LoadErrorView(error: e, stackTrace: st, compact: true),
            ),

            const SizedBox(height: AppSpacing.md),

            if (_parsedTransaction != null) ...[
              _buildPreviewCard(_parsedTransaction!),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: l10n.editDetails,
                      onPressed: _editDetails,
                      icon: Icons.edit,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.primary(
                      key: quickAddCreateKey,
                      label: l10n.create,
                      isLoading: _isSaving,
                      onPressed:
                          (_parsedTransaction!.amount != null &&
                              _selectedAccount != null &&
                              !_isSaving)
                          ? _createTransaction
                          : null,
                      icon: Icons.check,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ParsedTransaction transaction) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final hasAmount = transaction.amount != null;
    final currencyCode =
        _currencyCodeForSymbol(transaction.currency) ??
        _selectedAccount?.currency;
    final hasPayee = transaction.payeeName != null;
    final hasCategory = transaction.categoryName != null;

    // Determine color based on income/expense
    final amountColor = transaction.isIncome
        ? AppColors.income
        : AppColors.expense;
    final amountPrefix = transaction.isIncome ? '+' : '-';

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.preview,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(transaction.confidence),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    l10n.quickAddConfidence(
                      (transaction.confidence * 100).toInt(),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // Amount and Date (the date wraps below on narrow screens)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasAmount ? Icons.attach_money : Icons.money_off,
                      color: hasAmount ? amountColor : Colors.grey,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        hasAmount
                            ? '$amountPrefix${fmt.formatMoney(transaction.amount!, currencyCode: currencyCode)}'
                            : l10n.noAmount,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: hasAmount ? amountColor : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                if (transaction.date != null)
                  Chip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(fmt.formatDate(_calendarDay(transaction.date))),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Payee
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.payee),
              title: Text(transaction.payeeName ?? l10n.unknownPayee),
              subtitle: Text(hasPayee ? l10n.payee : l10n.payeeNotFound),
              trailing: hasPayee
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : const Icon(Icons.help_outline, color: AppColors.warning),
            ),

            // Category
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.category),
              // An inflow without a category is income for To Be Budgeted,
              // not something left to categorise.
              title: Text(
                transaction.categoryName ??
                    (transaction.isIncome
                        ? l10n.toBeBudgeted
                        : l10n.uncategorized),
              ),
              subtitle: Text(hasCategory ? l10n.category : l10n.uncategorized),
              trailing: hasCategory || transaction.isIncome
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : const Icon(Icons.help_outline, color: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return AppColors.success;
    }
    if (confidence >= 0.5) {
      return AppColors.warning;
    }
    return AppColors.error;
  }

  void _showCheatSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.parsingTips),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.parsingTipsDescription),
              const SizedBox(height: 16),
              Text(
                l10n.quickAddExamplesHeading,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final example in [
                l10n.quickAddExample1,
                l10n.quickAddExample2,
                l10n.quickAddExample3,
                l10n.quickAddExample4,
              ])
                Text(l10n.bulletItem(example)),
              const SizedBox(height: 16),
              Text(
                l10n.quickAddDetectsHeading,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final item in [
                l10n.amount,
                l10n.payee,
                l10n.category,
                l10n.date,
              ])
                Text(l10n.bulletItem(item)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}
