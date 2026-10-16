import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class ReorderCategoriesScreen extends ConsumerStatefulWidget {
  final String groupId;

  const ReorderCategoriesScreen({super.key, required this.groupId});

  @override
  ConsumerState<ReorderCategoriesScreen> createState() =>
      _ReorderCategoriesScreenState();
}

class _ReorderCategoriesScreenState
    extends ConsumerState<ReorderCategoriesScreen> {
  List<Category>? _categories;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    // We need to fetch all categories and filter, or add getCategoriesByGroupId to repository.
    // Assuming watchAllCategories is available or getAllCategories.
    final allCategories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();
    if (mounted) {
      setState(() {
        _categories =
            allCategories
                .where((c) => c.categoryGroupId == widget.groupId)
                .toList()
              ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      });
    }
  }

  Future<void> _save() async {
    if (_categories == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      for (int i = 0; i < _categories!.length; i++) {
        final category = _categories![i];
        if (category.sortOrder != i) {
          await repo.updateCategory(category.copyWith(sortOrder: i));
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      Logger.error('Action failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_categories == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reorderCategories)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reorderCategories),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ReorderableListView(
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final item = _categories!.removeAt(oldIndex);
            _categories!.insert(newIndex, item);
          });
        },
        children: [
          for (final category in _categories!)
            ListTile(
              key: Key(category.id),
              title: Text(category.name),
              trailing: const Icon(Icons.drag_handle),
            ),
        ],
      ),
    );
  }
}
