import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

class CategorySelector extends ConsumerWidget {
  final ValueChanged<Category> onSelected;

  const CategorySelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchyAsync = ref.watch(categoryHierarchyProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => hierarchyAsync.when(
        data: (hierarchy) => ListView.builder(
          controller: scrollController,
          itemCount: hierarchy.length,
          itemBuilder: (context, index) {
            final group = hierarchy.keys.elementAt(index);
            final categories = hierarchy[group]!;
            if (categories.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...categories.map(
                  (category) => ListTile(
                    title: Text(category.name),
                    leading: const Icon(Icons.label_outline),
                    onTap: () {
                      onSelected(category);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Divider(),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  static void show(BuildContext context, ValueChanged<Category> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategorySelector(onSelected: onSelected),
    );
  }
}
