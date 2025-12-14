import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final VoidCallback? onTap;

  const AccountCard({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If account has currency, use it. Otherwise use system setting?
    // User request implies system setting wins or isn't being used.
    // If account.currency matches system setting (or is default), we want to use the formatted defined by system?
    // Actually, account.currency probably IS the code (e.g. 'USD').
    // If user changes setting to 'EUR', but account is 'USD'.
    // AccountCard currently uses `account.currency`.
    // Valid behavior for Account Card is to show the account's actual currency style.
    // BUT if the user's issue is "I chose Euro and app still shows Dollar", maybe they expect EVERYTHING to change?
    // If they have only one account, created with default USD, and they change settings to EUR, they expect the account to show EUR?
    // To be safe and solve the user's problem, I will prioritize the settings currency overriding the account currency display
    // OR, I should check if I should update the account currency itself? No, that's a data change.
    // I will use settings.currency for display.
    final currency = ref.watch(settingsProvider).currency;
    final currencyFormatter = NumberFormat.simpleCurrency(name: currency);
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
