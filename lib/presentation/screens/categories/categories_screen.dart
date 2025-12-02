import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/categories_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_group_dialog.dart';
import 'package:ledger_zero/presentation/screens/categories/category_import_dialog.dart';
import 'package:ledger_zero/presentation/screens/categories/reassign_category_dialog.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
    final transRepo = ref.read(transactionRepositoryProvider);
    final catRepo = ref.read(categoryRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    try {
      final transactions = await transRepo.getTransactions(
        filter: TransactionFilter(categoryIds: [category.id]),
      );

      if (transactions.isNotEmpty) {
        if (!context.mounted) {
          return;
        }
        final targetCategoryId = await showDialog<String>(
          context: context,
          builder: (context) => ReassignCategoryDialog(
            count: transactions.length,
            excludeCategoryId: category.id,
          ),
        );

        if (targetCategoryId != null) {
          // Reassign
          final updatedTransactions = transactions
              .map((t) => t.copyWith(categoryId: targetCategoryId))
              .toList();
          await transRepo.batchUpdateTransactions(updatedTransactions);
          await catRepo.deleteCategory(category.id);
        }
      } else {
        if (!context.mounted) {
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${l10n.delete} ${category.name}?'),
            content: Text(l10n.deleteAccountConfirmation),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.delete)),
            ],
          ),
        );
        if (confirmed == true) {
          await catRepo.deleteCategory(category.id);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref, CategoryGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.delete} ${group.name}?'),
        content: Text(l10n.deleteAccountConfirmation), // Reusing existing confirmation message for now, ideally specific one
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(categoryRepositoryProvider)
            .deleteCategoryGroup(group.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _exportCategories(BuildContext context, WidgetRef ref) async {
    final groupsWithCats =
        ref.read(categoryGroupsWithCategoriesProvider).valueOrNull;
    if (groupsWithCats == null || groupsWithCats.isEmpty) {
      return;
    }

    final csvData = StringBuffer();
    csvData.writeln('Group,Category,Hidden'); // Header

    for (final group in groupsWithCats) {
      for (final cat in group.categories) {
        csvData.writeln('${group.group.name},${cat.name},${cat.isHidden}');
      }
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/categories_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csvData.toString());

      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportedTo(path))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(categoryGroupsWithCategoriesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Text(l10n.categories),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help', // Add l10n
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Category Best Practices'), // Add l10n
                    content: const SingleChildScrollView(
                      child: Text(
                          "- Group similar expenses (e.g., 'Housing', 'Food').\n"
                          "- Use 'Hide Category' instead of deleting to preserve history.\n"
                          "- Use emojis or icons for quick recognition.\n"
                          "- Keep it simple: Start with broad categories and split if needed."),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'))
                    ],
                  ),
                );
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: l10n.addCategoryGroup,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddEditCategoryGroupDialog(),
                );
              },
            ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'reorder') {
                  context.pushNamed('reorder-groups');
                } else if (value == 'export') {
                  _exportCategories(context, ref);
                } else if (value == 'import') {
                  showDialog(
                    context: context,
                    builder: (context) => const CategoryImportDialog(),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'reorder', child: Text(l10n.reorderGroups)),
                PopupMenuItem(value: 'export', child: Text(l10n.export)),
                PopupMenuItem(value: 'import', child: Text(l10n.import)),
              ],
            ),
        ],
      ),
      body: groupsAsync.when(
        data: (groupsWithCategories) {
          final filteredGroups = groupsWithCategories.map((group) {
            final filteredCats = group.categories
                .where((c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
            return CategoryGroupWithCategories(
                group: group.group, categories: filteredCats);
          }).where((g) =>
              g.categories.isNotEmpty ||
              g.group.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          if (filteredGroups.isEmpty) {
            return Center(child: Text(l10n.noRecentTransactions));
          }
          return ListView.builder(
            itemCount: filteredGroups.length,
            itemBuilder: (context, index) {
              final groupWithCats = filteredGroups[index];
              return ExpansionTile(
                key: Key(groupWithCats.group.id),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupWithCats.group.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          showDialog(
                            context: context,
                            builder: (context) => AddEditCategoryGroupDialog(
                                group: groupWithCats.group),
                          );
                        } else if (value == 'reorder') {
                          context.pushNamed('reorder-categories',
                              pathParameters: {
                                'groupId': groupWithCats.group.id
                              });
                        } else if (value == 'delete') {
                          if (groupWithCats.categories.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text(
                                    'Cannot delete non-empty group. Please delete or move categories first.')));
                          } else {
                            _deleteGroup(context, ref, groupWithCats.group);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'edit', child: Text(l10n.editCategoryGroup)),
                        PopupMenuItem(
                            value: 'reorder',
                            child: Text(l10n.reorderCategories)),
                        PopupMenuItem(
                            value: 'delete', child: Text(l10n.delete)),
                      ],
                    ),
                  ],
                ),
                initiallyExpanded: true,
                children: groupWithCats.categories.map((category) {
                  return ListTile(
                    title: Text(
                      category.name,
                      style: category.isHidden
                          ? TextStyle(color: Theme.of(context).disabledColor)
                          : null,
                    ),
                    subtitle: category.isHidden ? Text(l10n.hidden) : null,
                    leading: CircleAvatar(
                      backgroundColor: category.color != null
                          ? Color(category.color!)
                          : Theme.of(context).primaryColor,
                      child: Icon(
                        category.icon != null
                            ? (categoryIcons[category.icon] ?? Icons.category)
                            : Icons.category,
                        color: Colors.white,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Text(l10n.editCategory)),
                        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      ],
                      onSelected: (val) {
                        if (val == 'edit') {
                          context.pushNamed('edit-category',
                              pathParameters: {'id': category.id});
                        } else if (val == 'delete') {
                          _deleteCategory(context, ref, category);
                        }
                      },
                    ),
                    onTap: () {
                      context.pushNamed('edit-category', pathParameters: {'id': category.id});
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.pushNamed('add-category');
        },
        tooltip: l10n.addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
