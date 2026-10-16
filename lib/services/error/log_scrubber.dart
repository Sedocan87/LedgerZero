/// Removes personal and financial data from text before it is written to a
/// diagnostic log: SQL statements and their bound parameters, e-mail
/// addresses, map/JSON payloads (sync deltas, rows) and numbers that could be
/// amounts. Stack traces are not passed through here; they contain only code
/// locations.
class LogScrubber {
  LogScrubber._();

  static final RegExp _statement = RegExp(
    r'(Causing statement|statement|parameters|args|arguments|SQL)\s*[:=].*',
    caseSensitive: false,
  );
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+',
  );
  static final RegExp _innermostBraces = RegExp(r'\{[^{}]*\}');
  static final RegExp _innermostBrackets = RegExp(r'\[[^\[\]]*\]');
  static final RegExp _decimal = RegExp(r'[-+]?\d+(?:[.,  \x27]\d+)+');
  static final RegExp _longInteger = RegExp(r'(?<![\w])[-+]?\d{3,}(?![\w])');

  static String scrub(String? input) {
    if (input == null || input.isEmpty) {
      return input ?? '';
    }
    var s = input.replaceAllMapped(
      _statement,
      (m) => '${m.group(1)}: <removed>',
    );
    s = s.replaceAll(_email, '<email>');
    // Collapse nested payloads from the inside out.
    for (var i = 0; i < 8 && _innermostBraces.hasMatch(s); i++) {
      s = s.replaceAll(_innermostBraces, '<data>');
    }
    for (var i = 0; i < 8 && _innermostBrackets.hasMatch(s); i++) {
      s = s.replaceAll(_innermostBrackets, '<list>');
    }
    s = s.replaceAll(_decimal, '<n>');
    s = s.replaceAll(_longInteger, '<n>');
    return s;
  }
}
