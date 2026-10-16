import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

final _reconcileAccountProvider = StreamProvider.family
    .autoDispose<Account?, String>((ref, id) {
      return ref.watch(accountRepositoryProvider).watchAccount(id);
    });

/// Cleared balance (starting balance + cleared/reconciled rows) of an
/// account, optionally only up to and including a calendar day.
///
/// This is the figure a bank statement is reconciled against.
final clearedBalanceProvider = FutureProvider.family
    .autoDispose<int, ({String accountId, DateTime? upTo})>((ref, key) {
      // Follows clearing-status edits and new rows.
      ref.watch(ledgerChangesProvider);
      return ref
          .watch(accountRepositoryProvider)
          .getClearedBalance(key.accountId, upTo: key.upTo);
    });

/// Reconciles an account against a bank statement: every cleared
/// transaction up to the statement date becomes reconciled and, if the
/// cleared balance differs from the statement balance, an uncategorised
/// adjustment is created (see `TransactionService.reconcile`).
class ReconciliationScreen extends ConsumerStatefulWidget {
  final String accountId;
  const ReconciliationScreen({super.key, required this.accountId});

  @override
  ConsumerState<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  final _balanceController = TextEditingController();
  DateTime _statementDate = CalendarDate.today();
  bool _busy = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: CalendarDate.toLocalDay(_statementDate),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _statementDate = CalendarDate.fromLocalPick(picked));
    }
  }

  Future<void> _reconcile(Account account) async {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.read(appFormatterProvider);
    final messenger = ScaffoldMessenger.of(context);
    final statementBalance = fmt.parseAmount(_balanceController.text);
    if (statementBalance == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }
    final accountRepository = ref.read(accountRepositoryProvider);
    setState(() => _busy = true);
    try {
      // Fresh read: the preview may be stale.
      final cleared = await accountRepository.getClearedBalance(
        account.id,
        upTo: _statementDate,
      );
      final difference = statementBalance - cleared;
      if (difference != 0) {
        if (!mounted) {
          return;
        }
        final createAdjustment = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.discrepancyFound),
            content: Text(
              l10n.discrepancyMessage(
                fmt.formatMoney(difference, currencyCode: account.currency),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.no),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.yes),
              ),
            ],
          ),
        );
        if (createAdjustment != true) {
          return;
        }
      }

      final result = await ref
          .read(transactionServiceProvider)
          .reconcile(
            accountId: account.id,
            statementDate: _statementDate,
            statementBalance: statementBalance,
            adjustmentMemo: l10n.reconcileAdjustmentMemo,
            clearedBalanceUpTo: (id, day) =>
                accountRepository.getClearedBalance(id, upTo: day),
          );
      final message = result.adjustmentId == null
          ? l10n.reconcileResultMatched(result.reconciledCount)
          : l10n.reconcileResultAdjusted(
              result.reconciledCount,
              fmt.formatMoney(
                result.difference,
                currencyCode: account.currency,
              ),
            );
      messenger.showSnackBar(SnackBar(content: Text(message)));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      Logger.error('Reconciling account ${account.id} failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reconcileFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(_reconcileAccountProvider(widget.accountId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reconcileAccount)),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return Center(child: Text(l10n.accountNotFound));
          }
          return _buildForm(context, account);
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, s) => ErrorView(title: l10n.error, message: l10n.error),
      ),
    );
  }

  Widget _buildForm(BuildContext context, Account account) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    String money(int minor) =>
        fmt.formatMoney(minor, currencyCode: account.currency);

    final cleared = ref.watch(
      clearedBalanceProvider((accountId: account.id, upTo: null)),
    );
    final clearedUpTo = ref.watch(
      clearedBalanceProvider((accountId: account.id, upTo: _statementDate)),
    );
    final statement = fmt.parseAmount(_balanceController.text);
    final difference = statement != null && clearedUpTo.hasValue
        ? statement - clearedUpTo.value!
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AmountRow(
          key: const Key('reconcile.workingBalance'),
          label: l10n.reconcileWorkingBalance,
          value: money(account.balance),
        ),
        _AmountRow(
          key: const Key('reconcile.clearedBalance'),
          label: l10n.reconcileClearedBalance,
          value: cleared.hasValue ? money(cleared.value!) : '…',
        ),
        const Divider(height: 24),
        ListTile(
          key: const Key('reconcile.date'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l10n.reconcileStatementDate),
          subtitle: Text(fmt.formatDate(_statementDate)),
          onTap: _busy ? null : _pickDate,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('reconcile.statementBalance'),
          controller: _balanceController,
          decoration: InputDecoration(
            labelText: l10n.reconcileStatementBalance,
            hintText: l10n.enterActualBalance,
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _AmountRow(
          key: const Key('reconcile.clearedUpTo'),
          label: l10n.reconcileClearedUpToDate,
          value: clearedUpTo.hasValue ? money(clearedUpTo.value!) : '…',
        ),
        _AmountRow(
          key: const Key('reconcile.difference'),
          label: l10n.reconcileDifference,
          value: difference == null ? '-' : money(difference),
          valueStyle: difference == null
              ? null
              : TextStyle(
                  fontWeight: FontWeight.bold,
                  color: difference == 0
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                ),
        ),
        const SizedBox(height: 16),
        Text(l10n.reconcileExplanation, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('reconcile.confirm'),
          onPressed: _busy || statement == null
              ? null
              : () => _reconcile(account),
          child: Text(l10n.reconcile),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
