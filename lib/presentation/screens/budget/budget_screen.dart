import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_tutorial_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  bool _isSearching = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
    if (!_isSearching) {
      _searchController.clear();
      ref.read(budgetSearchQueryProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.search,
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                onChanged: (value) {
                  ref.read(budgetSearchQueryProvider.notifier).state = value;
                },
              )
            : Text(AppLocalizations.of(context)!.budget),
        centerTitle: true,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              )
            : null,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: AppLocalizations.of(context)!.search,
              onPressed: _toggleSearch,
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.category),
              tooltip: AppLocalizations.of(context)!.manageCategories,
              onPressed: () => context.pushNamed('categories'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const CustomScrollView(
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
        ),
      ),
    );
  }
}
