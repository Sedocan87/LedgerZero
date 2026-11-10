// Since Flutter 3.32 a SnackBar with an action stays on screen until it is
// dismissed (`persist` defaults to true when `action` is set). The app's
// "Undo" messages then cover the floating action buttons and follow the
// user from tab to tab, so every SnackBar that can have an action says
// `persist: false` and leaves after its duration.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every SnackBar with an action auto-dismisses', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final m in RegExp(r'(?<![A-Za-z_])SnackBar\(').allMatches(source)) {
        // The constructor's arguments, up to the matching parenthesis.
        var depth = 1;
        var i = m.end;
        while (i < source.length && depth > 0) {
          final c = source[i];
          if (c == '(') {
            depth++;
          } else if (c == ')') {
            depth--;
          }
          i++;
        }
        final args = source.substring(m.end, i - 1);
        if (RegExp(r'\baction\s*:').hasMatch(args) &&
            !RegExp(r'\bpersist\s*:').hasMatch(args)) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'SnackBar with an action but no persist',
    );
  });
}
