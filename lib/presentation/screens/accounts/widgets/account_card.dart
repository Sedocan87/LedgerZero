import 'package:flutter/material.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Icon, accent color, and localized name of the account type
    final (
      IconData icon,
      Color accentColor,
      String? typeName,
    ) = switch (account.type) {
      AccountType.checking => (
        Icons.account_balance_rounded,
        scheme.primary,
        l10n?.accountTypeChecking,
      ),
      AccountType.savings => (
        Icons.savings_rounded,
        isDark ? Colors.teal.shade300 : const Color(0xFF00796B),
        l10n?.accountTypeSavings,
      ),
      AccountType.credit => (
        Icons.credit_card_rounded,
        isDark ? Colors.amber.shade300 : const Color(0xFFE65100),
        l10n?.accountTypeCredit,
      ),
      AccountType.cash => (
        Icons.payments_rounded,
        isDark ? Colors.green.shade300 : AppColors.income,
        l10n?.accountTypeCash,
      ),
    };

    // Determine color for balance (red for negative, default for positive)
    final balanceColor = account.balance < 0
        ? (isDark ? Colors.red.shade300 : AppColors.expense)
        : scheme.onSurface;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Badge((typeName ?? account.type.name).toUpperCase()),
                    if (!account.onBudget && l10n != null)
                      _Badge(l10n.accountOffBudgetBadge.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amounts are shown in the account's own currency.
          Flexible(
            child: AmountText(
              account.balance,
              currencyCode: account.currency,
              amountContext: AmountContext.balance,
              style: theme.textTheme.titleMedium?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

/// A small pill label under the account name.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
