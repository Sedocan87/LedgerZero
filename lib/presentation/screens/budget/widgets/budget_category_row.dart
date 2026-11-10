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
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_columns.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/core/constants/category_icon_resolver.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';

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

  /// The row's sheet (tap or long-press the row): the category's full name
  /// and activity (tap for its transactions), then the quick actions.
  void _showQuickActions() {
    final target = _target();
    final payment = widget.viewModel.payment;
    final fmt = ref.read(appFormatterProvider);
    final name = widget.viewModel.category.name;
    final activity = widget.viewModel.activity;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('budget.rowActivity'),
                  title: Text(name, style: theme.textTheme.titleMedium),
                  subtitle: Semantics(
                    label: amountSemanticsLabel(
                      l10n: l10n,
                      formatter: fmt,
                      amount: activity,
                      amountContext: AmountContext.activity,
                    ),
                    excludeSemantics: true,
                    child: Text(
                      l10n.labelValue(l10n.activity, fmt.formatMoney(activity)),
                      style: theme.textTheme.bodyMedium?.tabular.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      _inspectCategory();
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    AppLocalizations.of(context)!.budgetPreviousMonth,
                  ),
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
                            content: Text(
                              target.l10n.cardPaymentNothingMissing,
                            ),
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
                    title: Text(
                      AppLocalizations.of(context)!.budgetAverageSpent,
                    ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppSemanticColors.of(context);
    final l10n = AppLocalizations.of(context);
    final available = widget.viewModel.available;
    final category = widget.viewModel.category;

    // Colour carries the state of the available amount (on the exact int
    // sign, so a zero balance is neutral and never shown as "-0.00").
    final Color pillText;
    final Color pillFill;
    if (available > 0) {
      pillText = colors.success;
      pillFill = AppSemanticColors.tonal(colors.success, scheme.surface);
    } else if (available < 0 && widget.viewModel.isCreditOverspent) {
      // Credit overspending (card spending the category could not cover):
      // card debt, not charged to next month's To Be Budgeted.
      pillText = colors.warning;
      pillFill = AppSemanticColors.tonal(colors.warning, scheme.surface);
    } else if (available < 0) {
      pillText = colors.error;
      pillFill = AppSemanticColors.tonal(colors.error, scheme.surface);
    } else {
      pillText = scheme.onSurfaceVariant;
      pillFill = scheme.surfaceContainerHigh;
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
    final progress = budgeted > 0
        ? (spent / budgeted).clamp(0.0, 1.0)
        : (spent > 0 ? 1.0 : 0.0);
    final isOverspent = available < 0 || (budgeted > 0 && spent > budgeted);
    final standard = viewMode == BudgetViewMode.standard;

    final badge = Container(
      width: BudgetColumns.iconSize,
      height: BudgetColumns.iconSize,
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(catIcon, size: 16, color: catColor),
    );

    // The name on one line; under it a 2 dp progress bar, or on a card's
    // payment row what is still missing to pay the card.
    final nameBlock = Column(
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
                  color: colors.warning,
                  semanticLabel: l10n?.budgetGoalUnderfunded,
                ),
              ),
            Expanded(
              // The full name is in the row's sheet (and for screen
              // readers, in the text itself).
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
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
                ? l10n?.cardPaymentMissing(fmt.formatMoney(payment.missing)) ??
                      ''
                : l10n?.cardPaymentCovered ?? '',
            key: Key('budget.cardMissing.${category.id}'),
            // A large amount on a narrow phone wraps after "Still missing:".
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.tabular.copyWith(
              color: payment.missing > 0 ? colors.warning : colors.success,
            ),
          ),
        ] else if (standard &&
            widget.viewModel.payment == null &&
            (budgeted > 0 || spent > 0)) ...[
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            color: isOverspent
                ? (widget.viewModel.isCreditOverspent
                      ? colors.warning
                      : colors.error)
                : colors.success,
            backgroundColor: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ],
      ],
    );

    // Budgeted: plain text, tap for the calculator (48 dp target).
    final budgetedCell = InkWell(
      onTap: () => _showCalculatorModal(widget.viewModel.budgeted),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.centerRight,
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(
          horizontal: BudgetColumns.cellPadding,
        ),
        child: _FittedAmount(
          budgeted,
          amountContext: AmountContext.budgeted,
          style: BudgetColumns.amountStyle(theme).copyWith(
            color: budgeted == 0 ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );

    // Activity: only in the wide layout (tablets); tap for the transactions.
    final activityCell = InkWell(
      onTap: _inspectCategory,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.centerRight,
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(
          horizontal: BudgetColumns.cellPadding,
        ),
        child: _FittedAmount(
          widget.viewModel.activity,
          amountContext: AmountContext.activity,
          style: BudgetColumns.amountStyle(
            theme,
          ).copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );

    // Available: a pill coloured by state.
    final availablePill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BudgetColumns.pillPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: pillFill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: _FittedAmount(
        available,
        amountContext: AmountContext.available,
        style: BudgetColumns.pillStyle(theme).copyWith(color: pillText),
      ),
    );
    final availableCell = Align(
      alignment: Alignment.centerRight,
      child: available < 0 && widget.viewModel.isCreditOverspent
          ? Tooltip(
              key: Key('budget.creditOverspent.${category.id}'),
              message: l10n?.budgetCreditOverspent ?? '',
              child: availablePill,
            )
          : availablePill,
    );

    // Progress Bar Mode (Comparison/Simple)
    Widget comparisonBar() {
      final barOverspent = spent > budgeted;
      final barColor = barOverspent ? colors.error : colors.success;

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
                    style: theme.textTheme.labelSmall?.tabular,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                NumberFormat.percentPattern(fmt.locale).format(progress),
                style: theme.textTheme.labelSmall?.tabular.copyWith(
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
            backgroundColor: scheme.surfaceContainerHighest,
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
          // The row's sheet: its activity and the quick actions.
          onTap: _showQuickActions,
          onLongPress: _showQuickActions,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth - 2 * AppSpacing.md;
              final columns = BudgetColumns.of(context, fmt, contentWidth);
              final Widget content;
              if (!standard) {
                final nameRow = Row(
                  children: [
                    badge,
                    const SizedBox(width: BudgetColumns.iconGap),
                    Expanded(child: nameBlock),
                  ],
                );
                // The bar beside the name from 460 dp, else under it.
                content = contentWidth >= 460
                    ? Row(
                        children: [
                          Expanded(flex: 3, child: nameRow),
                          const SizedBox(width: BudgetColumns.gap),
                          Expanded(flex: 6, child: comparisonBar()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          nameRow,
                          const SizedBox(height: 8),
                          comparisonBar(),
                        ],
                      );
              } else {
                // Fixed columns beside the name; under it (own line) they
                // may shrink rather than overflow.
                Widget cell(double width, Widget child) {
                  final sized = SizedBox(width: width, child: child);
                  return columns.nameOnOwnLine ? Flexible(child: sized) : sized;
                }

                final amounts = [
                  cell(columns.budgeted, budgetedCell),
                  const SizedBox(width: BudgetColumns.gap),
                  if (columns.activity case final width?) ...[
                    cell(width, activityCell),
                    const SizedBox(width: BudgetColumns.gap),
                  ],
                  cell(columns.available, availableCell),
                ];
                content = columns.nameOnOwnLine
                    // Large text on a narrow phone: the name on its own
                    // line, the amounts under it in their columns.
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                badge,
                                const SizedBox(width: BudgetColumns.iconGap),
                                Expanded(child: nameBlock),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: amounts,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          badge,
                          const SizedBox(width: BudgetColumns.iconGap),
                          Expanded(child: nameBlock),
                          const SizedBox(width: BudgetColumns.gap),
                          ...amounts,
                        ],
                      );
              }
              return Container(
                color: candidateData.isNotEmpty
                    ? scheme.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
                constraints: const BoxConstraints(minHeight: 56),
                alignment: Alignment.centerLeft,
                // The budgeted cell is 48 dp tall: with 4 dp above and
                // below, a standard row is 56 dp.
                padding: EdgeInsets.symmetric(
                  vertical: standard ? 4 : AppSpacing.md - 4,
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
        style: style?.tabular,
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
