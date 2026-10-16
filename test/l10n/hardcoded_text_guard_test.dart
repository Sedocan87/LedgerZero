import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against new hard-coded user-visible text in lib/presentation:
/// `Text('literal')` and literal strings in the usual text parameters
/// (hintText, labelText, tooltip, semanticLabel, ...). User-visible text
/// belongs in lib/l10n/app_en.arb + app_de.arb.
void main() {
  /// Literals that are the same in every language (brand, file names).
  const allowed = {'LedgerZero', 'Register.csv', 'Budget.csv'};

  final textCall = RegExp(
    r'''\b(?:Text|SelectableText|Tooltip|Tab)\(\s*(?:const\s+)?(?:message:\s*|text:\s*)?r?(['"])((?:\\.|(?!\1).)*)\1''',
  );
  final textParam = RegExp(
    r'''\b(?:hintText|labelText|helperText|errorText|counterText|prefixText|suffixText|tooltip|semanticLabel|semanticsLabel|label|title|subtitle|content|message|confirmText|cancelText)\s*:\s*(?:const\s+)?(?:Text\(\s*)?r?(['"])((?:\\.|(?!\1).)*)\1''',
  );

  bool isUserText(String literal) {
    // Interpolations are not text; an interpolation with nested quotes
    // ends the match early, so drop an unterminated `${` to the end.
    final words = literal
        .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '')
        .replaceAll(RegExp(r'\$\{.*$'), '');
    return RegExp('[A-Za-zÄÖÜäöüß]{2,}').hasMatch(words) &&
        !allowed.contains(literal);
  }

  test('no hard-coded user-visible strings in lib/presentation', () {
    final hits = <String>[];
    final files = Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      // Join the file so literals on the line after `Text(` are found too;
      // drop comment lines first.
      final source = [
        for (final line in lines) line.trimLeft().startsWith('//') ? '' : line,
      ].join('\n');
      for (final pattern in [textCall, textParam]) {
        for (final match in pattern.allMatches(source)) {
          final literal = match.group(2)!;
          if (!isUserText(literal)) {
            continue;
          }
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          hits.add('${file.path}:${line + 1}: $literal');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'Move these strings to lib/l10n/app_en.arb and app_de.arb '
          '(or add a language-neutral literal to the allow-list).',
    );
  });
}
