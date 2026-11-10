import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/providers/review_provider.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

/// To Be Budgeted of the selected month: a tonal block with the label, the
/// amount (long-press and drag it onto a category to assign it), a status
/// chip and the month's income line.
class ToBeBudgetedBanner extends ConsumerWidget {
  const ToBeBudgetedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final tbbAsync = ref.watch(tbbProvider(month));
    // The user has just given every euro a place: a good moment to ask for
    // a rating (rarely, and only after real use; see ReviewPrompter).
    ref.listen<AsyncValue<int>>(tbbProvider(month), (previous, next) {
      final before = previous?.valueOrNull;
      if (before != null && before > 0 && next.valueOrNull == 0) {
        unawaited(ref.read(reviewPrompterProvider).goodMoment());
      }
    });
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppSemanticColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 4.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.toBeBudgeted,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    tbbAsync.when(
                      skipLoadingOnReload: true,
                      data: (tbb) {
                        final color = tbbAmountColor(context, tbb);
                        final textWidget = FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AmountText(
                            tbb,
                            amountContext: AmountContext.toBeBudgeted,
                            maxLines: 1,
                            style: theme.textTheme.headlineMedium?.tabular
                                .copyWith(color: color),
                          ),
                        );
                        final amountRow = Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (tbb <= 0)
                              textWidget
                            else
                              LongPressDraggable<int>(
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
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      fmt.formatMoney(tbb),
                                      style: theme.textTheme.titleLarge?.tabular
                                          .copyWith(color: colors.success),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.5,
                                  child: textWidget,
                                ),
                                child: textWidget,
                              ),
                            TbbStatusChip(tbb: tbb),
                          ],
                        );
                        return amountRow;
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
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: _IncomeLine(),
          ),
        ],
      ),
    );
  }
}

/// The colour of a To Be Budgeted amount: success when there is money to
/// assign, error when more was assigned than there is, else the text colour.
Color tbbAmountColor(BuildContext context, int tbb) {
  final colors = AppSemanticColors.of(context);
  if (tbb > 0) {
    return colors.success;
  }
  if (tbb < 0) {
    return colors.error;
  }
  return Theme.of(context).colorScheme.onSurface;
}

/// "Ready to assign" (success), "Overassigned" (error) or "All assigned"
/// (neutral) next to a To Be Budgeted amount, so its state is not told by
/// colour alone.
class TbbStatusChip extends StatelessWidget {
  const TbbStatusChip({super.key, required this.tbb});

  /// To Be Budgeted (minor units); only its sign matters.
  final int tbb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppSemanticColors.of(context);
    final (label, textColor, fill) = switch (tbb.sign) {
      1 => (
        l10n.tbbStatusReady,
        colors.success,
        AppSemanticColors.tonal(colors.success, scheme.surfaceContainerLow),
      ),
      -1 => (
        l10n.tbbStatusOverassigned,
        colors.error,
        AppSemanticColors.tonal(colors.error, scheme.surfaceContainerLow),
      ),
      _ => (
        l10n.tbbStatusAllAssigned,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
    };
    return Container(
      key: const Key('tbb.status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
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
