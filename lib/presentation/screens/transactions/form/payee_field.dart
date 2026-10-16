import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

/// Payee input with suggestions.
///
/// The [controller] belongs to the form, so the field shows the payee even
/// when the payee list loads after the transaction, and the form always
/// knows the typed text. Typing anything that is not the selected payee's
/// name reports [onTextChanged] (the form then forgets the selected payee,
/// so a payee can be cleared or replaced by a new name).
class PayeeField extends ConsumerWidget {
  const PayeeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    required this.onTextChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Payee> onSelected;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final payees = ref.watch(suggestedPayeesProvider).valueOrNull ?? const [];
    return RawAutocomplete<Payee>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<Payee>.empty();
        }
        return payees.where((p) => p.name.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textController, node, onFieldSubmitted) {
        return AppTextField(
          key: const Key('payee_field'),
          controller: textController,
          focusNode: node,
          label: l10n.payee,
          textInputAction: TextInputAction.next,
          onChanged: onTextChanged,
          onFieldSubmitted: (_) {
            onFieldSubmitted();
            onSubmitted?.call();
          },
        );
      },
      optionsViewBuilder: (context, onOptionSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(option.name),
                      onTap: () => onOptionSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
