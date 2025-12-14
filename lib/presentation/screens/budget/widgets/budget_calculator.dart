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
      // If text is "0" or "0.00" and input is a number (not operator or dot handling which might differ),
      // we usually want to replace it.
      // Ops are handled above or passed as key?
      // Keys passed here: '0'-'9', '.', '+', '-', '*', '/'.
      // Oh wait, _buildKey calls this with label.
      // Labels: '7', '8', '9', '/', '4', '5', '6', '*', '1', '2', '3', '-', '.', '0', 'DEL'.
      // So operators ARE passed here.

      // Check if key is operator
      if (['+', '-', '*', '/'].contains(key)) {
        _controller.text += key;
        return;
      }

      // Check for decimal
      if (key == '.') {
        if (_controller.text.isEmpty) {
          _controller.text = '0.';
        } else if (!_controller.text.contains('.')) {
          // Allow dot if no dot yet?
          // Logic: if we have "0.00", typing "." might be weird.
          // If we treat "0.00" as initial value to be wiped, then typing "." should probably make it "0."?
          if (_controller.text == '0.00' || _controller.text == '0') {
            _controller.text = '0.';
          } else {
            _controller.text += key;
          }
        }
        return;
      }

      // Digits 0-9
      if (_controller.text == '0' || _controller.text == '0.00') {
        _controller.text = key;
      } else {
        _controller.text += key;
      }
    }
  }

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
                            _buildKey('.'),
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
              label: 'OK',
              onPressed: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
