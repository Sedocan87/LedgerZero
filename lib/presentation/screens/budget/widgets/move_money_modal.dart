import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/undo/budget_undo_actions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_fromCategoryId == null || _toCategoryId == null) {
      return;
    }

    // Prevent moving to same category
    if (_fromCategoryId == _toCategoryId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.moveMoneySameCategory),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = ref
          .read(appFormatterProvider)
          .parseAmount(_amountController.text);
      if (amount == null || amount <= 0) {
        return;
      }
      final month = ref.read(selectedBudgetMonthProvider);
      final budgetingService = ref.read(budgetingServiceProvider);

      await budgetingService.moveMoney(
        _fromCategoryId!,
        _toCategoryId!,
        amount,
        month,
      );

      // Undoable like every other budget edit (undo moves the money back
      // in one unit of work).
      final undoService = ref.read(undoServiceProvider);
      final action = MoveMoneyAction(
        budgetingService: budgetingService,
        fromCategoryId: _fromCategoryId!,
        toCategoryId: _toCategoryId!,
        amount: amount,
        month: month,
      );
      undoService.addAction(action);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        // The modal closes; show the snack bar on the screen below it.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.moveMoneyDone),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => undoService
                    .undo(action)
                    .catchError(
                      (Object e, StackTrace st) =>
                          Logger.error('Undoing move money failed', e, st),
                    ),
              ),
            ),
          );
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Visible categories only; a hidden one is listed when it is the
  /// preselected source or target (money can still be moved out of it).
  bool _listed(Category c) =>
      !c.isHidden || c.id == _fromCategoryId || c.id == _toCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref
        .watch(categoryGroupsWithCategoriesProvider)
        .whenData(
          (groups) => [
            for (final g in groups)
              CategoryGroupWithCategories(
                group: g.group,
                categories: g.categories.where(_listed).toList(),
              ),
          ],
        );

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
                  key: ValueKey(_fromCategoryId),
                  initialValue: _fromCategoryId,
                  // Long "Group: Category" names ellipsize on phones.
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.moveMoneyFrom,
                    border: const OutlineInputBorder(),
                  ),
                  items: groupsWithCategories.expand((group) {
                    return group.categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(
                          '${group.group.name}: ${category.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    });
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _fromCategoryId = value;
                    });
                  },
                  validator: (value) => value == null
                      ? AppLocalizations.of(context)!.selectCategoryRequired
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_toCategoryId),
                  initialValue: _toCategoryId,
                  // Long "Group: Category" names ellipsize on phones.
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.moveMoneyTo,
                    border: const OutlineInputBorder(),
                  ),
                  items: groupsWithCategories.expand((group) {
                    return group.categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(
                          '${group.group.name}: ${category.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    });
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _toCategoryId = value;
                    });
                  },
                  validator: (value) => value == null
                      ? AppLocalizations.of(context)!.selectCategoryRequired
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _amountController,
                  label: AppLocalizations.of(context)!.amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = ref
                        .read(appFormatterProvider)
                        .parseAmount(value);
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
        error: (err, stack) =>
            LoadErrorView(error: err, stackTrace: stack, compact: true),
      ),
    );
  }
}
