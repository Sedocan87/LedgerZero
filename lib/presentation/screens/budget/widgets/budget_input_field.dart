import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';
import 'package:flutter/services.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';

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
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isDisposed = false;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Handle loose focus -> cancel
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      final locale = Localizations.localeOf(context).toString();
      final format = NumberFormat.currency(
        locale: locale,
        symbol: '',
        decimalDigits: 2,
      );
      final text = format.format(widget.initialValue).trim();
      _controller = TextEditingController(text: text);

      // Select all text on init for easy overwriting
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _controllerInitialized = true;
    }
  }

  void _onFocusChange() {
    if (_isDisposed) {
      return;
    }
    if (!_focusNode.hasFocus) {
      // Only cancel if we lost focus completely and aren't submitting
      // For safety, delay check slightly or just rely on onSubmitted?
      // Often better to submit on blur for budget apps, or cancel.
      // Sticking to cancel as per previous logic, but being careful.
      widget.onCancel?.call();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  double _parseText(String text) {
    if (text.isEmpty) {
      return 0.0;
    }

    // Simple cleanup of currency symbols if any slipped in (though we use symbol: '')
    // Logic from previous implementation regarding MathEvaluator
    try {
      if (text.contains(RegExp(r'[+\-*/]'))) {
        // Math eval logic... simplified for redundancy here since we didn't change it much
        final locale = Localizations.localeOf(context).toString();
        final format = NumberFormat.currency(
          locale: locale,
          symbol: '',
          decimalDigits: 2,
        );

        // Replace separators locally if needed, similar to before
        String cleanCheck = text;
        if (format.symbols.GROUP_SEP.isNotEmpty) {
          cleanCheck = cleanCheck.replaceAll(format.symbols.GROUP_SEP, '');
        }
        if (format.symbols.DECIMAL_SEP.isNotEmpty &&
            format.symbols.DECIMAL_SEP != '.') {
          cleanCheck = cleanCheck.replaceAll(format.symbols.DECIMAL_SEP, '.');
        }
        return MathEvaluator.evaluate(cleanCheck);
      }

      final locale = Localizations.localeOf(context).toString();
      final format = NumberFormat.currency(
        locale: locale,
        symbol: '',
        decimalDigits: 2,
      );
      return format.parse(text).toDouble();
    } catch (e) {
      // Fallback
      return double.tryParse(text.replaceAll(',', '')) ?? widget.initialValue;
    }
  }

  void _submit() {
    if (_isDisposed) {
      return;
    }
    final value = _parseText(_controller.text);
    widget.onSubmitted(value);
  }

  void _showCalculator() {
    _focusNode.unfocus(); // Explicitly unfocus to avoid fighting
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BudgetCalculator(
          initialValue: _controller.text,
          onValueChanged: (val) {
            // Calculator updates text
            _controller.text = val;
          },
          onSubmitted: () {
            Navigator.pop(context);
            _submit();
          },
        ),
      ),
    ).then((_) {
      // If cancelled calculator, maybe re-focus? Or just cancel edit?
      // Let's cancel edit if they dismissed calculator without submitting
      if (mounted && !_isDisposed && !FocusScope.of(context).hasFocus) {
        widget.onCancel?.call();
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _submit();
        widget.onNext?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _submit();
        widget.onPrevious?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onCancel?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controllerInitialized) {
      return const SizedBox();
    }

    return KeyboardListener(
      focusNode: FocusNode(), // Dummy node for key events
      onKeyEvent: _handleKeyEvent,
      child: AppTextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true, // Critical for immediate keyboard
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        textAlign: TextAlign.end,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calculate, size: 18),
            onPressed: _showCalculator,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ),
    );
  }
}
