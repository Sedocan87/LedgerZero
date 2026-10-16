import 'package:flutter/material.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;

  const AccountCard({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Icon and name of the account type
    final (IconData icon, String? typeName) = switch (account.type) {
      AccountType.checking => (
        Icons.account_balance,
        l10n?.accountTypeChecking,
      ),
      AccountType.savings => (Icons.savings, l10n?.accountTypeSavings),
      AccountType.credit => (Icons.credit_card, l10n?.accountTypeCredit),
      AccountType.cash => (Icons.money, l10n?.accountTypeCash),
    };

    // Determine color for balance (red for negative, default for positive)
    final balanceColor = account.balance < 0
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
                  (typeName ?? account.type.name).toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Amounts are shown in the account's own currency.
          AmountText(
            account.balance,
            currencyCode: account.currency,
            amountContext: AmountContext.balance,
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
