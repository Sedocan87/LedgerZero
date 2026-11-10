import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_columns.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

/// Id of the seeded Savings & Investments group (stable across renames).
final String savingsGroupId = DeterministicId.defaultGroup(
  DefaultCategories.savingsGroup,
);

/// The header of a category group: its name (with the group's ⓘ where it
/// has one) and what the group has available, in the rows' Available
/// column. The expand chevron is the [ExpansionTile]'s.
class BudgetGroupRow extends ConsumerWidget {
  final CategoryGroup group;

  /// Sum of the group's available amounts (minor units).
  final int available;

  /// Shown instead of the group's name (the "Hidden categories" section).
  final String? title;

  const BudgetGroupRow({
    super.key,
    required this.group,
    required this.available,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        if (title != null) ...[
          Icon(
            Icons.visibility_off_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title ?? group.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // How money budgeted here reaches the savings accounts.
              if (group.id == savingsGroupId)
                const InfoButton(HelpTopic.saving),
              // What the credit cards' payment categories do.
              if (group.id == CardPayments.groupId)
                const InfoButton(HelpTopic.cardPayments),
            ],
          ),
        ),
        const SizedBox(width: BudgetColumns.gap),
        SizedBox(
          width: BudgetColumns.availableWidth(context, fmt),
          child: Padding(
            padding: const EdgeInsets.only(right: BudgetColumns.pillPadding),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: AmountText(
                available,
                amountContext: AmountContext.available,
                maxLines: 1,
                style: BudgetColumns.pillStyle(theme).copyWith(
                  color: available < 0
                      ? AppSemanticColors.of(context).error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
