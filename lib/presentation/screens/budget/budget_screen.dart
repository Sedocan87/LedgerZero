import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_tutorial_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.budget),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: AppLocalizations.of(context)!.manageCategories,
            onPressed: () => context.pushNamed('categories'),
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 8),
                MonthSelector(),
                ToBeBudgetedBanner(),
                BudgetTutorialBanner(),
              ],
            ),
          ),
          BudgetCategoryList(),
        ],
      ),
    );
  }
}
