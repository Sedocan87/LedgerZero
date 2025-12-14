import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final String? payeeName;
  final String? categoryName;
  final String? accountName;
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
    this.onTap,
    this.onLongPress,
    this.onClearStatusChanged,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Task 203: Color coding
    final isIncome = transaction.amount >= 0;
    // Using simple colors for now, can be improved with custom theme extensions
    final amountColor = isIncome
        ? Colors.green.shade700
        : theme.colorScheme.error;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      // ignore: deprecated_member_use
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.2),
      leading: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onTap?.call())
          : _buildClearedStatus(context),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              // Task 204: Payee
              payeeName ?? 'No Payee',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!transaction.approved) ...[
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            // Task 203: Amount
            NumberFormat.simpleCurrency().format(transaction.amount),
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
                  // Task 204: Category
                  categoryName ?? 'Uncategorized',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // Task 204: Date
                DateFormat.yMMMd().format(transaction.date),
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
                // ignore: deprecated_member_use
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Task 205: Cleared status indicator
  Widget _buildClearedStatus(BuildContext context) {
    IconData icon;
    Color color;

    switch (transaction.cleared) {
      case TransactionClearStatus.reconciled:
        icon = Icons.lock;
        color = Colors.green;
        break;
      case TransactionClearStatus.cleared:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TransactionClearStatus.uncleared:
        icon = Icons.check_circle_outline;
        color = Colors.grey;
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: () {
        if (onClearStatusChanged != null) {
          final next = transaction.cleared == TransactionClearStatus.cleared
              ? TransactionClearStatus.uncleared
              : TransactionClearStatus.cleared;
          onClearStatusChanged!(next);
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
