import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
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
import 'package:ledger_zero/core/constants/category_icon_resolver.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/widgets/common/overflow_tooltip_text.dart';

class BudgetCategoryRow extends ConsumerStatefulWidget {
  final BudgetCategoryViewModel viewModel;

  const BudgetCategoryRow({super.key, required this.viewModel});

  @override
  ConsumerState<BudgetCategoryRow> createState() => _BudgetCategoryRowState();
}

class _BudgetCategoryRowState extends ConsumerState<BudgetCategoryRow> {
  /// What a write started from this row needs, taken when its sheet or
  /// dialog opens. The row can be rebuilt for other data or removed while
  /// the sheet is open (a sync hides or deletes the category), so nothing
  /// is read from the widget or its `ref` when the user finally confirms.
  _RowTarget _target() => _RowTarget(
    container: ProviderScope.containerOf(context, listen: false),
    messenger: ScaffoldMessenger.of(context),
    l10n: AppLocalizations.of(context)!,
    categoryId: widget.viewModel.category.id,
    month: ref.read(selectedBudgetMonthProvider),
    budgeted: widget.viewModel.budgeted,
  );

  /// The amount budgeted right now: the row's own while it is on screen
  /// (it may have changed since the sheet opened), else what the sheet was
  /// opened with.
  int _currentBudgeted(_RowTarget target) =>
      mounted ? widget.viewModel.budgeted : target.budgeted;

  Future<void> _onSubmit(int value, _RowTarget target) async {
    await HapticFeedback.selectionClick();
    final budgetingService = target.container.read(budgetingServiceProvider);
    final oldAmount = _currentBudgeted(target);

    try {
      await budgetingService.setCategoryBudgetedAmount(
        target.categoryId,
        value,
        target.month,
      );
    } catch (e, stack) {
      // E.g. the category was deleted by sync while the sheet was open.
      Logger.error('Setting a budget failed', e, stack);
      target.showError();
      return;
    }

    if (oldAmount != value) {
      final action = BudgetChangeAction(
        budgetingService: budgetingService,
        categoryId: target.categoryId,
        month: target.month,
        oldAmount: oldAmount,
        newAmount: value,
      );
      target.container.read(undoServiceProvider).addAction(action);
      _showUndoSnackbar(action, target);
    }
  }

  Future<void> _onDragAccept(int tbbAmount) async {
    final target = _target();
    final val = await showDialog<int>(
      context: context,
      builder: (context) => _AssignAmountDialog(
        categoryName: widget.viewModel.category.name,
        initialAmount: tbbAmount,
      ),
    );
    if (val != null && val > 0) {
      // Add to existing budgeted amount
      await _onSubmit(_currentBudgeted(target) + val, target);
    }
  }

  Future<void> _autoAssign(AutoAssignRule rule, _RowTarget target) async {
    await HapticFeedback.selectionClick();
    final budgetingService = target.container.read(budgetingServiceProvider);
    final oldAmount = _currentBudgeted(target);

    final int newAmount;
    try {
      final budgetRepo = target.container.read(budgetRepositoryProvider);
      await budgetingService.autoAssign(target.categoryId, target.month, rule);

      // Fetch new amount to record undo
      final newBudget = await budgetRepo.getBudgetByCategoryAndMonth(
        target.categoryId,
        CalendarDate.monthKey(target.month),
      );
      newAmount = newBudget?.budgeted ?? 0;
    } catch (e, stack) {
      Logger.error('Quick-filling a budget failed', e, stack);
      target.showError();
      return;
    }

    if (oldAmount != newAmount) {
      final action = BudgetChangeAction(
        budgetingService: budgetingService,
        categoryId: target.categoryId,
        month: target.month,
        oldAmount: oldAmount,
        newAmount: newAmount,
      );
      target.container.read(undoServiceProvider).addAction(action);
      _showUndoSnackbar(action, target);
    }
  }

