import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;

  /// Amount in minor units.
  final int amount;
  final Color? amountColor;
  final IconData icon;
  final Color iconColor;

  /// Currency of [amount]; defaults to the Settings currency.
  final String? currencyCode;

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.amount,
    this.amountColor,
    required this.icon,
    required this.iconColor,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        // Read as one item: "<title>, <amount>".
        child: MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    amount,
                    currencyCode: currencyCode,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: amountColor ?? theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
