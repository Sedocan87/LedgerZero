import 'package:flutter/material.dart';

class HelpTooltip extends StatelessWidget {
  final String message;
  final Widget? child;
  final Color? color;
  final double size;

  const HelpTooltip({
    super.key,
    required this.message,
    this.child,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.onInverseSurface,
      ),
      child: child ?? Icon(
        Icons.help_outline,
        size: size,
        color: color ?? Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
