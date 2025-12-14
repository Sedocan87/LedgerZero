import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/categories_provider.dart';

class ReassignCategoryDialog extends ConsumerStatefulWidget {
  final int count;
  final String excludeCategoryId;

  const ReassignCategoryDialog({
    super.key,
    required this.count,
    required this.excludeCategoryId,
  });

  @override
  ConsumerState<ReassignCategoryDialog> createState() =>
      _ReassignCategoryDialogState();
}

class _ReassignCategoryDialogState
    extends ConsumerState<ReassignCategoryDialog> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(categoryGroupsWithCategoriesProvider);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.deleteCategory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.categoryHasTransactions(widget.count)),
          const SizedBox(height: 16),
          groupsAsync.when(
            data: (groups) {
              final items = <DropdownMenuItem<String>>[];
              for (final group in groups) {
                for (final cat in group.categories) {
                  if (cat.id == widget.excludeCategoryId) {
                    continue;
                  }
                  items.add(
                    DropdownMenuItem(
                      value: cat.id,
                      child: Text('${group.group.name}: ${cat.name}'),
                    ),
                  );
                }
              }

              if (items.isEmpty) {
                return const Text('No other categories available.');
              }

              return DropdownButtonFormField<String>(
                key: ValueKey(_selectedCategoryId),
                initialValue: _selectedCategoryId,
                items: items,
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: Text(l10n.category),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error: $e'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _selectedCategoryId == null
              ? null
              : () {
                  Navigator.pop(context, _selectedCategoryId);
                },
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}
