import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/picker_field.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

/// Editable state of one split line.
class SplitItem {
  SplitItem({this.id, this.categoryId, String amountText = '', String? memo}) {
    amountController.text = amountText;
    memoController.text = memo ?? '';
  }

  /// Id of the existing child transaction, `null` for a new line.
  final String? id;
  String? categoryId;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController memoController = TextEditingController();

  SplitDraft toDraft() => SplitDraft(
    id: id,
    amountText: amountController.text,
    categoryId: categoryId,
    memo: memoController.text.isEmpty ? null : memoController.text,
  );

  factory SplitItem.fromDraft(SplitDraft draft) => SplitItem(
    id: draft.id,
    categoryId: draft.categoryId,
    amountText: draft.amountText,
    memo: draft.memo,
  );

  void dispose() {
    amountController.dispose();
    memoController.dispose();
  }
}

/// Edits the lines of a split transaction. Amounts are entered without a
/// sign; the transaction type (outflow/inflow) gives the sign.
class SplitEditor extends ConsumerWidget {
  const SplitEditor({
    super.key,
    required this.items,
    required this.categories,
    required this.onChanged,
  });

  final List<SplitItem> items;

  /// Category lookup for the line labels (id -> category).
  final Map<String, Category> categories;

  /// Called after any change (the parent re-renders and autosaves).
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PickerField(
                          label: l10n.category,
                          text: categories[items[index].categoryId]?.name ?? '',
                          onTap: () async {
                            final picked = await showCategoryPicker(context);
                            if (picked != null) {
                              items[index].categoryId = picked.id;
                              onChanged();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: l10n.delete,
                        onPressed: () {
                          items.removeAt(index).dispose();
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: items[index].amountController,
                          label: l10n.amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          onChanged: (_) => onChanged(),
                          validator: (value) {
                            final parsed = fmt.parseAmount(value ?? '');
                            return parsed == null || parsed == 0
                                ? l10n.invalidAmount
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTextField(
                          controller: items[index].memoController,
                          label: l10n.memo,
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        AppButton.text(
          label: l10n.addSplit,
          icon: Icons.add,
          onPressed: () {
            items.add(SplitItem());
            onChanged();
          },
        ),
      ],
    );
  }
}
