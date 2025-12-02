import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/categories_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

class MoveMoneyModal extends ConsumerStatefulWidget {
  final String? initialFromCategoryId;
  final String? initialToCategoryId;

  const MoveMoneyModal({
    super.key,
    this.initialFromCategoryId,
    this.initialToCategoryId,
  });

  @override
  ConsumerState<MoveMoneyModal> createState() => _MoveMoneyModalState();
}

class _MoveMoneyModalState extends ConsumerState<MoveMoneyModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _fromCategoryId;
  String? _toCategoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromCategoryId = widget.initialFromCategoryId;
    _toCategoryId = widget.initialToCategoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromCategoryId == null || _toCategoryId == null) return;

    // Prevent moving to same category
    if (_fromCategoryId == _toCategoryId) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination categories must be different')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      final month = ref.read(selectedBudgetMonthProvider);
      final budgetingService = ref.read(budgetingServiceProvider);

      await budgetingService.moveMoney(
        _fromCategoryId!,
        _toCategoryId!,
        amount,
        month,
      );

      // Refresh providers
      ref.invalidate(budgetViewModelProvider);
      ref.invalidate(tbbProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryGroupsWithCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: categoriesAsync.when(
        data: (groupsWithCategories) {
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.moveMoney,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _fromCategoryId,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.moveMoneyFrom,
                    border: const OutlineInputBorder(),
                  ),
                  items: groupsWithCategories.expand((group) {
                    return group.categories.map((category) {
                       return DropdownMenuItem<String>(
                        value: category.id,
                        child: Text('${group.group.name}: ${category.name}'),
                      );
                    });
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _fromCategoryId = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _toCategoryId,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.moveMoneyTo,
                    border: const OutlineInputBorder(),
                  ),
                  items: groupsWithCategories.expand((group) {
                    return group.categories.map((category) {
                       return DropdownMenuItem<String>(
                        value: category.id,
                        child: Text('${group.group.name}: ${category.name}'),
                      );
                    });
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _toCategoryId = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _amountController,
                  label: AppLocalizations.of(context)!.amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.invalidAmount;
                    }
                    final amount = double.tryParse(value.replaceAll(',', '.'));
                    if (amount == null || amount <= 0) {
                      return AppLocalizations.of(context)!.invalidAmount;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AppButton.primary(
                  label: AppLocalizations.of(context)!.save,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
