import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

class ScheduledTransactionListItem extends ConsumerWidget {
  final ScheduledTransaction transaction;
  final String? payeeName;
  final String? categoryName;
  final String? accountName;

  /// Currency of the account; `null` uses the Settings currency.
  final String? currencyCode;

  /// The account is closed: nothing is booked for this schedule.
  final bool accountClosed;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSkip;

  const ScheduledTransactionListItem({
    super.key,
    required this.transaction,
    this.payeeName,
    this.categoryName,
    this.accountName,
    this.currencyCode,
    this.accountClosed = false,
    this.onTap,
    this.onDelete,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final isIncome = (transaction.amount ?? 0) >= 0;
    final amountColor = isIncome
        ? Colors.green.shade700
        : theme.colorScheme.error;
    final l10n = AppLocalizations.of(context)!;

    String frequencyText = '';
    if (transaction.frequency != null) {
      switch (transaction.frequency!) {
        case RecurrenceFrequency.daily:
          frequencyText = l10n.daily;
          break;
        case RecurrenceFrequency.weekly:
          frequencyText = l10n.weekly;
          break;
        case RecurrenceFrequency.monthly:
          frequencyText = l10n.monthly;
          break;
        case RecurrenceFrequency.yearly:
          frequencyText = l10n.yearly;
          break;
      }
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.calendar_today,
          color: theme.colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              payeeName ?? l10n.unknownPayee,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmt.formatMoney(
              transaction.amount ?? 0,
              currencyCode: currencyCode,
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  categoryName ?? l10n.none,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (transaction.nextDate != null)
                Text(
                  l10n.labelValue(
                    l10n.nextDate,
                    fmt.formatDate(transaction.nextDate!),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (accountName != null)
                Text(
                  accountName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              Text(frequencyText, style: theme.textTheme.bodySmall),
            ],
          ),
          if (accountClosed)
            Text(
              l10n.scheduledAccountClosed,
              key: Key('scheduled.accountClosed.${transaction.id}'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete' && onDelete != null) {
            onDelete!();
          } else if (value == 'skip' && onSkip != null) {
            onSkip!();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'skip',
            child: Row(
              children: [
                Icon(Icons.skip_next, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.skip),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(l10n.delete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
