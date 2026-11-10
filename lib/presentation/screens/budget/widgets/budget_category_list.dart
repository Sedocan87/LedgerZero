import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_columns.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

/// Remembers that the Savings & Investments transfer hint was dismissed.
const savingsTransferHintKey = 'hint_savings_transfer_seen';

class BudgetCategoryList extends ConsumerWidget {
  final Key? headerKey;

  const BudgetCategoryList({super.key, this.headerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetViewModelAsync = ref.watch(budgetViewModelProvider);
    final scheme = Theme.of(context).colorScheme;

    // After a ledger write the provider recomputes; keep showing the rows
    // (and their scroll position and focus) instead of a spinner.
    return budgetViewModelAsync.when(
      skipLoadingOnReload: true,
      data: (groups) {
        if (groups.isEmpty && ref.watch(budgetSearchQueryProvider).isNotEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(AppLocalizations.of(context)!.noMatchingCategories),
            ),
          );
        }
        if (groups.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.category_outlined,
              title: AppLocalizations.of(context)!.noCategoriesTitle,
              description: AppLocalizations.of(
                context,
              )!.noCategoriesDescription,
              actionLabel: AppLocalizations.of(context)!.setupBudget,
              onAction: () => context.pushNamed('categories'),
            ),
          );
        }

        // Calculate totals
        var totalBudgeted = 0;
        var totalActivity = 0;
        var totalAvailable = 0;

        for (final group in groups) {
          for (final cat in group.categories) {
            totalBudgeted += cat.budgeted;
            totalActivity += cat.activity;
            totalAvailable += cat.available;
          }
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Header
              if (index == 0) {
                return BudgetListHeader(key: headerKey);
              }

              // Footer
              if (index == groups.length + 1) {
                return BudgetSummaryFooter(
                  totalBudgeted: totalBudgeted,
                  totalActivity: totalActivity,
                  totalAvailable: totalAvailable,
                );
              }

              // Groups (index 1 to groups.length)
              final groupVM = groups[index - 1];
              final categoryWidgets = <Widget>[
                // Once money is budgeted for savings: how it gets there.
                if (groupVM.group.id == savingsGroupId &&
                    groupVM.categories.any((c) => c.budgeted > 0))
                  OneTimeHintCard(
                    prefsKey: savingsTransferHintKey,
                    text: AppLocalizations.of(context)!.hintSavingsTransfer,
                    topic: HelpTopic.saving,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  ),
              ];
              for (var i = 0; i < groupVM.categories.length; i++) {
                if (i > 0) {
                  // Inset under the name, like a list.
                  categoryWidgets.add(
                    Divider(
                      height: 1,
                      indent:
                          AppSpacing.md +
                          BudgetColumns.iconSize +
                          BudgetColumns.iconGap,
                      endIndent: AppSpacing.md,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  );
                }
                categoryWidgets.add(
                  // Keyed by category: without a key a row's State is
                  // matched by position, and a sheet opened from it would
                  // write to whichever category a sync moved there.
                  BudgetCategoryRow(
                    key: ValueKey(groupVM.categories[i].category.id),
                    viewModel: groupVM.categories[i],
                  ),
                );
              }
              final groupAvailable = groupVM.categories.fold<int>(
                0,
                (sum, c) => sum + c.available,
              );

              // A plain section: a hairline above every group but the
              // first, a header row and the rows; no card, no outline.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 1)
                    Divider(
                      height: 9,
                      thickness: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  FocusTraversalGroup(
                    child: ListTileTheme.merge(
                      minLeadingWidth: 24,
                      horizontalTitleGap: 6,
                      child: ExpansionTile(
                        key: PageStorageKey('group_${groupVM.group.id}'),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: BudgetGroupRow(
                          group: groupVM.group,
                          available: groupAvailable,
                          title: groupVM.isHiddenGroup
                              ? AppLocalizations.of(
                                  context,
                                )!.hiddenCategoriesGroup
                              : null,
                        ),
                        // Hidden categories with money stay reachable,
                        // folded.
                        initiallyExpanded: !groupVM.isHiddenGroup,
                        tilePadding: const EdgeInsets.only(
                          left: AppSpacing.sm,
                          right: AppSpacing.md,
                        ),
                        minTileHeight: 44,
                        visualDensity: VisualDensity.compact,
                        iconColor: scheme.onSurfaceVariant,
                        collapsedIconColor: scheme.onSurfaceVariant,
                        textColor: scheme.onSurface,
                        collapsedTextColor: scheme.onSurface,
                        childrenPadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: categoryWidgets,
                      ),
                    ),
                  ),
                ],
              );
            },
            childCount: groups.length + 2, // Header + Groups + Footer
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SliverFillRemaining(
        child: LoadErrorView(
          error: err,
          stackTrace: stack,
          onRetry: () => ref.invalidate(budgetViewModelProvider),
        ),
      ),
    );
  }
}

