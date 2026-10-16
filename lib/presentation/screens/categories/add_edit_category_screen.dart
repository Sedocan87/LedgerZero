import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class AddEditCategoryScreen extends ConsumerStatefulWidget {
  final String? categoryId;

  const AddEditCategoryScreen({super.key, this.categoryId});

  @override
  ConsumerState<AddEditCategoryScreen> createState() =>
      _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends ConsumerState<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedGroupId;
  bool _isHidden = false;
  int? _selectedColor;
  String? _selectedIcon;
  bool _isLoading = false;
  Category? _existingCategory;
  int _transactionCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _loadCategory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    setState(() => _isLoading = true);
    try {
      final category = await ref
          .read(categoryRepositoryProvider)
          .getCategoryById(widget.categoryId!);
      if (category != null) {
        _existingCategory = category;
        _nameController.text = category.name;
        _selectedGroupId = category.categoryGroupId;
        _isHidden = category.isHidden;
        _selectedColor = category.color;
        _selectedIcon = category.icon;

        // Load stats
        final transactions = await ref
            .read(transactionRepositoryProvider)
            .getTransactions(
              filter: TransactionFilter(categoryIds: [category.id]),
            );
        _transactionCount = transactions.length;
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate group selection
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.categoryGroupRequired),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(categoryRepositoryProvider);
      final now = DateTime.now();

      if (widget.categoryId != null && _existingCategory != null) {
        final updatedCategory = _existingCategory!.copyWith(
          name: _nameController.text.trim(),
          categoryGroupId: _selectedGroupId,
          isHidden: _isHidden,
          color: _selectedColor,
          icon: _selectedIcon,
        );
        await repository.updateCategory(updatedCategory);
      } else {
        final newCategory = Category(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          categoryGroupId: _selectedGroupId,
          isHidden: _isHidden,
          color: _selectedColor,
          icon: _selectedIcon,
          createdAt: now,
        );
        await repository.createCategory(newCategory);
      }

      if (mounted) {
        context.pop();
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(categoryGroupsProvider);
    final isEditing = widget.categoryId != null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editCategory : l10n.addCategory),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading && _existingCategory == null && isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEditing) ...[
                      Text(
                        l10n.categoryUsage(_transactionCount),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      controller: _nameController,
                      label: l10n.categoryName,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.nameRequired;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    groupsAsync.when(
                      data: (groups) {
                        return DropdownButtonFormField<String>(
                          key: ValueKey(_selectedGroupId),
                          initialValue: _selectedGroupId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.categoryGroup,
                            border: const OutlineInputBorder(),
                          ),
                          items: groups.map((group) {
                            return DropdownMenuItem(
                              value: group.id,
                              child: Text(
                                group.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedGroupId = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? l10n.fieldRequired : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) =>
                          LoadErrorView(error: e, stackTrace: s, compact: true),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.hideCategory),
                      value: _isHidden,
                      onChanged: (val) => setState(() => _isHidden = val),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.color,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryColors.map((colorValue) {
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = colorValue),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: _selectedColor == colorValue
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.icon,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryIcons.entries.map((entry) {
                        final isSelected = _selectedIcon == entry.key;
                        return IconButton(
                          icon: Icon(entry.value),
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : null,
                          onPressed: () =>
                              setState(() => _selectedIcon = entry.key),
                          style: isSelected
                              ? IconButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
