import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class NaturalLanguageInputScreen extends ConsumerStatefulWidget {
  const NaturalLanguageInputScreen({super.key});

  @override
  ConsumerState<NaturalLanguageInputScreen> createState() =>
      _NaturalLanguageInputScreenState();
}

class _NaturalLanguageInputScreenState
    extends ConsumerState<NaturalLanguageInputScreen> {
  final TextEditingController _controller = TextEditingController();
  ParsedTransaction? _parsedTransaction;
  bool _isParsing = false;
  Account? _selectedAccount;
  bool _accountInitialized = false;

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      setState(() {
        _parsedTransaction = null;
      });
      return;
    }
    _parseInput(text);
  }

  Future<void> _parseInput(String text) async {
    setState(() {
      _isParsing = true;
    });

    final parser = ref.read(transactionParserProvider);
    final result = await parser.parse(text);

    if (mounted) {
      setState(() {
        _parsedTransaction = result;
        _isParsing = false;
      });
    }
  }

  Future<void> _createTransaction() async {
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
  void _editDetails() {
    final parsed = _parsedTransaction;
    if (parsed == null) {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Initialize account selection
    final accountsAsync = ref.watch(accountsProvider);

    accountsAsync.whenData((accounts) {
      if (!_accountInitialized && accounts.isNotEmpty) {
        // Default to first checking account or just first account
        final defaultAccount = accounts.firstWhere(
          (a) => a.type == AccountType.checking,
          orElse: () => accounts.first,
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
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
              data: (accounts) => DropdownButtonFormField<Account>(
                initialValue: _selectedAccount,
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
                        value: account,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccount = value;
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
                      label: l10n.create,
                      onPressed:
                          (_parsedTransaction!.amount != null &&
                              _selectedAccount != null)
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.preview,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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

            // Amount and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasAmount ? Icons.attach_money : Icons.money_off,
                      color: hasAmount ? amountColor : Colors.grey,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      hasAmount
                          ? '$amountPrefix${fmt.formatMoney(transaction.amount!, currencyCode: currencyCode)}'
                          : l10n.noAmount,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: hasAmount ? amountColor : Colors.grey,
                            fontWeight: FontWeight.bold,
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
              title: Text(transaction.categoryName ?? l10n.uncategorized),
              subtitle: Text(hasCategory ? l10n.category : l10n.uncategorized),
              trailing: hasCategory
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
