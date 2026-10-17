import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class ToBeBudgetedBanner extends ConsumerWidget {
  const ToBeBudgetedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbbAsync = ref.watch(
      tbbProvider(ref.watch(selectedBudgetMonthProvider)),
    );
    final fmt = ref.watch(appFormatterProvider);
    final scheme = Theme.of(context).colorScheme;

    final tbbValue = tbbAsync.valueOrNull ?? 0;
    final isNegative = tbbValue < 0;
    final accentColor = isNegative ? scheme.error : Colors.green.shade700;
    final cardBgColor = Color.alphaBlend(
      accentColor.withValues(alpha: 0.06),
      scheme.surfaceContainerLow,
    );

    return Card(
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!.toBeBudgeted,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      tbbAsync.when(
                        data: (tbb) {
                          final formatted = fmt.formatMoney(tbb);
                          final textWidget = AmountText(
                            tbb,
                            amountContext: AmountContext.toBeBudgeted,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: tbb >= 0
                                      ? Colors.green.shade700
                                      : scheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                          );

                          if (tbb <= 0) {
                            return textWidget;
                          }

                          return LongPressDraggable<int>(
                            data: tbb,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                  border: Border.all(
                                    color: Colors.green.shade700.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  formatted,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: textWidget,
                            ),
                            child: textWidget,
                          );
                        },
                        loading: () => const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (err, stack) => LoadErrorView(
                          error: err,
                          stackTrace: stack,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const InfoButton(HelpTopic.toBeBudgeted),
              ],
            ),
            Divider(height: 16, color: accentColor.withValues(alpha: 0.2)),
            const _IncomeLine(),
          ],
        ),
      ),
    );
  }
}

/// The month's income under To Be Budgeted: what arrived and what recurring
/// income is still expected (opens Income & Salaries); while no salary is
/// set up, it invites to add one and opens the form.
class _IncomeLine extends ConsumerWidget {
  const _IncomeLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final income = ref.watch(monthIncomeProvider(month)).valueOrNull;
    if (income == null) {
      return const SizedBox(height: kMinInteractiveDimension);
    }
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final parts = [
      if (income.received > 0)
        l10n.budgetIncomeReceived(fmt.formatMoney(income.received)),
      if (income.expected > 0)
        l10n.budgetIncomeExpected(
          fmt.formatMoney(income.expected),
          fmt.formatMonthDay(income.nextExpectedDate!),
        ),
    ];
    final summary = l10n.labelValue(
      l10n.budgetIncomeLabel,
      parts.isEmpty ? l10n.budgetIncomeNone : parts.join(' · '),
    );

    final addsSalary = !income.hasRecurringIncome;
    return InkWell(
      key: const Key('budget.incomeLine'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: addsSalary
          ? () => showAddIncomeSheet(context)
          : () => context.push('/settings/income'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!addsSalary || income.received > 0)
                    Text(summary, style: textStyle),
                  if (addsSalary)
                    Text(
                      l10n.budgetIncomeAddPrompt,
                      style: textStyle?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              addsSalary ? Icons.add_circle_outline : Icons.chevron_right,
              size: 20,
              color: addsSalary ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
