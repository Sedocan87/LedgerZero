import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;

  const AccountCard({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(
      name: account.currency,
    );
    final theme = Theme.of(context);

    // Determine icon based on account type
    IconData icon;
    switch (account.type) {
      case AccountType.checking:
        icon = Icons.account_balance;
        break;
      case AccountType.savings:
        icon = Icons.savings;
        break;
      case AccountType.credit:
        icon = Icons.credit_card;
        break;
      case AccountType.cash:
        icon = Icons.money;
        break;
    }

    // Determine color for balance (red for negative, default for positive)
    final balanceColor = account.currentBalance < 0
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: theme.textTheme.titleMedium),
                Text(
                  account.type.name.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(account.currentBalance),
            style: theme.textTheme.titleMedium?.copyWith(
              color: balanceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