/// The column labels above the first group (Budgeted, Available; Activity
/// too on a tablet), right-aligned over the rows' amounts.
class BudgetListHeader extends ConsumerWidget {
  const BudgetListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    Widget label(String text, String tooltip, double width, double inset) =>
        Flexible(
          child: SizedBox(
            width: width,
            child: Tooltip(
              message: tooltip,
              child: Padding(
                padding: EdgeInsets.only(right: inset),
                child: Text(
                  text.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = BudgetColumns.of(context, fmt, constraints.maxWidth);
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              label(
                l10n.budgeted,
                l10n.budgetedTooltip,
                columns.budgeted,
                BudgetColumns.cellPadding,
              ),
              const SizedBox(width: BudgetColumns.gap),
              if (columns.activity case final width?) ...[
                label(
                  l10n.activity,
                  l10n.activityTooltip,
                  width,
                  BudgetColumns.cellPadding,
                ),
                const SizedBox(width: BudgetColumns.gap),
              ],
              label(
                l10n.available,
                l10n.availableTooltip,
                columns.available,
                BudgetColumns.pillPadding,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Totals row of the budget list, in the rows' columns. Amounts are minor
/// units.
class BudgetSummaryFooter extends ConsumerWidget {
  final int totalBudgeted;
  final int totalActivity;
  final int totalAvailable;

  const BudgetSummaryFooter({
    super.key,
    required this.totalBudgeted,
    required this.totalActivity,
    required this.totalAvailable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppSemanticColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    // [nameOnOwnLine]: the amounts are under the title and may shrink.
    Widget amount(
      BudgetColumns columns,
      int value,
      AmountContext amountContext,
      double width,
      double inset, {
      Color? color,
      TextStyle? style,
    }) {
      final cell = SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.only(right: inset),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: AmountText(
              value,
              amountContext: amountContext,
              maxLines: 1,
              style: (style ?? BudgetColumns.amountStyle(theme)).copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? scheme.onSurface,
              ),
            ),
          ),
        ),
      );
      return columns.nameOnOwnLine ? Flexible(child: cell) : cell;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 9,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = BudgetColumns.of(
                context,
                fmt,
                constraints.maxWidth,
              );
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.total,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // On a phone the month's activity is not a column.
                  if (columns.activity == null)
                    Text(
                      l10n.labelValue(
                        l10n.activity,
                        fmt.formatMoney(totalActivity),
                      ),
                      style: theme.textTheme.bodySmall?.tabular.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
              final amounts = [
                amount(
                  columns,
                  totalBudgeted,
                  AmountContext.budgeted,
                  columns.budgeted,
                  BudgetColumns.cellPadding,
                ),
                const SizedBox(width: BudgetColumns.gap),
                if (columns.activity case final width?) ...[
                  amount(
                    columns,
                    totalActivity,
                    AmountContext.activity,
                    width,
                    BudgetColumns.cellPadding,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: BudgetColumns.gap),
                ],
                amount(
                  columns,
                  totalAvailable,
                  AmountContext.available,
                  columns.available,
                  BudgetColumns.pillPadding,
                  style: BudgetColumns.pillStyle(theme),
                  color: totalAvailable < 0 ? colors.error : null,
                ),
              ];
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: columns.nameOnOwnLine
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          title,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: amounts,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: BudgetColumns.gap),
                          ...amounts,
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}
