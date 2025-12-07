import 'package:flutter/material.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

class BudgetCalculator extends StatefulWidget {
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
  State<BudgetCalculator> createState() => _BudgetCalculatorState();
}

class _BudgetCalculatorState extends State<BudgetCalculator> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      widget.onValueChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    if (key == 'C') {
      _controller.clear();
    } else if (key == 'DEL') {
      if (_controller.text.isNotEmpty) {
        _controller.text = _controller.text.substring(0, _controller.text.length - 1);
      }
    } else if (key == '=') {
      try {
        final result = MathEvaluator.evaluate(_controller.text);
        // format result to remove trailing .0 if integer
        String resultStr = result.toString();
        if (resultStr.endsWith('.0')) {
          resultStr = resultStr.substring(0, resultStr.length - 2);
        }
        _controller.text = resultStr;
      } catch (e) {
        // ignore error or show feedback
      }
    } else {
      _controller.text += key;
    }
  }

  Widget _buildKey(String label, {Color? color, Color? textColor, int flex = 1}) {
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
              color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor ?? Theme.of(context).colorScheme.onSurface,
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
          // Display is handled by the input field in the parent,
          // but we might want to show it here if used as a standalone overlay.
          // However, based on the task, this is likely an overlay FOR budget entry.
          // We assume the parent input field is visible or this widget updates it.
          // For now, let's just show the keypad.
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
                            _buildKey('.'),
                            _buildKey('0'),
                            _buildKey('DEL', color: Theme.of(context).colorScheme.errorContainer, textColor: Theme.of(context).colorScheme.onErrorContainer),
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
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildKey('/', color: Theme.of(context).colorScheme.primaryContainer, textColor: Theme.of(context).colorScheme.onPrimaryContainer)])),
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildKey('*', color: Theme.of(context).colorScheme.primaryContainer, textColor: Theme.of(context).colorScheme.onPrimaryContainer)])),
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildKey('-', color: Theme.of(context).colorScheme.primaryContainer, textColor: Theme.of(context).colorScheme.onPrimaryContainer)])),
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildKey('+', color: Theme.of(context).colorScheme.primaryContainer, textColor: Theme.of(context).colorScheme.onPrimaryContainer)])),
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildKey('=', color: Theme.of(context).colorScheme.secondaryContainer, textColor: Theme.of(context).colorScheme.onSecondaryContainer)])),
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
              label: 'OK',
              onPressed: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
