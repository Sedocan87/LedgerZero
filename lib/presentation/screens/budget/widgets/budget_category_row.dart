import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';

class BudgetCategoryRow extends StatelessWidget {
  final BudgetCategoryViewModel viewModel;

  const BudgetCategoryRow({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(decimalDigits: 2);
    final available = viewModel.available;

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
              viewModel.category.name,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(viewModel.budgeted),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currency.format(viewModel.activity),
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
