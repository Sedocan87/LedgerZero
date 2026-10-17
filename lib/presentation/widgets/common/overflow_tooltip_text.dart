import 'package:flutter/material.dart';

/// [text] in at most [maxLines] lines (one line when its first word is wider
/// than the space) with an ellipsis. Only when it does not fit, tapping it
/// shows the full text in a tooltip, which closes on the next tap anywhere or
/// after [showDuration]. Screen readers always get the full text from the
/// [Text] itself, so the tooltip is excluded from semantics.
class OverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final Duration showDuration;

  const OverflowTooltipText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.showDuration = const Duration(seconds: 5),
  });

  /// Whether a line ending at [offset] splits a word (not after a space,
  /// "/" or "-", where wrapping is natural).
  bool _breaksInsideWord(int offset) {
    if (offset <= 0 || offset >= text.length) {
      return false;
    }
    bool isBreak(String c) => c.trim().isEmpty || c == '/' || c == '-';
    return !isBreak(text[offset - 1]) && !isBreak(text[offset]);
  }

  /// The longest run of whole words from the start of [text] that fits on
  /// one line, or null when the first word alone does not fit.
  String? _fittingWords(TextPainter Function(String) layout) {
    String? fitting;
    for (final match in RegExp(r'\s+').allMatches(text)) {
      final prefix = text.substring(0, match.start);
      final painter = layout(prefix);
      final fits = painter.computeLineMetrics().length == 1;
      painter.dispose();
      if (!fits) {
        break;
      }
      fitting = prefix;
    }
    return fitting;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
        final textDirection = Directionality.of(context);
        final textScaler = MediaQuery.textScalerOf(context);
        TextPainter layout(String value) => TextPainter(
          text: TextSpan(text: value, style: effectiveStyle),
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final painter = layout(text);
        final lineCount = painter.computeLineMetrics().length;
        final firstLineEnd = painter
            .getLineBoundary(const TextPosition(offset: 0))
            .end;
        painter.dispose();

        var shown = text;
        var lines = maxLines;
        if (lineCount > 1 && _breaksInsideWord(firstLineEnd)) {
          // A word too long for a line is split wherever it reaches the
          // edge ("Auto Mainte-nance", "Lebensm-ittel"). Break after the
          // whole words that fit on the first line instead; when not even
          // the first word fits, one line with an ellipsis.
          final words = _fittingWords(layout);
          if (words == null) {
            lines = 1;
          } else {
            shown = '$words\n${text.substring(words.length).trimLeft()}';
          }
        }
        final truncated = lineCount > lines || shown != text;

        final label = Text(
          shown,
          style: style,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: text,
        );
        if (!truncated) {
          return label;
        }
        return Tooltip(
          message: text,
          triggerMode: TooltipTriggerMode.tap,
          showDuration: showDuration,
          excludeFromSemantics: true,
          child: label,
        );
      },
    );
  }
}
