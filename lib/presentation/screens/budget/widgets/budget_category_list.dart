import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class BudgetCategoryList extends ConsumerWidget {
  const BudgetCategoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetViewModelAsync = ref.watch(budgetViewModelProvider);

    return budgetViewModelAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'No categories. Go to Settings to add some.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                return const BudgetListHeader();
              }
              final groupVM = groups[index - 1];
              return ExpansionTile(
                key: PageStorageKey('group_${groupVM.group.id}'),
                title: BudgetGroupRow(group: groupVM.group),
                initiallyExpanded: true,
                shape: const Border(), // Remove borders
                children: groupVM.categories.map((catVM) {
                  return BudgetCategoryRow(viewModel: catVM);
                }).toList(),
              );
            },
            childCount: groups.length + 1,
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SliverFillRemaining(
        child: Center(child: Text('Error: $err')),
      ),
    );
  }
}

class BudgetListHeader extends StatelessWidget {
  const BudgetListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(AppLocalizations.of(context)!.category.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
          Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.budgeted.toUpperCase(), textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
          Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.activity.toUpperCase(), textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
          Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.available.toUpperCase(), textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
          const SizedBox(width: 48), // Approximate width of ExpansionTile trailing icon
        ],
      ),
    );
  }
}
