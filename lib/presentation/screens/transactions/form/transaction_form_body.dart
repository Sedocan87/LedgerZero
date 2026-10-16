import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/payee_field.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/picker_field.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/split_editor.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_draft.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_form_controller.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/transaction_tutorial_manager.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

/// The fields of the add/edit transaction form.
class TransactionFormBody extends ConsumerWidget {
  const TransactionFormBody({
    super.key,
    required this.controller,
    required this.tutorialKeys,
    required this.payeeFocus,
    required this.onSubmit,
    required this.onPayeeSelected,
    this.onSaveAndAddAnother,
  });

  final TransactionFormController controller;

  /// Targets of the entry tutorial (owned by the screen).
  final TransactionTutorialKeys tutorialKeys;
  final FocusNode payeeFocus;

  /// Validates and saves (memo "done" key).
  final VoidCallback onSubmit;
  final ValueChanged<Payee> onPayeeSelected;

  /// Shown for new transactions only.
  final VoidCallback? onSaveAndAddAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final accounts = <String, Account>{
      for (final account
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        account.id: account,
    };
    final categories = <String, Category>{
      for (final category
          in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        category.id: category,
    };
    final c = controller;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TransactionFormType>(
            segments: [
              ButtonSegment(
                value: TransactionFormType.expense,
                label: Text(l10n.outflow),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: TransactionFormType.income,
                label: Text(l10n.inflow),
                icon: const Icon(Icons.add_circle_outline),
              ),
              ButtonSegment(
                value: TransactionFormType.transfer,
                label: Text(l10n.transfer),
                icon: const Icon(Icons.swap_horiz),
              ),
            ],
            selected: {c.formType},
            onSelectionChanged: (selection) => c.setFormType(selection.first),
          ),
          const SizedBox(height: 16),
          AppTextField(
            key: tutorialKeys.amount,
            controller: c.amountController,
            label: l10n.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => c.changed(),
            validator: (value) {
              final amount = fmt.parseAmount(value ?? '');
              return amount == null || amount == 0 ? l10n.invalidAmount : null;
            },
          ),
          const SizedBox(height: 16),
          PickerField(
            label: c.isTransfer ? l10n.fromAccount : l10n.account,
            text: accounts[c.accountId]?.name ?? '',
            onTap: () async {
              final picked = await showAccountPicker(context);
              if (picked != null) {
                c.accountId = picked.id;
                c.changed();
              }
            },
          ),
          const SizedBox(height: 16),
          if (c.isTransfer) ...[
            PickerField(
              label: l10n.toAccount,
              text: accounts[c.transferAccountId]?.name ?? '',
              onTap: () async {
                final picked = await showAccountPicker(
                  context,
                  excludeId: c.accountId,
                );
                if (picked != null) {
                  c.transferAccountId = picked.id;
                  c.changed();
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          PickerField(
            label: l10n.date,
            text: fmt.formatDate(c.date),
            prefixIcon: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: CalendarDate.toLocalDay(c.date),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                c.date = CalendarDate.fromLocalPick(picked);
                c.changed();
              }
            },
          ),
          const SizedBox(height: 16),
          if (!c.isTransfer) ...[
            PayeeField(
              key: tutorialKeys.payee,
              controller: c.payeeController,
              focusNode: payeeFocus,
              onSelected: onPayeeSelected,
              onTextChanged: c.payeeTextChanged,
            ),
            const SizedBox(height: 16),
            if (!c.isSplit)
              KeyedSubtree(
                key: tutorialKeys.category,
                child: PickerField(
                  label: l10n.category,
                  text: categories[c.categoryId]?.name ?? '',
                  onTap: () async {
                    final picked = await showCategoryPicker(context);
                    if (picked != null) {
                      c.categoryId = picked.id;
                      c.changed();
                    }
                  },
                ),
              ),
            SwitchListTile(
              title: Text(l10n.split),
              value: c.isSplit,
              onChanged: c.setSplit,
            ),
            if (c.isSplit)
              SplitEditor(
                items: c.splits,
                categories: categories,
                onChanged: c.changed,
              ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: c.memoController,
            label: l10n.memo,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            onChanged: (_) => c.changed(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.cleared),
            value: c.cleared != TransactionClearStatus.uncleared,
            onChanged: c.setCleared,
          ),
          if (!c.isEditing && !c.isSplit && !c.isTransfer)
            _RecurrenceSection(controller: c),
          const SizedBox(height: 24),
          if (onSaveAndAddAnother != null) ...[
            AppButton.secondary(
              label: l10n.saveAndAddAnother,
              icon: Icons.playlist_add,
              onPressed: onSaveAndAddAnother,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = controller;
    String label(RecurrenceFrequency f) => switch (f) {
      RecurrenceFrequency.daily => l10n.daily,
      RecurrenceFrequency.weekly => l10n.weekly,
      RecurrenceFrequency.monthly => l10n.monthly,
      RecurrenceFrequency.yearly => l10n.yearly,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: Text(l10n.recurring),
          value: c.isRecurring,
          onChanged: (value) {
            c.isRecurring = value;
            c.changed();
          },
        ),
        if (c.isRecurring)
          DropdownButtonFormField<RecurrenceFrequency>(
            key: ValueKey(c.frequency),
            initialValue: c.frequency,
            items: [
              for (final f in RecurrenceFrequency.values)
                DropdownMenuItem(value: f, child: Text(label(f))),
            ],
            onChanged: (value) {
              if (value != null) {
                c.frequency = value;
                c.changed();
              }
            },
            decoration: InputDecoration(labelText: l10n.frequency),
          ),
      ],
    );
  }
}
