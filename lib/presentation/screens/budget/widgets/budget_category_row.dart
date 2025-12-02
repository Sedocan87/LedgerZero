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
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_input_field.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';
import 'package:ledger_zero/presentation/widgets/common/animated_count_text.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

class BudgetCategoryRow extends ConsumerStatefulWidget {
  final BudgetCategoryViewModel viewModel;

  const BudgetCategoryRow({super.key, required this.viewModel});

  @override
  ConsumerState<BudgetCategoryRow> createState() => _BudgetCategoryRowState();
}

class _BudgetCategoryRowState extends ConsumerState<BudgetCategoryRow> {
  Future<void> _onSubmit(double value) async {
    HapticFeedback.selectionClick();
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);
    final oldAmount = widget.viewModel.budgeted;

    await budgetingService.setCategoryBudgetedAmount(
      widget.viewModel.category.id,
      value,
      month,
    );

    if (oldAmount != value) {
      ref.read(undoServiceProvider).addAction(
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

  void _moveFocus(int direction) {
    ref.read(budgetOrderedCategoriesProvider.future).then((orderedCategories) {
      final currentIndex =
          orderedCategories.indexOf(widget.viewModel.category.id);
      if (currentIndex == -1) return;

      final newIndex = currentIndex + direction;
      if (newIndex >= 0 && newIndex < orderedCategories.length) {
        ref.read(editingCategoryProvider.notifier).state =
            orderedCategories[newIndex];
      }
    });
  }

  void _onDragAccept(double tbbAmount) {
    showDialog(
        context: context,
        builder: (context) {
          final controller =
              TextEditingController(text: tbbAmount.toStringAsFixed(2));
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!
                .assignTo(widget.viewModel.category.name)),
            content: AppTextField(
              controller: controller,
              label: AppLocalizations.of(context)!.amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel)),
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
        });
  }

  Future<void> _autoAssign(AutoAssignRule rule) async {
    HapticFeedback.selectionClick();
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
      ref.read(undoServiceProvider).addAction(
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
    final endDate = DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final filter = TransactionFilter(
      categoryIds: [widget.viewModel.category.id],
      startDate: startDate,
      endDate: endDate,
    );

    ref.read(transactionsProvider.notifier).updateFilter(filter);
    context.goNamed('transactions');
  }

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
    final currency = NumberFormat.simpleCurrency(decimalDigits: 2);
    final available = widget.viewModel.available;

    // Determine color for available amount bubble
    Color bubbleColor;
    Color textColor;

    if (available > 0) {
      bubbleColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      if (Theme.of(context).brightness == Brightness.dark) {
        bubbleColor = Colors.green.shade900;
        textColor = Colors.green.shade100;
      }
    } else if (available < 0) {
      bubbleColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      if (Theme.of(context).brightness == Brightness.dark) {
        bubbleColor = Colors.red.shade900;
        textColor = Colors.red.shade100;
      }
    } else {
      bubbleColor = Colors.grey.withValues(alpha: 0.1);
      textColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }

    final editingCategoryId = ref.watch(editingCategoryProvider);
    final isEditing = editingCategoryId == widget.viewModel.category.id;
    final viewMode = ref.watch(budgetViewModeProvider);

    return DragTarget<double>(
      onWillAcceptWithDetails: (details) => details.data > 0,
      onAcceptWithDetails: (details) => _onDragAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          color: candidateData.isNotEmpty
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.viewModel.category.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (viewMode == BudgetViewMode.standard) ...[
                  Expanded(
                    flex: 2,
                    child: isEditing
                        ? BudgetInputField(
                            initialValue: widget.viewModel.budgeted,
                            onSubmitted: _onSubmit,
                            onCancel: () {
                              ref.read(editingCategoryProvider.notifier).state =
                                  null;
                            },
                            onNext: () => _moveFocus(1),
                            onPrevious: () => _moveFocus(-1),
                          )
                        : GestureDetector(
                            onTap: () {
                              ref.read(editingCategoryProvider.notifier).state =
                                  widget.viewModel.category.id;
                            },
                            onLongPress: _showQuickActions,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedCountText(
                                value: widget.viewModel.budgeted,
                                format: currency,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _inspectCategory,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 4.0),
                        child: AnimatedCountText(
                          value: widget.viewModel.activity,
                          format: currency,
                          textAlign: TextAlign.right,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationStyle: TextDecorationStyle.dotted,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerRight,
                      child: AnimatedCountText(
                        value: available,
                        format: currency,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    flex: 6,
                    child: Builder(builder: (context) {
                      final budgeted = widget.viewModel.budgeted;
                      final spent = widget.viewModel.activity.abs();
                      final progress = budgeted > 0
                          ? (spent / budgeted).clamp(0.0, 1.0)
                          : (spent > 0 ? 1.0 : 0.0);
                      final isOverspent = spent > budgeted;
                      final barColor =
                          isOverspent ? Colors.red : Colors.green;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${currency.format(spent)} / ${currency.format(budgeted)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress,
                            color: barColor,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
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
