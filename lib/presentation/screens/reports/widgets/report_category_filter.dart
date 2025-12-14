import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';

class ReportCategoryFilter extends ConsumerWidget {
  const ReportCategoryFilter({super.key});

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categories = await categoryRepo.getAllCategories();
    // Sort by name
    categories.sort((a, b) => a.name.compareTo(b.name));

    final currentFilters = ref.read(reportCategoryFilterProvider);

    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => _CategoryFilterSheet(
          categories: categories,
          initialSelection: currentFilters,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterCount = ref.watch(reportCategoryFilterProvider).length;

    return IconButton(
      icon: Badge(
        label: filterCount > 0 ? Text('$filterCount') : null,
        isLabelVisible: filterCount > 0,
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () => _showFilterSheet(context, ref),
      tooltip: AppLocalizations.of(context)!.filterCategories,
    );
  }
}

class _CategoryFilterSheet extends ConsumerStatefulWidget {
  final List<Category> categories;
  final Set<String> initialSelection;

  const _CategoryFilterSheet({
    required this.categories,
    required this.initialSelection,
  });

  @override
  ConsumerState<_CategoryFilterSheet> createState() =>
      _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends ConsumerState<_CategoryFilterSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.filterCategories,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                      });
                    },
                    child: Text(AppLocalizations.of(context)!.clear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final cat = widget.categories[index];
                  final isSelected = _selectedIds.contains(cat.id);
                  return CheckboxListTile(
                    title: Text(cat.name),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(cat.id);
                        } else {
                          _selectedIds.remove(cat.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ref.read(reportCategoryFilterProvider.notifier).state =
                            _selectedIds;
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)!.apply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
