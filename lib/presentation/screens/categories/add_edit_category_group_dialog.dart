import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class AddEditCategoryGroupDialog extends ConsumerStatefulWidget {
  final CategoryGroup? group;

  const AddEditCategoryGroupDialog({super.key, this.group});

  @override
  ConsumerState<AddEditCategoryGroupDialog> createState() =>
      _AddEditCategoryGroupDialogState();
}

class _AddEditCategoryGroupDialogState
    extends ConsumerState<AddEditCategoryGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameController.text = widget.group!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(categoryRepositoryProvider);
      if (widget.group != null) {
        await repository.updateCategoryGroup(
          widget.group!.copyWith(name: _nameController.text.trim()),
        );
      } else {
        await repository.createCategoryGroup(
          CategoryGroup(
            id: const Uuid().v4(),
            name: _nameController.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.group != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.editCategoryGroup : l10n.addCategoryGroup),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _nameController,
          label: l10n.groupName,
          validator: (val) =>
              val == null || val.trim().isEmpty ? l10n.fieldRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
