import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  TextEditingController? _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final locale = Localizations.localeOf(context).toString();
      // Use currency format without symbol to respect locale decimal/grouping separators
      final format = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);
      final text = format.format(widget.initialValue).trim();
      _controller = TextEditingController(text: text);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
       widget.onCancel?.call();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller == null) {
      return;
    }

    double value;
    try {
      final locale = Localizations.localeOf(context).toString();
      final format = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);
      // parse() returns num, so we cast to double
      value = format.parse(_controller!.text).toDouble();
    } catch (e) {
      // Fallback: try parsing with standard double.parse (e.g. if user wiped formatting)
      try {
         value = double.parse(_controller!.text.replaceAll(',', ''));
      } catch (_) {
         value = widget.initialValue;
      }
    }
    widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    // If controller is still null (shouldn't happen after didChangeDependencies), show empty
    if (_controller == null) {
      return const SizedBox();
    }

    return AppTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      onTap: () {
        // Select all text on tap
        _controller!.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller!.text.length,
        );
      },
    );
  }
}
