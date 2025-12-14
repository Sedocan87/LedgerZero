import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_template_dialogs.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_tutorial_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_tutorial_manager.dart';

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

    // Trigger tutorial after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BudgetTutorialManager.showTutorial(context, ref);
    });
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

  Future<void> _copyPreviousMonth() async {
    final month = ref.read(selectedBudgetMonthProvider);
    await ref.read(budgetingServiceProvider).copyBudgetFromPreviousMonth(month);
    ref.invalidate(budgetViewModelProvider);
    ref.invalidate(tbbProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.budgetUpdated)),
      );
    }
  }

  Future<void> _resetBudget() async {
    final month = ref.read(selectedBudgetMonthProvider);
    final dateFormat = intl.DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    );
    final monthString = dateFormat.format(month);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetBudget),
        content: Text(
          AppLocalizations.of(context)!.resetBudgetConfirmation(monthString),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.reset),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(budgetingServiceProvider).resetBudget(month);
      ref.invalidate(budgetViewModelProvider);
      ref.invalidate(tbbProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.budgetUpdated)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (value) {
                  ref.read(budgetSearchQueryProvider.notifier).state = value;
                },
              )
            : Text(l10n.budget),
        centerTitle: false,
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: Consumer(
                builder: (context, ref, child) {
                  final mode = ref.watch(budgetViewModeProvider);
                  return Icon(
                    mode == BudgetViewMode.standard
                        ? Icons.bar_chart
                        : Icons.list,
                  );
                },
              ),
              tooltip: l10n.viewMode,
              onPressed: () {
                final current = ref.read(budgetViewModeProvider);
                ref
                    .read(budgetViewModeProvider.notifier)
                    .state = current == BudgetViewMode.standard
                    ? BudgetViewMode.comparison
                    : BudgetViewMode.standard;
              },
            ),
            IconButton(
              icon: const Icon(Icons.category_outlined),
              tooltip: l10n.manageCategories,
              onPressed: () => context.pushNamed('categories'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'save_template') {
                  await showSaveTemplateDialog(context, ref);
                } else if (value == 'apply_template') {
                  await showApplyTemplateDialog(context, ref);
                } else if (value == 'copy_previous') {
                  await _copyPreviousMonth();
                } else if (value == 'reset') {
                  await _resetBudget();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save_template',
                  child: Text(l10n.saveAsTemplate),
                ),
                PopupMenuItem(
                  value: 'apply_template',
                  child: Text(l10n.applyTemplate),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'copy_previous',
                  child: Text(l10n.copyFromPreviousMonth),
                ),
                PopupMenuItem(value: 'reset', child: Text(l10n.resetBudget)),
              ],
            ),
          ] else
            IconButton(icon: const Icon(Icons.close), onPressed: _toggleSearch),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: MonthSelector(key: monthSelectorKey),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ToBeBudgetedBanner(key: tbbKey),
                ),
              ),
              const SliverToBoxAdapter(child: BudgetTutorialBanner()),
              BudgetCategoryList(headerKey: categoryListKey),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
