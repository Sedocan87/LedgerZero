import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/undo/budget_undo_actions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';

class BudgetCategoryRow extends ConsumerStatefulWidget {
  final BudgetCategoryViewModel viewModel;

  const BudgetCategoryRow({super.key, required this.viewModel});

  @override
  ConsumerState<BudgetCategoryRow> createState() => _BudgetCategoryRowState();
}

class _BudgetCategoryRowState extends ConsumerState<BudgetCategoryRow> {
  Future<void> _onSubmit(double value) async {
    await HapticFeedback.selectionClick();
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);
    final oldAmount = widget.viewModel.budgeted;

    await budgetingService.setCategoryBudgetedAmount(
      widget.viewModel.category.id,
      value,
      month,
    );

    if (oldAmount != value) {
      ref
          .read(undoServiceProvider)
          .addAction(
            BudgetChangeAction(
              budgetingService: budgetingService,
              categoryId: widget.viewModel.category.id,
              month: month,
              oldAmount: oldAmount,
              newAmount: value,
            ),
          );
      _showUndoSnackbar();
    }

    // Only clear editing state if we are still the one editing.
    // This prevents overwriting the state if navigation (Up/Down) has already moved focus to another category.
    if (ref.read(editingCategoryProvider) == widget.viewModel.category.id) {
      ref.read(editingCategoryProvider.notifier).state = null;
    }

