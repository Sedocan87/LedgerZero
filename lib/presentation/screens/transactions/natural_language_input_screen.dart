import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

final _allAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

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
    if (_parsedTransaction == null || _selectedAccount == null || _parsedTransaction!.amount == null) {
      return;
    }

    final tx = _parsedTransaction!;

    // 1. Handle Payee
    String? payeeId = tx.payeeId;
    if (payeeId == null && tx.payeeName != null) {
      // Create new payee
      final newPayee = Payee(
        id: const Uuid().v4(),
        name: tx.payeeName!,
        createdAt: DateTime.now(),
      );
      await ref.read(payeeRepositoryProvider).createPayee(newPayee);
      payeeId = newPayee.id;
    }

    // 2. Create Transaction
    final transaction = Transaction(
      id: const Uuid().v4(),
      accountId: _selectedAccount!.id,
      date: tx.date ?? DateTime.now(),
      amount: tx.isIncome ? tx.amount! : -tx.amount!,
      payeeId: payeeId,
      categoryId: tx.categoryId,
      memo: tx.note ?? _controller.text, // Use original text as memo if no note extracted? Or maybe extracting note is better.
      cleared: TransactionClearStatus.uncleared,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(transactionRepositoryProvider).createTransaction(transaction);

    // Task 494: Save Parsing History
    // We only save if we successfully created the transaction.
    // We save the original input and the final IDs.
    try {
      await ref.read(parsingHistoryRepositoryProvider).addHistory(
        _controller.text,
        payeeId,
        tx.categoryId,
      );
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

  Future<void> _editDetails() async {
    if (_parsedTransaction == null) {
      return;
    }

    // Save as draft to be picked up by AddEditTransactionScreen
    final prefs = ref.read(sharedPreferencesProvider);
    const key = 'draft_transaction_new';

    final draft = {
      'amount': _parsedTransaction!.amount?.toString() ?? '',
      'memo': _controller.text, // Pass full text as memo if no specific note
      'date': (_parsedTransaction!.date ?? DateTime.now()).toIso8601String(),
      'accountId': _selectedAccount?.id,
      'payeeId': _parsedTransaction!.payeeId,
      'payeeName': _parsedTransaction!.payeeName,
      'categoryId': _parsedTransaction!.categoryId,
      'formType': _parsedTransaction!.isIncome ? 1 : 0, // 0: expense, 1: income
    };

    await prefs.setString(key, jsonEncode(draft));

    if (mounted) {
      await context.pushNamed('add-transaction'); // This opens the screen which restores the draft
    }
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
    final accountsAsync = ref.watch(_allAccountsProvider);

    accountsAsync.whenData((accounts) {
       if (!_accountInitialized && accounts.isNotEmpty) {
           // Default to first checking account or just first account
           final defaultAccount = accounts.firstWhere(
             (a) => a.type == AccountType.checking,
             orElse: () => accounts.first
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
                hintText: 'e.g., "Lunch at Mario\'s \$15"',
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
                decoration: InputDecoration(
                  labelText: l10n.account,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: accounts.map((account) => DropdownMenuItem(
                  value: account,
                  child: Text(account.name),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccount = value;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading accounts'),
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
                       onPressed: (_parsedTransaction!.amount != null && _selectedAccount != null)
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
    final hasAmount = transaction.amount != null;
    final hasPayee = transaction.payeeName != null;
    final hasCategory = transaction.categoryName != null;

    // Determine color based on income/expense
    final amountColor = transaction.isIncome ? AppColors.income : AppColors.expense;
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(transaction.confidence),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${(transaction.confidence * 100).toInt()}% ${l10n.confidence}',
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
                     Icon(hasAmount ? Icons.attach_money : Icons.money_off,
                          color: hasAmount ? amountColor : Colors.grey),
                     const SizedBox(width: AppSpacing.xs),
                     Text(
                       hasAmount
                         ? '$amountPrefix${NumberFormat.simpleCurrency(name: transaction.currency ?? '').format(transaction.amount).substring(1)}' // simplistic formatting
                         : l10n.noAmount,
                       style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                         color: hasAmount ? amountColor : Colors.grey,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
                 if (transaction.date != null)
                   Chip(
                     avatar: const Icon(Icons.calendar_today, size: 16),
                     label: Text(DateFormat.yMMMd().format(transaction.date!)),
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
              Text('${l10n.examples}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• "Lunch 15"'),
              const Text('• "Coffee \$5 at Starbucks"'),
              const Text('• "Uber 25 tomorrow"'),
              const Text('• "Salary 3000" (Income)'),
              const SizedBox(height: 16),
              Text('${l10n.appDetects}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• ${l10n.amount}'),
              Text('• ${l10n.payee}'),
              Text('• ${l10n.category}'),
              Text('• ${l10n.date}'),
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
