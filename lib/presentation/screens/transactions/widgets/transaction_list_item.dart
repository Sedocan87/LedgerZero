import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';

class TransactionListItem extends ConsumerWidget {
  final Transaction transaction;
  final String? payeeName;
  final String? categoryName;
  final String? accountName;

  /// Currency of the transaction's account; `null` uses the Settings
  /// currency.
  final String? currencyCode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<TransactionClearStatus>? onClearStatusChanged;
  final bool isSelected;
  final bool isSelectionMode;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.payeeName,
    this.categoryName,
    this.accountName,
    this.currencyCode,
    this.onTap,
    this.onLongPress,
    this.onClearStatusChanged,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Color coding
    final isIncome = transaction.amount >= 0;
    final amountColor = isIncome ? AppColors.income : theme.colorScheme.error;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.2,
      ),
      leading: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onTap?.call())
          : _buildClearedStatus(context, l10n),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              // Payee
              payeeName ?? l10n.transactionNoPayee,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!transaction.approved) ...[
            Tooltip(
              message: l10n.transactionNotApproved,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.tertiary,
                semanticLabel: l10n.transactionNotApproved,
              ),
            ),
            const SizedBox(width: 4),
          ],
          AmountText(
            // Amount
            transaction.amount,
            currencyCode: currencyCode,
            amountContext: AmountContext.transaction,
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
                  // Category
                  categoryName ?? l10n.uncategorized,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // Date
                fmt.formatDate(transaction.date),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (accountName != null) ...[
            const SizedBox(height: 2),
            Text(
              accountName!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Cleared status indicator
  //
  // The icon stays 20 px; the tappable area is at least
  // kMinInteractiveDimension (48 x 48).
  Widget _buildClearedStatus(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final (
      IconData icon,
      Color color,
      String status,
    ) = switch (transaction.cleared) {
      TransactionClearStatus.reconciled => (
        Icons.lock,
        AppColors.success,
        l10n.transactionStatusReconciled,
      ),
      TransactionClearStatus.cleared => (
        Icons.check_circle,
        AppColors.success,
        l10n.cleared,
      ),
      TransactionClearStatus.uncleared => (
        Icons.check_circle_outline,
        theme.colorScheme.onSurfaceVariant,
        l10n.uncleared,
      ),
    };

    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: onClearStatusChanged != null
          ? l10n.transactionClearStatusTooltip(status)
          : status,
      onPressed: onClearStatusChanged == null
          ? null
          : () {
              final next = transaction.cleared == TransactionClearStatus.cleared
                  ? TransactionClearStatus.uncleared
                  : TransactionClearStatus.cleared;
              onClearStatusChanged!(next);
            },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: kMinInteractiveDimension,
        minHeight: kMinInteractiveDimension,
      ),
    );
  }
}
