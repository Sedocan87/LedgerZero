/// Guesses the decimal separator (`.` or `,`) of a column of amount texts.
///
/// A cell with both separators settles it: the one that comes last is the
/// decimal separator (`1.234,56` -> `,`). Otherwise a cell with exactly
/// two digits after its only separator (`12,50`) names the decimal
/// separator, and a cell with exactly three digits after its only
/// separator (`1.234`, `€1,234`) names the thousands separator (so the
/// other one is the decimal separator). Votes are counted over all
/// [values]; a tie or no evidence returns [fallback].
String inferDecimalSeparator(Iterable<String> values, {String fallback = '.'}) {
  var dotVotes = 0;
  var commaVotes = 0;
  for (final raw in values) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    final lastDot = digitsOnly.lastIndexOf('.');
    final lastComma = digitsOnly.lastIndexOf(',');
    if (lastDot != -1 && lastComma != -1) {
      // Both present: the later one is the decimal separator.
      if (lastDot > lastComma) {
        dotVotes += 2;
      } else {
        commaVotes += 2;
      }
      continue;
    }
    final separator = lastDot != -1 ? '.' : (lastComma != -1 ? ',' : null);
    if (separator == null) {
      continue;
    }
    final index = lastDot != -1 ? lastDot : lastComma;
    final count = separator.allMatches(digitsOnly).length;
    final trailing = digitsOnly.length - index - 1;
    if (count > 1) {
      // "1.234.567": grouping only, so the other one is the decimal.
      if (separator == '.') {
        commaVotes++;
      } else {
        dotVotes++;
      }
    } else if (trailing == 2 || trailing == 1) {
      if (separator == '.') {
        dotVotes++;
      } else {
        commaVotes++;
      }
    } else if (trailing == 3) {
      if (separator == '.') {
        commaVotes++;
      } else {
        dotVotes++;
      }
    }
  }
  if (dotVotes == commaVotes) {
    return fallback;
  }
  return dotVotes > commaVotes ? '.' : ',';
}
