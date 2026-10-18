import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/widgets/charts/balance_trend_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/core/utils/logger.dart';

final accountDetailProvider = StreamProvider.family
    .autoDispose<Account?, String>((ref, id) {
      return ref.watch(accountRepositoryProvider).watchAccount(id);
    });

/// The account's transactions, newest first; a split is listed once, by
/// its parent (which carries the account-side amount).
final accountTransactionsProvider = StreamProvider.family
    .autoDispose<List<Transaction>, String>((ref, accountId) {
      return ref
          .watch(transactionRepositoryProvider)
          .watchTransactions(
            filter: TransactionFilter(
              accountIds: [accountId],
              excludeSplitChildren: true,
            ),
            sort: const TransactionSort(
              field: TransactionSortField.date,
              ascending: false,
            ),
          );
    });

enum _DeleteAccountChoice { close, delete }

class AccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  Future<void> _setClosed(
    BuildContext context,
    WidgetRef ref,
    bool closed,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (closed && !await _confirmClosingWithSchedules(context, ref)) {
      return;
    }
    try {
      await ref.read(accountServiceProvider).setClosed(accountId, closed);
      if (closed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.accountClosedMessage)),
        );
      }
    } catch (e, st) {
      Logger.error('Closing account $accountId failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountUpdateFailed)));
    }
  }

  /// Scheduled transactions book nothing into a closed account: when some
  /// target this one, the user is told and asked to confirm.
  Future<bool> _confirmClosingWithSchedules(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final schedules = await ref
        .read(scheduledTransactionRepositoryProvider)
        .getAllScheduledTransactions();
    final active = schedules
        .where((s) => s.accountId == accountId && s.nextDate != null)
        .length;
    if (active == 0 || !context.mounted) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('closeAccount.schedulesWarning'),
        title: Text(l10n.closeAccount),
        content: Text(l10n.closeAccountSchedulesWarning(active)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.closeAccount),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Offers closing (recommended) or permanently deleting the account.
  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account? account,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final canClose = account != null && !account.isClosed;
    final choice = await showDialog<_DeleteAccountChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canClose) ...[
                Text(l10n.deleteAccountCloseRecommendation),
                const SizedBox(height: 12),
              ],
              Text(l10n.deleteAccountPermanentWarning),
              const SizedBox(height: 12),
              Text(l10n.deleteAccountTransfersWarning),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (canClose)
            FilledButton(
              key: const Key('deleteAccount.close'),
              onPressed: () =>
                  Navigator.pop(context, _DeleteAccountChoice.close),
              child: Text(l10n.closeAccountInstead),
            ),
          TextButton(
            key: const Key('deleteAccount.delete'),
            onPressed: () =>
                Navigator.pop(context, _DeleteAccountChoice.delete),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.deletePermanently),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    if (choice == _DeleteAccountChoice.close) {
      await _setClosed(context, ref, true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final converted = await ref
          .read(accountServiceProvider)
          .deleteAccount(accountId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountDeletedMessage(converted))),
      );
      if (context.mounted) {
        context.pop();
      }
    } catch (e, st) {
      Logger.error('Deleting account $accountId failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountFailed)));
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getTransactionsByAccount(accountId);
      final payees = await ref.read(payeeRepositoryProvider).getAllPayees();
      final categories = await ref
          .read(categoryRepositoryProvider)
          .getAllCategories();
      await TransactionExportService(
        files: ref.read(exportFileServiceProvider),
      ).exportTransactionsToCsv(
        transactions: transactions,
        payeeNames: {for (final p in payees) p.id: p.name},
        categoryNames: {for (final c in categories) c.id: c.name},
        accountNames: {account.id: account.name},
        filenamePrefix: 'export_${account.name.replaceAll(' ', '_')}',
        shareText: l10n.transactionsShareText,
      );
    } catch (e, st) {
      Logger.error('Exporting account $accountId failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountDetailProvider(accountId));
    final l10n = AppLocalizations.of(context)!;
    // The partner's personal account is read-only here.
    final readOnly = accountAsync.value?.isPartners ?? false;

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (account) => Text(account?.name ?? l10n.accountDetails),
          loading: () => Text(l10n.loading),
          error: (_, _) => Text(l10n.error),
        ),
        actions: [
          if (!readOnly) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.goNamed(
                'edit-account',
                pathParameters: {'id': accountId},
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  await _deleteAccount(context, ref, accountAsync.value);
                } else if (value == 'close') {
                  final account = accountAsync.value;
                  if (account != null) {
                    await _setClosed(context, ref, !account.isClosed);
                  }
                } else if (value == 'reconcile') {
                  context.goNamed(
                    'reconcile-account',
                    pathParameters: {'id': accountId},
                  );
                } else if (value == 'export') {
                  final account = accountAsync.value;
                  if (account != null) {
                    await _export(context, ref, account);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reconcile',
                  child: Text(l10n.reconcileAccount),
                ),
                PopupMenuItem(value: 'export', child: Text(l10n.exportToCsv)),
                PopupMenuItem(
                  value: 'close',
                  child: Text(
                    accountAsync.value?.isClosed == true
                        ? l10n.reopenAccount
                        : l10n.closeAccount,
                  ),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.deleteAccount)),
              ],
            ),
          ],
        ],
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return Center(child: Text(l10n.accountNotFound));
          }
          if (account.isPartners) {
            return _PartnerAccountView(account: account);
          }
          return Column(
            children: [
              TransactionListChartWrapper(
                accountId: accountId,
                startingBalance: account.startingBalance,
                currencyCode: account.currency,
              ),
              Expanded(
                child: TransactionList(
                  accountId: accountId,
                  currency: account.currency,
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, s) => LoadErrorView(error: e, stackTrace: s),
      ),
    );
  }
}

