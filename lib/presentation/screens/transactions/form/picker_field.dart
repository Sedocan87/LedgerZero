import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

/// A read-only form field that shows [text] and opens a picker on tap.
///
/// The displayed text is derived from the caller's state on every build, so
/// it is correct whenever the referenced list (accounts, categories) loads.
class PickerField extends StatefulWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.text,
    required this.onTap,
    this.focusNode,
    this.prefixIcon,
    this.onClear,
    this.validator,
    this.fieldKey,
  });

  final String label;
  final String text;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final Widget? prefixIcon;

  /// When set, a clear button is shown while [text] is not empty.
  final VoidCallback? onClear;

  /// Validates the field inside an enclosing [Form] (receives [text]).
  final FormFieldValidator<String>? validator;

  /// Key of the underlying text field (lets tests find a specific picker).
  final Key? fieldKey;

  @override
  State<PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends State<PickerField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant PickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.text) {
      // Changing the controller notifies the enclosing Form, which must not
      // happen during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != widget.text) {
          _controller.text = widget.text;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onClear = widget.onClear;
    final Widget? suffixIcon;
    if (onClear != null && widget.text.isNotEmpty) {
      suffixIcon = IconButton(
        icon: const Icon(Icons.clear),
        tooltip: AppLocalizations.of(context)!.clear,
        onPressed: onClear,
      );
    } else if (widget.prefixIcon == null) {
      suffixIcon = const Icon(Icons.arrow_drop_down);
    } else {
      suffixIcon = null;
    }
    return AppTextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      readOnly: true,
      prefixIcon: widget.prefixIcon,
      suffixIcon: suffixIcon,
      onTap: widget.onTap,
      // Validate the caller's value: the controller lags one frame behind.
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.text),
    );
  }
}
