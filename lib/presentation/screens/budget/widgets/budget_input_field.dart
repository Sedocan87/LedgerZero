import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';
import 'package:flutter/services.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

class BudgetInputField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onSubmitted;
  final VoidCallback? onCancel;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const BudgetInputField({
    super.key,
    required this.initialValue,
    required this.onSubmitted,
    this.onCancel,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<BudgetInputField> createState() => _BudgetInputFieldState();
}

class _BudgetInputFieldState extends State<BudgetInputField> {
  TextEditingController? _controller;
  late FocusNode _focusNode;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
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
    if (!_focusNode.hasFocus && !_isNavigating) {
      // Check if we are showing the calculator modal, if so don't cancel yet?
      // Actually losing focus to modal is tricky.
      // But typically modals don't steal focus in a way that triggers this immediately if we use showModalBottomSheet.
      // However, if the user taps outside, we want to submit/cancel.
      // For now, let's keep it simple.
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

  double _parseText(String text) {
    if (text.contains(RegExp(r'[+\-*/]'))) {
      final locale = Localizations.localeOf(context).toString();
      final format = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);

      if (format.symbols.GROUP_SEP.isNotEmpty) {
        text = text.replaceAll(format.symbols.GROUP_SEP, '');
      }
      if (format.symbols.DECIMAL_SEP.isNotEmpty && format.symbols.DECIMAL_SEP != '.') {
         text = text.replaceAll(format.symbols.DECIMAL_SEP, '.');
      }

      return MathEvaluator.evaluate(text);
    } else {
      try {
        final locale = Localizations.localeOf(context).toString();
        final format = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);
        return format.parse(text).toDouble();
      } catch (e) {
        try {
          return double.parse(text.replaceAll(',', ''));
        } catch (_) {
          return widget.initialValue;
        }
      }
    }
  }

  void _submit() {
    if (_controller == null) return;
    double value;
    try {
      value = _parseText(_controller!.text);
    } catch (e) {
      value = widget.initialValue;
    }
    widget.onSubmitted(value);
  }

  void _adjustValue(double delta) {
    if (_controller == null) return;
    try {
      double currentValue = _parseText(_controller!.text);
      double newValue = currentValue + delta;

      final locale = Localizations.localeOf(context).toString();
      final format = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);
      _controller!.text = format.format(newValue).trim();
    } catch (e) {
      // ignore
    }
  }

  void _showCalculator() {
    // We need to prevent onCancel from firing when losing focus to the modal
    _focusNode.removeListener(_onFocusChange);

    showModalBottomSheet(
      context: context,
      builder: (context) => BudgetCalculator(
        initialValue: _controller!.text,
        onValueChanged: (val) {
          _controller!.text = val;
        },
        onSubmitted: () {
          Navigator.pop(context);
          _submit();
        },
      ),
    ).then((_) {
      // Re-attach listener when modal closes (if we didn't submit)
      // If we submitted, this widget might be disposed or state changed.
      if (mounted) {
        _focusNode.addListener(_onFocusChange);
        // If we didn't submit (e.g. user tapped outside modal), we might want to refocus or cancel.
        // For now, let's just focus back.
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _isNavigating = true;
        _submit();
        widget.onNext?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _isNavigating = true;
        _submit();
        widget.onPrevious?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox();
    }

    return KeyboardListener(
      focusNode: FocusNode(), // Needed for listener, but we use _focusNode for text field
      onKeyEvent: _handleKeyEvent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: () => _adjustValue(-1.0),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          Expanded(
            child: AppTextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              onTap: () {
                _controller!.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controller!.text.length,
                );
              },
              suffixIcon: IconButton(
                icon: const Icon(Icons.calculate, size: 18),
                onPressed: _showCalculator,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: () => _adjustValue(1.0),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}
