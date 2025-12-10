class StackTraceFormatter {
  static String format(StackTrace? stackTrace) {
    if (stackTrace == null) {
      return '';
    }

    final lines = stackTrace.toString().split('\n');
    final formattedLines = <String>[];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }

      // Filter out noise if needed, or just format
      // For now, let's keep it simple but extensible.
      // We can remove lines from 'package:flutter' internals if we want to focus on our code,
      // but often those are useful.
      // Let's at least indent them cleanly.

      formattedLines.add(line);
    }

    return formattedLines.join('\n');
  }

  static String formatWithContext(Object error, StackTrace? stackTrace) {
    return 'Error: $error\nStack Trace:\n${format(stackTrace)}';
  }
}
