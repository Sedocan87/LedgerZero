import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

/// Parses what the user typed into a budget amount field or the budget
/// calculator into minor units.
///
/// Plain amounts go through [AppFormatter.parseAmount] (locale-aware decimal
/// comma); arithmetic such as `50+12,50` goes through [MathEvaluator] with
/// the same decimal separator. An empty input is `0`. Returns `null` when the
/// input is not a valid amount or expression.
int? parseBudgetInput(String text, AppFormatter fmt) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return 0;
  }
  // An operator after the first character means arithmetic; a leading sign
  // alone is a plain (negative) amount.
  if (trimmed.substring(1).contains(RegExp(r'[+\-*/]'))) {
    try {
      return MathEvaluator.evaluate(
        trimmed,
        decimalSeparator: fmt.decimalSeparator,
      );
    } on FormatException {
      return null;
    }
  }
  return fmt.parseAmount(trimmed);
}

class BudgetCalculator extends ConsumerStatefulWidget {
  final String initialValue;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onSubmitted;

  const BudgetCalculator({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
    required this.onSubmitted,
  });

  @override
  ConsumerState<BudgetCalculator> createState() => _BudgetCalculatorState();
}

class _BudgetCalculatorState extends ConsumerState<BudgetCalculator> {
  late TextEditingController _controller;

  /// The pre-filled value is replaced (not appended to) by the first digit
  /// or decimal key, like a selected text field.
  bool _replaceOnInput = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      setState(() {});
      widget.onValueChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    final fmt = ref.read(appFormatterProvider);
    final separator = fmt.decimalSeparator;
    final replace = _replaceOnInput;
    _replaceOnInput = false;

    if (key == 'C') {
      _controller.clear();
    } else if (key == 'DEL') {
      if (_controller.text.isNotEmpty) {
        _controller.text = _controller.text.substring(
          0,
          _controller.text.length - 1,
        );
      }
    } else if (key == '=') {
      try {
        final result = MathEvaluator.evaluate(
          _controller.text,
          decimalSeparator: separator,
        );
        // Drop a zero fraction so further typing extends the whole number.
        var resultStr = fmt.formatAmountForInput(result);
        final zeroFraction = '${separator}00';
        if (resultStr.endsWith(zeroFraction)) {
          resultStr = resultStr.substring(
            0,
            resultStr.length - zeroFraction.length,
          );
        }
        _controller.text = resultStr;
        _replaceOnInput = true;
      } on FormatException {
        // Invalid expression: keep the text so the user can correct it.
      }
    } else if (['+', '-', '*', '/'].contains(key)) {
      _controller.text += key;
    } else {
      final text = replace || _isZero(_controller.text, separator)
          ? ''
          : _controller.text;
      if (key == separator) {
        // Only one decimal separator in the current operand.
        final operand = text.split(RegExp(r'[+\-*/]')).last;
        if (operand.contains(separator)) {
          _controller.text = text;
        } else {
          _controller.text = operand.isEmpty
              ? '${text}0$separator'
              : '$text$separator';
        }
      } else {
        // Digits 0-9
        _controller.text = text + key;
      }
    }
  }

  static bool _isZero(String text, String separator) =>
      text == '0' || text == '0${separator}00';

  Widget _buildKey(
    String label, {
    Color? color,
    Color? textColor,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () {
            if (label == 'OK') {
              widget.onSubmitted();
            } else {
              _onKeyPress(label);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color:
                  color ??
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: label == 'DEL'
                ? Icon(
                    Icons.backspace_outlined,
                    color: textColor ?? Theme.of(context).colorScheme.onSurface,
                    semanticLabel: AppLocalizations.of(
                      context,
                    )!.calculatorBackspace,
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color:
                          textColor ?? Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      height: 350,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Value Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            alignment: Alignment.centerRight,
            child: Text(
              _controller.text.isEmpty ? '0' : _controller.text,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey('7'),
                            _buildKey('8'),
                            _buildKey('9'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey('4'),
                            _buildKey('5'),
                            _buildKey('6'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey('1'),
                            _buildKey('2'),
                            _buildKey('3'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              ref.watch(appFormatterProvider).decimalSeparator,
                            ),
                            _buildKey('0'),
                            _buildKey(
                              'DEL',
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              '/',
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              '*',
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              '-',
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              '+',
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKey(
                              '=',
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: AppButton.primary(
              label: AppLocalizations.of(context)!.ok,
              onPressed: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