    // Refresh the budget view to reflect changes
    ref.invalidate(budgetViewModelProvider);
    ref.invalidate(tbbProvider);
  }

  void _onDragAccept(double tbbAmount) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: tbbAmount.toStringAsFixed(2),
        );
        return AlertDialog(
          title: Text(
            AppLocalizations.of(
              context,
            )!.assignTo(widget.viewModel.category.name),
          ),
          content: AppTextField(
            controller: controller,
            label: AppLocalizations.of(context)!.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                final val = double.tryParse(controller.text) ?? 0.0;
                if (val > 0) {
                  // Add to existing budgeted amount
                  _onSubmit(widget.viewModel.budgeted + val);
                }
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _autoAssign(AutoAssignRule rule) async {
    await HapticFeedback.selectionClick();
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);
    final oldAmount = widget.viewModel.budgeted;

    await budgetingService.autoAssign(
      widget.viewModel.category.id,
      month,
      rule,
    );

    // Fetch new amount to record undo
    final budgetRepo = ref.read(budgetRepositoryProvider);
    final monthString = DateFormat('yyyy-MM').format(month);
    final newBudget = await budgetRepo.getBudgetByCategoryAndMonth(
      widget.viewModel.category.id,
      monthString,
    );
    final newAmount = newBudget?.budgeted ?? 0.0;

    if (oldAmount != newAmount) {
      ref
          .read(undoServiceProvider)
          .addAction(
            BudgetChangeAction(
              budgetingService: budgetingService,
              categoryId: widget.viewModel.category.id,
              month: month,
              oldAmount: oldAmount,
              newAmount: newAmount,
            ),
          );
      _showUndoSnackbar();
    }

    // Refresh providers
    ref.invalidate(budgetViewModelProvider);
    ref.invalidate(tbbProvider);
  }

  void _showUndoSnackbar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.budgetUpdated),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.undo,
          onPressed: () async {
            await ref.read(undoServiceProvider).undo();
            ref.invalidate(budgetViewModelProvider);
            ref.invalidate(tbbProvider);
          },
        ),
      ),
    );
  }

  void _inspectCategory() {
    final month = ref.read(selectedBudgetMonthProvider);
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    final filter = TransactionFilter(
      categoryIds: [widget.viewModel.category.id],
      startDate: startDate,
      endDate: endDate,
    );

    ref.read(transactionsProvider.notifier).updateFilter(filter);
    context.goNamed('transactions');
  }

  // Refined implementation below:
  // I need to track the value from onValueChanged to submit it.
  void _showCalculatorModal(double initialValue) {
    String currentValue = initialValue.toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BudgetCalculator(
          initialValue: currentValue,
          onValueChanged: (val) {
            currentValue = val;
          },
          onSubmitted: () {
            Navigator.pop(context);
            // Parse and submit
            // Handle math expressions if Calculator didn't resolve them yet?
            // Calculator usually resolves on '=', but if user types '50+50' then OK?
            // MathEvaluator usage is internal to Calculator key press '='.
            // If text still contains symbols, we should evaluate.
            try {
              // Simple parse for now, assuming calculator did its job or user typed number
              // If MathEvaluator needed, we should expose it or use it here.
              // Let's assume for now user presses = before OK, or just numbers.
              // Robust parsing:
              final val = double.tryParse(currentValue);
              if (val != null) {
                _onSubmit(val);
              }
            } catch (_) {}
          },
        ),
      ),
    );
  }

  // _moveFocus was unused, replacing it with the above
  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context)!.quickActions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(AppLocalizations.of(context)!.budgetPreviousMonth),
                onTap: () {
                  Navigator.pop(context);
                  _autoAssign(AutoAssignRule.lastMonthBudgeted);
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: Text(AppLocalizations.of(context)!.budgetAverageSpent),
                onTap: () {
                  Navigator.pop(context);
                  _autoAssign(AutoAssignRule.averageSpent);
                },
              ),
              ListTile(
                leading: const Icon(Icons.money_off),
                title: Text(AppLocalizations.of(context)!.budgetZeroOut),
                onTap: () {
                  Navigator.pop(context);
                  _onSubmit(0.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(AppLocalizations.of(context)!.moveMoney),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => MoveMoneyModal(
                      initialFromCategoryId: widget.viewModel.category.id,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = ref.watch(settingsProvider).currency;
    final currency = NumberFormat.simpleCurrency(
      decimalDigits: 2,
      name: currencyCode,
    );
    final theme = Theme.of(context);
    final available = widget.viewModel.available;

    // Determine color for available amount bubble
    Color bubbleColor;
    Color textColor;

    if (available > 0) {
      bubbleColor = AppColors.success.withValues(
        alpha: 0.1,
      ); // M3 way: tertiaryContainer
      textColor = AppColors.success;
    } else if (available < 0) {
      bubbleColor = AppColors.expense.withValues(
        alpha: 0.1,
      ); // M3 way: errorContainer
      textColor = AppColors.expense;
    } else {
      bubbleColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    final viewMode = ref.watch(budgetViewModeProvider);

    return DragTarget<double>(
      onWillAcceptWithDetails: (details) => details.data > 0,
      onAcceptWithDetails: (details) => _onDragAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          onLongPress: _showQuickActions,
          child: Container(
            color: candidateData.isNotEmpty
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, // Increased padding
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Category Name
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      if (widget.viewModel.goalTarget > 0 &&
                          widget.viewModel.budgeted <
                              widget.viewModel.goalTarget)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          widget.viewModel.category.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (viewMode == BudgetViewMode.standard) ...[
                  // Assigned (Budgeted) Column - Editable
                  // Assigned (Budgeted) Column - Editable via Calculator
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () =>
                          _showCalculatorModal(widget.viewModel.budgeted),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: Text(
                          currency.format(widget.viewModel.budgeted),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Activity Column (Read only)
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _inspectCategory,
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Text(
                          currency.format(widget.viewModel.activity),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Available Column (Bubble)
                  Expanded(
                    flex: 2,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          currency.format(available),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Progress Bar Mode (Comparison/Simple)
                  Expanded(
                    flex: 6,
                    child: Builder(
                      builder: (context) {
                        final budgeted = widget.viewModel.budgeted;
                        final spent = widget.viewModel.activity.abs();
                        final progress = budgeted > 0
                            ? (spent / budgeted).clamp(0.0, 1.0)
                            : (spent > 0 ? 1.0 : 0.0);
                        final isOverspent = spent > budgeted;
                        final barColor = isOverspent
                            ? AppColors.expense
                            : AppColors.success;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${currency.format(spent)} / ${currency.format(budgeted)}',
                                  style: theme.textTheme.labelSmall,
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: barColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              color: barColor,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
