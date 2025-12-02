import 'package:flutter/material.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

class BudgetGroupRow extends StatelessWidget {
  final CategoryGroup group;

  const BudgetGroupRow({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Text(
      group.name,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
