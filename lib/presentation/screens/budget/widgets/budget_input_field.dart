import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

class BudgetInputField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onSubmitted;
  final VoidCallback? onCancel;

  const BudgetInputField({
    super.key,
    required this.initialValue,
    required this.onSubmitted,
    this.onCancel,
  });

  @override
  State<BudgetInputField> createState() => _BudgetInputFieldState();
}

class _BudgetInputFieldState extends State<BudgetInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Convert initial value to string, removing trailing .0 if present
    String text = widget.initialValue.toStringAsFixed(2);
    if (text.endsWith('.00')) {
      text = text.substring(0, text.length - 3);
    }

    _controller = TextEditingController(text: text);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
       widget.onCancel?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    // Basic parsing, could be enhanced with expression evaluation
    double value;
    try {
      // Handle simple cases manually to be safe or use NumberFormat
      // For now, removing commas allows parsing standard format "1,000.00"
      // Ideally we should use NumberFormat from intl package based on locale
      value = double.parse(_controller.text.replaceAll(',', ''));
    } catch (e) {
      value = widget.initialValue;
    }
    widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      onTap: () {
        // Select all text on tap
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
    );
  }
}
