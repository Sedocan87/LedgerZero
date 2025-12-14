import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class BudgetCategoryList extends ConsumerWidget {
  final Key? headerKey;

  const BudgetCategoryList({super.key, this.headerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetViewModelAsync = ref.watch(budgetViewModelProvider);
    final currency = ref.watch(settingsProvider).currency;

    return budgetViewModelAsync.when(
      data: (groups) {
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
        double totalBudgeted = 0;
        double totalActivity = 0;
        double totalAvailable = 0;

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
                  currencyCode: currency,
                );
              }

              // Groups (index 1 to groups.length)
              final groupVM = groups[index - 1];
              return FocusTraversalGroup(
                child: ExpansionTile(
                  key: PageStorageKey('group_${groupVM.group.id}'),
                  title: BudgetGroupRow(group: groupVM.group),
                  initiallyExpanded: true,
                  shape: const Border(), // Remove borders
                  children: groupVM.categories.map((catVM) {
                    return BudgetCategoryRow(viewModel: catVM);
                  }).toList(),
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
      error: (err, stack) =>
          SliverFillRemaining(child: Center(child: Text('Error: $err'))),
    );
  }
}

class BudgetListHeader extends StatelessWidget {
  const BudgetListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Tooltip(
              message: AppLocalizations.of(context)!.categoryTooltip,
              child: Text(
                AppLocalizations.of(context)!.category.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
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
                style: Theme.of(context).textTheme.labelSmall,
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
                style: Theme.of(context).textTheme.labelSmall,
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
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          const SizedBox(
            width: 48,
          ), // Approximate width of ExpansionTile trailing icon to align with content
        ],
      ),
    );
  }
}

class BudgetSummaryFooter extends StatelessWidget {
  final double totalBudgeted;
  final double totalActivity;
  final double totalAvailable;
  final String currencyCode;

  const BudgetSummaryFooter({
    super.key,
    required this.totalBudgeted,
    required this.totalActivity,
    required this.totalAvailable,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(
      decimalDigits: 2,
      name: currencyCode,
    );

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              AppLocalizations.of(context)!.total.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(totalBudgeted),
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(totalActivity),
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(totalAvailable),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: totalAvailable < 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          const SizedBox(
            width: 48,
          ), // Approximate width of ExpansionTile trailing icon
        ],
      ),
    );
  }
}