/// The partner's personal account: its balance as their phone shared it,
/// and why there are no transactions.
class _PartnerAccountView extends ConsumerWidget {
  const _PartnerAccountView({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountBalanceLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  ref
                      .watch(appFormatterProvider)
                      .formatMoney(
                        account.balance,
                        currencyCode: account.currency,
                      ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          key: const Key('account.partnerNotice'),
          color: theme.colorScheme.secondaryContainer,
          child: ListTile(
            leading: Icon(
              Icons.lock_person_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            title: Text(
              l10n.accountPartnerTitle,
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
            subtitle: Text(
              l10n.accountPartnerBody,
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ),
      ],
    );
  }
}

class TransactionListChartWrapper extends ConsumerWidget {
  final String accountId;
  final int startingBalance;
  final String? currencyCode;
  const TransactionListChartWrapper({
    super.key,
    required this.accountId,
    required this.startingBalance,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));
    return transactionsAsync.when(
      data: (transactions) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: BalanceTrendChart(
              transactions: transactions,
              startingBalance: startingBalance,
              currencyCode: currencyCode,
            ),
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class TransactionList extends ConsumerWidget {
  final String accountId;
  final String currency;

  const TransactionList({
    super.key,
    required this.accountId,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));
    final payeeNames = ref.watch(payeeMapProvider).valueOrNull ?? const {};
    final accountNames = ref.watch(accountMapProvider).valueOrNull ?? const {};
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: l10n.noTransactions,
            description: l10n.emptyAccountTransactionsMessage,
            actionLabel: l10n.addTransaction,
            onAction: () =>
                context.push('/add-transaction?accountId=$accountId'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final t = transactions[index];
            final String title;
            String subtitle = fmt.formatDate(t.date);
            final isTransfer = t.transferAccountId != null;
            if (isTransfer) {
              final other = accountNames[t.transferAccountId];
              title = other == null
                  ? l10n.transfer
                  : t.amount < 0
                  ? l10n.transferToAccount(other)
                  : l10n.transferFromAccount(other);
              if (t.memo != null && t.memo!.isNotEmpty) {
                subtitle = '$subtitle · ${t.memo}';
              }
            } else {
              title = payeeNames[t.payeeId] ?? t.memo ?? l10n.unknownPayee;
            }

            final isIncome = t.amount >= 0;
            final amountColor = isIncome
                ? (isDark ? Colors.green.shade300 : AppColors.income)
                : (isDark ? Colors.red.shade300 : AppColors.expense);
            final iconData = isTransfer
                ? Icons.swap_horiz_rounded
                : (isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => context.push('/edit-transaction/${t.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconData, color: amountColor, size: 20),
                  ),
                  title: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    fmt.formatMoney(t.amount, currencyCode: currency),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const AppLoadingIndicator(),
      error: (e, s) => LoadErrorView(error: e, stackTrace: s),
    );
  }
}
