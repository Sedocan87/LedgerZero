import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';

class AnimatedCountText extends ConsumerWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final NumberFormat? format;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.format,
    this.textAlign,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for test environment safely without dart:io
    final isTest = WidgetsBinding.instance.runtimeType.toString() ==
        'TestWidgetsFlutterBinding';

    // Check reduced motion
    final shouldAnimate = ThemeNotifier.shouldAnimate(context, ref);

    final effectiveDuration = (isTest || !shouldAnimate) ? Duration.zero : duration;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: effectiveDuration,
      builder: (context, val, child) {
        final text =
            format != null ? format!.format(val) : val.toStringAsFixed(2);
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
        );
      },
    );
  }
}
