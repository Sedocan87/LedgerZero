import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

/// Id of the seeded Savings & Investments group (stable across renames).
final String savingsGroupId = DeterministicId.defaultGroup(
  DefaultCategories.savingsGroup,
);

class BudgetGroupRow extends StatelessWidget {
  final CategoryGroup group;

  /// Shown instead of the group's name (the "Hidden categories" section).
  final String? title;

  const BudgetGroupRow({super.key, required this.group, this.title});

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
            child: Icon(
              title == null
                  ? Icons.folder_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title ?? group.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // How money budgeted here reaches the savings accounts.
          if (group.id == savingsGroupId) const InfoButton(HelpTopic.saving),
        ],
      ),
    );
  }
}
