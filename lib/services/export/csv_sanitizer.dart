/// A cell value we produced ourselves (amount, date, flag) that must be
/// written as-is, e.g. `-12.50`, and not treated as user text.
class CsvLiteral {
  final String value;
  const CsvLiteral(this.value);

  @override
  String toString() => value;
}

/// Protects spreadsheet users from formula injection (CSV injection).
///
/// A text cell that starts with `=`, `+`, `-`, `@`, a tab or a carriage
/// return is prefixed with `'`, so Excel, Numbers, LibreOffice and Google
/// Sheets show it as text instead of evaluating it. Numbers and
/// [CsvLiteral] values are left alone, so negative amounts stay numbers.
class CsvSanitizer {
  CsvSanitizer._();

  static const Set<String> _triggers = {'=', '+', '-', '@', '\t', '\r', '\n'};

  static Object? cell(Object? value) {
    if (value is CsvLiteral) {
      return value.value;
    }
    if (value is String && value.isNotEmpty) {
      if (_triggers.contains(value[0])) {
        return "'$value";
      }
      final trimmed = value.trimLeft();
      if (trimmed.isNotEmpty && _triggers.contains(trimmed[0])) {
        return "'$value";
      }
    }
    return value;
  }

  /// Undoes [cell] on import: a leading `'` is removed when the next
  /// character (or first non-whitespace character) is one of the triggers (so
  /// `'-Fees` comes back as `-Fees` while a name that really starts with `'`
  /// is kept).
  static String unquote(String value) {
    if (value.length >= 2 && value[0] == "'") {
      final rest = value.substring(1);
      final trimmed = rest.trimLeft();
      if (_triggers.contains(rest[0]) ||
          (trimmed.isNotEmpty && _triggers.contains(trimmed[0]))) {
        return rest;
      }
    }
    return value;
  }

  static List<Object?> row(List<Object?> row) => [for (final v in row) cell(v)];

  static List<List<Object?>> rows(List<List<Object?>> rows) => [
    for (final r in rows) row(r),
  ];
}
