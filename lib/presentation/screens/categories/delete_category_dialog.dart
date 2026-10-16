import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

/// What the user chose in [DeleteCategoryDialog].
class DeleteCategoryDecision {
  const DeleteCategoryDecision({this.targetCategoryId});

  /// Category that receives transactions, budgets and other references;
  /// `null` deletes without a replacement (budgeted money goes back to To
  /// Be Budgeted, transactions become uncategorised).
  final String? targetCategoryId;
}

/// Asks how to delete [category]: move everything to another category, or
/// delete it without a replacement. Pops a [DeleteCategoryDecision], or
/// `null` when cancelled.
class DeleteCategoryDialog extends ConsumerStatefulWidget {
  const DeleteCategoryDialog({
    super.key,
    required this.category,
    required this.transactionCount,
  });

  final Category category;
  final int transactionCount;

  @override
  ConsumerState<DeleteCategoryDialog> createState() =>
      _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends ConsumerState<DeleteCategoryDialog> {
  /// `true`: move to [_targetId]; `false`: delete without replacement.
  bool? _moveToTarget;
  String? _targetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(categoryGroupsWithCategoriesProvider);
    final items = <DropdownMenuItem<String>>[
      for (final group in groupsAsync.valueOrNull ?? const [])
        for (final cat in group.categories)
          if (cat.id != widget.category.id)
            DropdownMenuItem(
              value: cat.id,
              child: Text(
                '${group.group.name}: ${cat.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
    ];
    final hasTargets = items.isNotEmpty;
    final moveToTarget = _moveToTarget ?? hasTargets;
    final canDelete = !moveToTarget || _targetId != null;

    return AlertDialog(
      title: Text(l10n.deleteNamedTitle(widget.category.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteCategoryTransactionCount(widget.transactionCount)),
            const SizedBox(height: 8),
            if (groupsAsync.isLoading)
              const LinearProgressIndicator()
            else
              RadioGroup<bool>(
                groupValue: moveToTarget,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _moveToTarget = value);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      key: const Key('deleteCategory.move'),
                      value: true,
                      enabled: hasTargets,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.deleteCategoryMoveOption),
                    ),
                    if (!hasTargets)
                      Text(l10n.deleteCategoryNoOtherCategories)
                    else if (moveToTarget)
                      DropdownButtonFormField<String>(
                        key: const Key('deleteCategory.target'),
                        initialValue: _targetId,
                        isExpanded: true,
                        items: items,
                        onChanged: (value) => setState(() => _targetId = value),
                        decoration: InputDecoration(
                          labelText: l10n.deleteCategoryTargetLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    RadioListTile<bool>(
                      key: const Key('deleteCategory.noTarget'),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.deleteCategoryNoTargetOption),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              moveToTarget
                  ? l10n.deleteCategoryMoveExplanation
                  : l10n.deleteCategoryNoTargetExplanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('deleteCategory.confirm'),
          onPressed: canDelete
              ? () => Navigator.pop(
                  context,
                  DeleteCategoryDecision(
                    targetCategoryId: moveToTarget ? _targetId : null,
                  ),
                )
              : null,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// Asks where the categories of a non-empty [group] should go before it is
/// deleted. Pops the target group id, or `null` when cancelled.
class DeleteCategoryGroupDialog extends StatefulWidget {
  const DeleteCategoryGroupDialog({
    super.key,
    required this.group,
    required this.categoryCount,
    required this.otherGroups,
  });

  final CategoryGroup group;
  final int categoryCount;

  /// Possible targets (never contains [group]); must not be empty.
  final List<CategoryGroup> otherGroups;

  @override
  State<DeleteCategoryGroupDialog> createState() =>
      _DeleteCategoryGroupDialogState();
}

class _DeleteCategoryGroupDialogState extends State<DeleteCategoryGroupDialog> {
  String? _targetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.deleteNamedTitle(widget.group.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteGroupMoveExplanation(widget.categoryCount)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('deleteGroup.target'),
            initialValue: _targetId,
            isExpanded: true,
            items: [
              for (final g in widget.otherGroups)
                DropdownMenuItem(
                  value: g.id,
                  child: Text(g.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _targetId = value),
            decoration: InputDecoration(
              labelText: l10n.deleteGroupTargetLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('deleteGroup.confirm'),
          onPressed: _targetId == null
              ? null
              : () => Navigator.pop(context, _targetId),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}