  /// "Budget updated" with Undo for [action]. The snack bar can outlive
  /// this row, so it keeps the service and messenger, not the ref; an undo
  /// that fails (e.g. the category was deleted meanwhile) shows the generic
  /// error instead of throwing.
  void _showUndoSnackbar(BudgetChangeAction action, _RowTarget target) {
    final l10n = target.l10n;
    final undoService = target.container.read(undoServiceProvider);
    final messenger = target.messenger;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text(l10n.budgetUpdated),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => undoService.undo(action).catchError((
            Object e,
            StackTrace st,
          ) {
            Logger.error('Undoing a budget change failed', e, st);
            messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
          }),
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
    final target = _target();
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
            // Accepts a plain amount or an unevaluated expression. Parsed
            // before the sheet closes: an unfinished or impossible one
            // ("50+", "5/0") keeps it open with a message, instead of
            // closing as if the amount had been set.
            final val = parseBudgetInput(currentValue, fmt);
            if (val == null) {
              return target.l10n.invalidAmount;
            }
            if (val < 0) {
              // Budgeting a negative amount would raise To Be Budgeted.
              return target.l10n.budgetAmountNegative;
            }
            Navigator.pop(context);
            _onSubmit(val, target);
            return null;
          },
        ),
      ),
    );
  }

  void _showQuickActions() {
    final target = _target();
    final payment = widget.viewModel.payment;
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
                  _autoAssign(AutoAssignRule.lastMonthBudgeted, target);
                },
              ),
              // Nothing is spent from a payment category: it gets "cover
              // the card balance" instead of the spending-based fills.
              if (payment != null)
                ListTile(
                  key: const Key('budget.coverCardBalance'),
                  leading: const Icon(Icons.credit_score_outlined),
                  title: Text(
                    AppLocalizations.of(context)!.cardPaymentCoverBalance,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (payment.missing > 0) {
                      _onSubmit(
                        _currentBudgeted(target) + payment.missing,
                        target,
                      );
                    } else {
                      target.messenger.showSnackBar(
                        SnackBar(
                          content: Text(target.l10n.cardPaymentNothingMissing),
                        ),
                      );
                    }
                  },
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    AppLocalizations.of(context)!.budgetLastMonthSpent,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _autoAssign(AutoAssignRule.lastMonthSpent, target);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(AppLocalizations.of(context)!.budgetAverageSpent),
                  onTap: () {
                    Navigator.pop(context);
                    _autoAssign(AutoAssignRule.averageSpent, target);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.money_off),
                title: Text(AppLocalizations.of(context)!.budgetZeroOut),
                onTap: () {
                  Navigator.pop(context);
                  _onSubmit(0, target);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(AppLocalizations.of(context)!.moveMoney),
                onTap: () {
                  // The sheet's context is gone once popped; the row's
                  // navigator stays (the row itself may not).
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showModalBottomSheet(
                    context: navigator.context,
                    isScrollControlled: true,
                    builder: (context) => MoveMoneyModal(
                      initialFromCategoryId: target.categoryId,
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
    final category = widget.viewModel.category;

    // Determine color for available amount bubble (on the exact int sign,
    // so a zero balance is neutral and never shown as "-0.00").
    Color bubbleColor;
    Color textColor;

    if (available > 0) {
      bubbleColor = AppColors.success.withValues(
        alpha: 0.1,
      ); // M3 way: tertiaryContainer
      textColor = AppColors.success;
    } else if (available < 0 && widget.viewModel.isCreditOverspent) {
      // Credit overspending (card spending the category could not cover):
      // card debt, not charged to next month's To Be Budgeted.
      bubbleColor = AppColors.warning.withValues(alpha: 0.12);
      textColor = AppColors.warning;
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
    final catColor = CategoryIconResolver.tintFor(
      color: category.color,
      icon: category.icon,
      id: category.id,
      name: category.name,
      brightness: theme.brightness,
    );
    final catIcon = CategoryIconResolver.iconFor(
      icon: category.icon,
      id: category.id,
      name: category.name,
    );

    final budgeted = widget.viewModel.budgeted;
    // Net spending: a category whose refunds exceed its spending has spent
    // nothing (not the refund's amount, which would show as overspending).
    final spent = math.max(0, -widget.viewModel.activity);
    final miniProgress = budgeted > 0
        ? (spent / budgeted).clamp(0.0, 1.0)
        : (spent > 0 ? 1.0 : 0.0);
    final isOverspent = available < 0 || (budgeted > 0 && spent > budgeted);
    final standard = viewMode == BudgetViewMode.standard;

    // Category Icon Badge + Name + Subtle Progress Bar
    final nameBlock = Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(catIcon, size: 15, color: catColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.viewModel.goalTarget > 0 &&
                      widget.viewModel.budgeted < widget.viewModel.goalTarget)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: Colors.orange.shade700,
                        semanticLabel: l10n?.budgetGoalUnderfunded,
                      ),
                    ),
                  Expanded(
                    // Two lines; tap shows a longer name.
                    child: OverflowTooltipText(
                      category.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.viewModel.payment case final payment?
                  when payment.debt > 0 || payment.missing > 0) ...[
                const SizedBox(height: 2),
                Text(
                  payment.missing > 0
                      ? l10n?.cardPaymentMissing(
                              fmt.formatMoney(payment.missing),
                            ) ??
                            ''
                      : l10n?.cardPaymentCovered ?? '',
                  key: Key('budget.cardMissing.${category.id}'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: payment.missing > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
              if (standard &&
                  widget.viewModel.payment == null &&
                  (budgeted > 0 || spent > 0)) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: miniProgress,
                    minHeight: 3,
                    color: isOverspent ? AppColors.expense : AppColors.success,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    // Assigned (Budgeted) Column - Editable via Calculator
    final budgetedCell = InkWell(
      onTap: () => _showCalculatorModal(widget.viewModel.budgeted),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.centerRight,
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.28,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: _FittedAmount(
          widget.viewModel.budgeted,
          amountContext: AmountContext.budgeted,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );

    // Activity Column (Read only)
    final activityCell = InkWell(
      onTap: _inspectCategory,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.centerRight,
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: _FittedAmount(
          widget.viewModel.activity,
          amountContext: AmountContext.activity,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    // Available Column (Bubble)
    final availableBubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: _FittedAmount(
        available,
        amountContext: AmountContext.available,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final availableCell = Container(
      alignment: Alignment.centerRight,
      child: available < 0 && widget.viewModel.isCreditOverspent
          ? Tooltip(
              key: Key('budget.creditOverspent.${category.id}'),
              message: l10n?.budgetCreditOverspent ?? '',
              child: availableBubble,
            )
          : availableBubble,
    );

    // Progress Bar Mode (Comparison/Simple)
    Widget comparisonBar() {
      // Ratio for the progress bar only.
      final progress = budgeted > 0
          ? (spent / budgeted).clamp(0.0, 1.0)
          : (spent > 0 ? 1.0 : 0.0);
      final barOverspent = spent > budgeted;
      final barColor = barOverspent ? AppColors.expense : AppColors.success;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Semantics(
                  label: l10n?.amountSemanticsSpentOfBudgeted(
                    fmt.formatMoney(spent),
                    fmt.formatMoney(budgeted),
                  ),
                  excludeSemantics: l10n != null,
                  child: Text(
                    '${fmt.formatMoney(spent)} / ${fmt.formatMoney(budgeted)}',
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                NumberFormat.percentPattern(fmt.locale).format(progress),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: barColor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ],
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data > 0,
      onAcceptWithDetails: (details) => _onDragAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          onLongPress: _showQuickActions,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On a phone the name and three amounts do not fit side by
              // side (see budgetRowIsCompact): the name gets its own line.
              final compact = budgetRowIsCompact(
                constraints.maxWidth - 2 * AppSpacing.md,
              );
              final Widget content;
              if (compact) {
                content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nameBlock,
                    if (standard) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(child: budgetedCell),
                          const SizedBox(width: 4),
                          Expanded(child: activityCell),
                          Expanded(child: availableCell),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      comparisonBar(),
                    ],
                  ],
                );
              } else {
                content = Row(
                  children: [
                    Expanded(flex: 3, child: nameBlock),
                    if (standard) ...[
                      const SizedBox(width: 4),
                      Expanded(flex: 2, child: budgetedCell),
                      Expanded(flex: 2, child: activityCell),
                      Expanded(flex: 2, child: availableCell),
                    ] else ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 6, child: comparisonBar()),
                    ],
                  ],
                );
              }
              return Container(
                color: candidateData.isNotEmpty
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
                // The amount cells are at least kMinInteractiveDimension
                // tall; the vertical padding is reduced so the row keeps
                // its height.
                padding: EdgeInsets.symmetric(
                  vertical: standard
                      ? (compact ? AppSpacing.sm : AppSpacing.md - 6)
                      : (compact ? AppSpacing.md - 4 : AppSpacing.md),
                  horizontal: AppSpacing.md,
                ),
                child: content,
              );
            },
          ),
        );
      },
    );
  }
}

/// Whether a budget row (or the header and footer above and below it) whose
/// content is [contentWidth] dp wide uses the two-line layout: the category
/// name on its own line and the three amounts in equal columns under it.
///
/// Side by side, a 360 dp phone leaves about 51 dp for an amount and 61 dp
/// for a name, which cuts off "250,00 €" and "Lebensmittel" alike
/// (measured with Roboto in `budget_row_fit_test.dart`). Name plus icon
/// need about 160 dp and each amount up to 100 dp, so the single line is
/// kept from 460 dp on (tablets, landscape).
bool budgetRowIsCompact(double contentWidth) => contentWidth < 460;

/// An amount of the budget table: one line, tabular figures, never cut off.
/// If it is wider than its cell (six-digit amounts, a large font scale) it
/// is scaled down to fit instead of ending in an ellipsis.
class _FittedAmount extends StatelessWidget {
  final int amount;
  final AmountContext amountContext;
  final TextStyle? style;

  const _FittedAmount(this.amount, {required this.amountContext, this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: AmountText(
        amount,
        amountContext: amountContext,
        style: style?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
      ),
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

/// See [_BudgetCategoryRowState._target].
class _RowTarget {
  /// Outlives the row, unlike its `ref`.
  final ProviderContainer container;
  final ScaffoldMessengerState messenger;
  final AppLocalizations l10n;
  final String categoryId;

  /// The month on screen when the sheet opened (the selection can move on
  /// by itself at midnight on the 1st).
  final DateTime month;

  /// Budgeted amount when the sheet opened.
  final int budgeted;

  const _RowTarget({
    required this.container,
    required this.messenger,
    required this.l10n,
    required this.categoryId,
    required this.month,
    required this.budgeted,
  });

  void showError() =>
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
}
