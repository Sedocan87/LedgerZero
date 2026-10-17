import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class BudgetCategoryList extends ConsumerWidget {
  final Key? headerKey;

  const BudgetCategoryList({super.key, this.headerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetViewModelAsync = ref.watch(budgetViewModelProvider);
    final scheme = Theme.of(context).colorScheme;

    return budgetViewModelAsync.when(
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
              final categoryWidgets = <Widget>[];
              for (var i = 0; i < groupVM.categories.length; i++) {
                if (i == 0) {
                  categoryWidgets.add(
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  );
                } else {
                  categoryWidgets.add(
                    Divider(
                      height: 1,
                      indent: 52,
                      endIndent: 16,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  );
                }
                categoryWidgets.add(
                  BudgetCategoryRow(viewModel: groupVM.categories[i]),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: FocusTraversalGroup(
                    child: ExpansionTile(
                      key: PageStorageKey('group_${groupVM.group.id}'),
                      title: BudgetGroupRow(group: groupVM.group),
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 2.0,
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 4.0),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      children: categoryWidgets,
                    ),
                  ),
                ),
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

class BudgetListHeader extends StatelessWidget {
  const BudgetListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32.0, 6.0, 32.0, 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Tooltip(
              message: AppLocalizations.of(context)!.categoryTooltip,
              child: Text(
                AppLocalizations.of(context)!.category.toUpperCase(),
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: AppLocalizations.of(context)!.budgetedTooltip,
              child: Text(
                AppLocalizations.of(context)!.budgeted.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: AppLocalizations.of(context)!.activityTooltip,
              child: Text(
                AppLocalizations.of(context)!.activity.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: AppLocalizations.of(context)!.availableTooltip,
              child: Text(
                AppLocalizations.of(context)!.available.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Totals row of the budget list. Amounts are minor units.
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Card(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(
                      Icons.functions_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.total.toUpperCase(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    fmt.formatMoney(totalBudgeted),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    fmt.formatMoney(totalActivity),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    fmt.formatMoney(totalAvailable),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: totalAvailable < 0
                          ? scheme.error
                          : scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
