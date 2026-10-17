import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

class BudgetGroupRow extends StatelessWidget {
  final CategoryGroup group;

  const BudgetGroupRow({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.folder_outlined, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              group.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
