import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color? amountColor;
  final IconData icon;
  final Color iconColor;
  final String currencyCode;

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.amount,
    this.amountColor,
    required this.icon,
    required this.iconColor,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(name: currencyCode);
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        // Theme handles shape/color
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                currencyFormat.format(amount),
                style: theme.textTheme.headlineSmall?.copyWith(
                  // M3 Style
                  color: amountColor ?? theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
