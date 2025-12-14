import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';

final tbbProvider = FutureProvider.autoDispose.family<double, DateTime>((
  ref,
  month,
) {
  final budgetingService = ref.watch(budgetingServiceProvider);
  return budgetingService.calculateTBB(month);
});

class ToBeBudgetedWidget extends ConsumerWidget {
  const ToBeBudgetedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final tbbAsync = ref.watch(tbbProvider(currentMonth));
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(settingsProvider).currency;
    final theme = Theme.of(context);

    return tbbAsync.when(
      data: (tbb) {
        final currencyFormat = NumberFormat.simpleCurrency(name: currency);

        // Determine Gradient Colors
        List<Color> gradientColors;
        Color textColor = Colors.white;

        if (tbb > 0) {
          gradientColors = [
            AppColors.success,
            AppColors.success.withValues(alpha: 0.7),
          ];
        } else if (tbb < 0) {
          gradientColors = [
            AppColors.expense,
            AppColors.expense.withValues(alpha: 0.7),
          ];
        } else {
          // Zero/Neutral
          gradientColors = [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ];
          textColor = theme.colorScheme.onSurface;
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                l10n.toBeBudgeted.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                currencyFormat.format(tbb),
                style: theme.textTheme.displaySmall?.copyWith(
                  // Large amount text
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          'Error loading budget',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
