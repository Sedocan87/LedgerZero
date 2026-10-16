import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class ReorderGroupsScreen extends ConsumerStatefulWidget {
  const ReorderGroupsScreen({super.key});

  @override
  ConsumerState<ReorderGroupsScreen> createState() =>
      _ReorderGroupsScreenState();
}

class _ReorderGroupsScreenState extends ConsumerState<ReorderGroupsScreen> {
  List<CategoryGroup>? _groups;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await ref
        .read(categoryRepositoryProvider)
        .getAllCategoryGroups();
    if (mounted) {
      setState(() {
        _groups = groups
          ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      });
    }
  }

  Future<void> _save() async {
    if (_groups == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      for (int i = 0; i < _groups!.length; i++) {
        final group = _groups![i];
        if (group.sortOrder != i) {
          await repo.updateCategoryGroup(group.copyWith(sortOrder: i));
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

    if (_groups == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reorderGroups)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reorderGroups),
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
            final item = _groups!.removeAt(oldIndex);
            _groups!.insert(newIndex, item);
          });
        },
        children: [
          for (final group in _groups!)
            ListTile(
              key: Key(group.id),
              title: Text(group.name),
              trailing: const Icon(Icons.drag_handle),
            ),
        ],
      ),
    );
  }
}
