import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedCountText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Check for test environment safely without dart:io
    final isTest = WidgetsBinding.instance.runtimeType.toString() ==
        'TestWidgetsFlutterBinding';
    final effectiveDuration = isTest ? Duration.zero : duration;

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
