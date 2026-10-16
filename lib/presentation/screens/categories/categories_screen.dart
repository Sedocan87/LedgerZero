import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/csv/category_csv_service.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_group_dialog.dart';
import 'package:ledger_zero/presentation/screens/categories/delete_category_dialog.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

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

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Deletes [category] through [CategoryService]: the user either picks a
  /// target category (transactions, budgets and references move there) or
  /// explicitly deletes without a replacement.
  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final service = ref.read(categoryServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    try {
      final count = await service.countTransactions(category.id);
      if (!context.mounted) {
        return;
      }
      final decision = await showDialog<DeleteCategoryDecision>(
        context: context,
        builder: (context) =>
            DeleteCategoryDialog(category: category, transactionCount: count),
      );
      if (decision == null) {
        return;
      }
      await service.deleteCategory(
        category.id,
        reassignTo: decision.targetCategoryId,
      );
      if (context.mounted) {
        _showMessage(context, l10n.categoryDeletedMessage);
      }
    } catch (e, st) {
      Logger.error('Deleting category ${category.id} failed', e, st);
      if (context.mounted) {
        _showMessage(context, l10n.deleteCategoryFailed);
      }
    }
  }

  /// Deletes [group]. An empty group is deleted after a confirmation; a
  /// group with categories needs a target group they move to (with their
  /// budgets and transactions).
  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    CategoryGroup group,
  ) async {
    final service = ref.read(categoryServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    try {
      final count = await service.countCategoriesInGroup(group.id);
      if (!context.mounted) {
        return;
      }
      String? target;
      if (count == 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteNamedTitle(group.name)),
            content: Text(l10n.deleteGroupEmptyConfirmation),
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
        if (confirmed != true) {
          return;
        }
      } else {
        final otherGroups = [
          for (final g
              in await ref
                  .read(categoryRepositoryProvider)
                  .getAllCategoryGroups())
            if (g.id != group.id) g,
        ]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
        if (!context.mounted) {
          return;
        }
        if (otherGroups.isEmpty) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.deleteCategoryGroup),
              content: Text(l10n.deleteGroupNoOtherGroup),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
          return;
        }
        target = await showDialog<String>(
          context: context,
          builder: (context) => DeleteCategoryGroupDialog(
            group: group,
            categoryCount: count,
            otherGroups: otherGroups,
          ),
        );
        if (target == null) {
          return;
        }
      }
      await service.deleteCategoryGroup(group.id, moveCategoriesTo: target);
    } catch (e, st) {
      Logger.error('Deleting category group ${group.id} failed', e, st);
      if (context.mounted) {
        _showMessage(context, l10n.deleteGroupFailed);
      }
    }
  }

  /// Shares the category list as CSV (temporary file, deleted after
  /// sharing).
  Future<void> _exportCategories() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final groups = [...await repo.getAllCategoryGroups()]
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      final categories = [...await repo.getAllCategories()]
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      final csv = ref
          .read(categoryCsvServiceProvider)
          .buildCsv(groups, categories);
      final files = ref.read(exportFileServiceProvider);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = await files.writeString('categories_$stamp.csv', csv);
      await files.shareAndDelete(file);
    } catch (e, st) {
      Logger.error('Exporting categories failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedGeneric)));
    }
  }

  /// Lets the user pick a CSV with the system file picker and imports the
  /// groups and categories it adds.
  Future<void> _importCategories() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ExternalUiGuard.run(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['csv', 'txt'],
        ),
      );
      if (picked == null) {
        return;
      }
      final content = await picked.readAsText();
      final result = await ref
          .read(categoryCsvServiceProvider)
          .importCsv(content);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.categoriesImported(result.categoriesCreated)),
        ),
      );
    } on CategoryCsvFormatException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.categoryImportInvalidFile)),
      );
    } catch (e, st) {
      Logger.error('Importing categories failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailedGeneric)));
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
              tooltip: l10n.help,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.categoryTipsTitle),
                    content: SingleChildScrollView(
                      child: Text(l10n.categoryTipsBody),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.ok),
                      ),
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
                  _exportCategories();
                } else if (value == 'import') {
                  _importCategories();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reorder',
                  child: Text(l10n.reorderGroups),
                ),
                PopupMenuItem(value: 'export', child: Text(l10n.export)),
                PopupMenuItem(value: 'import', child: Text(l10n.import)),
              ],
            ),
        ],
      ),
      body: groupsAsync.when(
        data: (groupsWithCategories) {
          final filteredGroups = groupsWithCategories
              .map((group) {
                final filteredCats = group.categories
                    .where(
                      (c) => c.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();
                return CategoryGroupWithCategories(
                  group: group.group,
                  categories: filteredCats,
                );
              })
              .where(
                (g) =>
                    g.categories.isNotEmpty ||
                    g.group.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

          if (filteredGroups.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty
                    ? l10n.noCategoriesYet
                    : l10n.noMatchingCategories,
              ),
            );
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
                              group: groupWithCats.group,
                            ),
                          );
                        } else if (value == 'reorder') {
                          context.pushNamed(
                            'reorder-categories',
                            pathParameters: {'groupId': groupWithCats.group.id},
                          );
                        } else if (value == 'delete') {
                          _deleteGroup(context, ref, groupWithCats.group);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.editCategoryGroup),
                        ),
                        PopupMenuItem(
                          value: 'reorder',
                          child: Text(l10n.reorderCategories),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
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
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.editCategory),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'edit') {
                          context.pushNamed(
                            'edit-category',
                            pathParameters: {'id': category.id},
                          );
                        } else if (val == 'delete') {
                          _deleteCategory(context, ref, category);
                        }
                      },
                    ),
                    onTap: () {
                      context.pushNamed(
                        'edit-category',
                        pathParameters: {'id': category.id},
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            LoadErrorView(error: err, stackTrace: stack, compact: true),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories-fab',
        onPressed: () {
          context.pushNamed('add-category');
        },
        tooltip: l10n.addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
