import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_input_field.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';

class BudgetCategoryRow extends ConsumerStatefulWidget {
  final BudgetCategoryViewModel viewModel;

  const BudgetCategoryRow({super.key, required this.viewModel});

  @override
  ConsumerState<BudgetCategoryRow> createState() => _BudgetCategoryRowState();
}

class _BudgetCategoryRowState extends ConsumerState<BudgetCategoryRow> {
  bool _isEditing = false;

  Future<void> _onSubmit(double value) async {
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);

    await budgetingService.setCategoryBudgetedAmount(
      widget.viewModel.category.id,
      value,
      month,
    );

    if (mounted) {
      setState(() {
        _isEditing = false;
      });
    }

    // Refresh the budget view to reflect changes
    ref.invalidate(budgetViewModelProvider);
    ref.invalidate(tbbProvider);
  }

  Future<void> _autoAssign(AutoAssignRule rule) async {
    final month = ref.read(selectedBudgetMonthProvider);
    final budgetingService = ref.read(budgetingServiceProvider);

    await budgetingService.autoAssign(
      widget.viewModel.category.id,
      month,
      rule,
    );

    // Refresh providers
    ref.invalidate(budgetViewModelProvider);
    ref.invalidate(tbbProvider);
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
          Expanded(
            flex: 2,
            child: _isEditing
                ? BudgetInputField(
                    initialValue: widget.viewModel.budgeted,
                    onSubmitted: _onSubmit,
                    onCancel: () {
                      if (mounted) {
                        setState(() {
                          _isEditing = false;
                        });
                      }
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    onLongPress: _showQuickActions,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                       alignment: Alignment.centerRight,
                       padding: const EdgeInsets.symmetric(vertical: 8),
                       child: Text(
                        currency.format(widget.viewModel.budgeted),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(widget.viewModel.activity),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
               decoration: BoxDecoration(
                 color: bubbleColor,
                 borderRadius: BorderRadius.circular(8),
               ),
               alignment: Alignment.centerRight,
               child: Text(
                currency.format(available),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
