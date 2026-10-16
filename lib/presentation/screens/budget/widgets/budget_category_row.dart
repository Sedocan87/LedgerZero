import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/undo/budget_undo_actions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
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
  Future<void> _onSubmit(int value) async {
    await HapticFeedback.selectionClick();
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);
    final oldAmount = widget.viewModel.budgeted;

    await budgetingService.setCategoryBudgetedAmount(
      widget.viewModel.category.id,
      value,
      month,
    );
    if (!mounted) {
      return;
    }

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
  }

  Future<void> _onDragAccept(int tbbAmount) async {
    final val = await showDialog<int>(
      context: context,
      builder: (context) => _AssignAmountDialog(
        categoryName: widget.viewModel.category.name,
        initialAmount: tbbAmount,
      ),
    );
    if (mounted && val != null && val > 0) {
      // Add to existing budgeted amount
      await _onSubmit(widget.viewModel.budgeted + val);
    }
  }

  Future<void> _autoAssign(AutoAssignRule rule) async {
    await HapticFeedback.selectionClick();
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);
    final oldAmount = widget.viewModel.budgeted;

    final budgetRepo = ref.read(budgetRepositoryProvider);
    await budgetingService.autoAssign(
      widget.viewModel.category.id,
      month,
      rule,
    );

    // Fetch new amount to record undo
    final monthString = CalendarDate.monthKey(month);
    final newBudget = await budgetRepo.getBudgetByCategoryAndMonth(
      widget.viewModel.category.id,
      monthString,
    );
    final newAmount = newBudget?.budgeted ?? 0;
    if (!mounted) {
      return;
    }

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
  }

  void _showUndoSnackbar() {
    // The snack bar can outlive this row; keep the service, not the ref.
    final undoService = ref.read(undoServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.budgetUpdated),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.undo,
          onPressed: () async {
            await undoService.undo();
          },
        ),
      ),
    );
  }

  /// Opens the category's activity for the selected month in its own,
  /// non-persisted list (the Transactions tab keeps its filter).
  void _inspectCategory() {
    final month = ref.read(selectedBudgetMonthProvider);
    final fmt = ref.read(appFormatterProvider);
    // TransactionFilter dates are inclusive calendar days.
    final filter = TransactionFilter(
      categoryIds: [widget.viewModel.category.id],
      startDate: CalendarDate.startOfMonthUtc(month),
      endDate: DateTime.utc(month.year, month.month + 1, 0),
    );
    context.pushNamed(
      'filtered-transactions',
      extra: FilteredTransactionsArgs(
        filter: filter,
        title: AppLocalizations.of(context)!.txCategoryActivityTitle(
          widget.viewModel.category.name,
          fmt.formatMonthYear(month),
        ),
      ),
    );
  }

  void _showCalculatorModal(int initialValue) {
    final fmt = ref.read(appFormatterProvider);
    String currentValue = fmt.formatAmountForInput(initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Above the tab scaffold, so its snackbars (e.g. "Transaction saved")
      // never cover the calculator keys.
      useRootNavigator: true,
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
            // Accepts a plain amount or an unevaluated expression.
            final val = parseBudgetInput(currentValue, fmt);
            if (val != null) {
              _onSubmit(val);
            }
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
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(AppLocalizations.of(context)!.budgetLastMonthSpent),
                onTap: () {
                  Navigator.pop(context);
                  _autoAssign(AutoAssignRule.lastMonthSpent);
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
                  _onSubmit(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(AppLocalizations.of(context)!.moveMoney),
                onTap: () {
                  Navigator.pop(context);
                  // The sheet's context is gone once popped; use the row's.
                  showModalBottomSheet(
                    context: this.context,
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
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final available = widget.viewModel.available;

    // Determine color for available amount bubble (on the exact int sign,
    // so a zero balance is neutral and never shown as "-0.00").
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

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data > 0,
      onAcceptWithDetails: (details) => _onDragAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          onLongPress: _showQuickActions,
          child: Container(
            color: candidateData.isNotEmpty
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            // The amount cells are at least kMinInteractiveDimension tall;
            // the vertical padding is reduced so the row keeps its height.
            padding: EdgeInsets.symmetric(
              vertical: viewMode == BudgetViewMode.standard
                  ? AppSpacing.md - 6
                  : AppSpacing.md,
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
                            semanticLabel: l10n?.budgetGoalUnderfunded,
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
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: AmountText(
                          widget.viewModel.budgeted,
                          amountContext: AmountContext.budgeted,
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
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: AmountText(
                          widget.viewModel.activity,
                          amountContext: AmountContext.activity,
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
                        child: AmountText(
                          available,
                          amountContext: AmountContext.available,
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
                        // Ratio for the progress bar only.
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
                                Semantics(
                                  label: l10n?.amountSemanticsSpentOfBudgeted(
                                    fmt.formatMoney(spent),
                                    fmt.formatMoney(budgeted),
                                  ),
                                  excludeSemantics: l10n != null,
                                  child: Text(
                                    '${fmt.formatMoney(spent)} / ${fmt.formatMoney(budgeted)}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                                Text(
                                  NumberFormat.percentPattern(
                                    fmt.locale,
                                  ).format(progress),
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

/// Asks how much of the dragged To Be Budgeted amount to assign; pops with
/// the amount in minor units, or `null` when cancelled.
class _AssignAmountDialog extends ConsumerStatefulWidget {
  final String categoryName;
  final int initialAmount;

  const _AssignAmountDialog({
    required this.categoryName,
    required this.initialAmount,
  });

  @override
  ConsumerState<_AssignAmountDialog> createState() =>
      _AssignAmountDialogState();
}

class _AssignAmountDialogState extends ConsumerState<_AssignAmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: ref
        .read(appFormatterProvider)
        .formatAmountForInput(widget.initialAmount),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.assignTo(widget.categoryName)),
      content: AppTextField(
        controller: _controller,
        label: l10n.amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            ref.read(appFormatterProvider).parseAmount(_controller.text) ?? 0,
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
