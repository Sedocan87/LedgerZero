import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/presentation/widgets/common/pro_gate.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_currency_warning.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_month_actions.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_template_dialogs.dart';
import 'package:ledger_zero/presentation/widgets/common/settings_action.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_tutorial_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/leftover_card.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/new_month_card.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/salary_prompt.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/savings_categories_offer.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_tutorial_manager.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with WidgetsBindingObserver {
  bool _isSearching = false;
  late TextEditingController _searchController;
  final _tutorialKeys = BudgetTutorialKeys();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
  }

  bool _tutorialStarted = false;

  /// Starts the tutorial once the category list has data: its last step
  /// points at the list, which does not exist while the list is loading.
  void _startTutorialWhenLoaded(AsyncValue<Object?> list) {
    if (_tutorialStarted || !list.hasValue) {
      return;
    }
    _tutorialStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BudgetTutorialManager.showTutorial(context, ref, _tutorialKeys);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A new day (or month) may have started while in the background.
      ref.read(todayProvider.notifier).refresh();
    }
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
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.read(appFormatterProvider);
    final month = ref.read(selectedBudgetMonthProvider);
    final previous = DateTime.utc(month.year, month.month - 1, 1);
    final ok = await confirmMonthOverwrite(
      context,
      ref,
      month: month,
      message: l10n.budgetCopyConfirmation(
        fmt.formatMonthYear(month),
        fmt.formatMonthName(previous),
      ),
    );
    if (!ok || !mounted) {
      return;
    }
    await runMonthAction(
      context,
      ref,
      run: () =>
          ref.read(budgetingServiceProvider).copyBudgetFromPreviousMonth(month),
      message: l10n.budgetCopiedFrom(fmt.formatMonthName(previous)),
    );
  }

  Future<void> _resetBudget() async {
    final l10n = AppLocalizations.of(context)!;
    final month = ref.read(selectedBudgetMonthProvider);
    final monthString = ref.read(appFormatterProvider).formatMonthYear(month);

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

    if (confirm == true && mounted) {
      await runMonthAction(
        context,
        ref,
        run: () => ref.read(budgetingServiceProvider).resetBudget(month),
        message: l10n.budgetResetDone,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    ref.listen(budgetViewModelProvider, (_, next) {
      _startTutorialWhenLoaded(next);
    });
    _startTutorialWhenLoaded(ref.read(budgetViewModelProvider));

    // Back leaves the search first (and clears the filter); only a second
    // back leaves the screen.
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: _buildScaffold(context, l10n, theme),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
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
            // The month is the title: chevrons step a month, the name
            // opens the month picker.
            : MonthSelector(key: _tutorialKeys.monthSelector),
        centerTitle: false,
        titleSpacing: _isSearching ? null : 4,
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: _toggleSearch,
            ),
            // View mode, categories, templates and the month operations.
            PopupMenuButton<String>(
              key: const Key('budget.menu'),
              onSelected: (value) async {
                if (value == 'view_mode') {
                  final current = ref.read(budgetViewModeProvider);
                  ref
                      .read(budgetViewModeProvider.notifier)
                      .state = current == BudgetViewMode.standard
                      ? BudgetViewMode.comparison
                      : BudgetViewMode.standard;
                } else if (value == 'categories') {
                  await context.pushNamed('categories');
                } else if (value == 'save_template') {
                  await showSaveTemplateDialog(context, ref);
                } else if (value == 'apply_template') {
                  await showApplyTemplateDialog(context, ref);
                } else if (value == 'copy_previous') {
                  await _copyPreviousMonth();
                } else if (value == 'auto_fill') {
                  await showAutoFillSettingsDialog(context, ref);
                } else if (value == 'reset') {
                  await _resetBudget();
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'view_mode',
                  checked:
                      ref.read(budgetViewModeProvider) ==
                      BudgetViewMode.comparison,
                  child: Text(l10n.budgetViewProgress),
                ),
                PopupMenuItem(
                  value: 'categories',
                  child: Text(l10n.manageCategories),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'save_template',
                  child: _ProMenuLabel(l10n.saveAsTemplate),
                ),
                PopupMenuItem(
                  value: 'apply_template',
                  child: _ProMenuLabel(l10n.applyTemplate),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'copy_previous',
                  child: Text(l10n.copyFromPreviousMonth),
                ),
                PopupMenuItem(
                  value: 'auto_fill',
                  child: _ProMenuLabel(l10n.autoFillMenu),
                ),
                PopupMenuItem(value: 'reset', child: Text(l10n.resetBudget)),
              ],
            ),
            const SettingsAction(),
          ] else
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.close,
              onPressed: _toggleSearch,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
                  child: ToBeBudgetedBanner(key: _tutorialKeys.tbb),
                ),
              ),
              const SliverToBoxAdapter(child: _NoAccountsPrompt()),
              const SliverToBoxAdapter(child: BudgetCurrencyWarning()),
              const SliverToBoxAdapter(child: BudgetTutorialBanner()),
              const SliverToBoxAdapter(child: SalaryPrompt()),
              const SliverToBoxAdapter(child: LeftoverCard()),
              const SliverToBoxAdapter(child: AutoFillNoteCard()),
              const SliverToBoxAdapter(child: NewMonthCard()),
              const SliverToBoxAdapter(child: SavingsCategoriesOffer()),
              BudgetCategoryList(headerKey: _tutorialKeys.categoryList),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while no account exists: budgeting starts with an account's
/// balance, so point the user there.
class _NoAccountsPrompt extends ConsumerWidget {
  const _NoAccountsPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccounts = ref
        .watch(accountsProvider)
        .whenData((accounts) => accounts.isNotEmpty)
        .valueOrNull;
    if (hasAccounts != false) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        key: const Key('budget.noAccounts'),
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.budgetNoAccountsMessage,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/accounts/add?first=1'),
                icon: const Icon(Icons.add),
                label: Text(l10n.createAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A budget menu entry of a Pro feature (templates, automatic fill), with
/// the PRO badge while Pro is locked.
class _ProMenuLabel extends StatelessWidget {
  const _ProMenuLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(text)),
      const SizedBox(width: 8),
      const ProBadge(feature: ProFeature.budgetTemplates),
    ],
  );
}
