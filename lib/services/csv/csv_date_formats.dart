import 'package:intl/intl.dart';

/// Date formats the CSV import offers, in the order of the dropdown.
///
/// Two-digit years (`yy`) get intl's century window (`26` -> 2026, `99` ->
/// 1999); the Sparkasse CSV-CAMT and CSV-MT940 exports use `dd.MM.yy`.
const List<String> csvDateFormats = [
  'yyyy-MM-dd',
  'dd.MM.yyyy',
  'dd.MM.yy',
  'dd/MM/yyyy',
  'MM/dd/yyyy',
  'dd/MM/yy',
  'MM/dd/yy',
  'yyyy.MM.dd',
  'yyyy/MM/dd',
  'dd-MM-yyyy',
  'MM-dd-yyyy',
  'yyyy-MM-dd HH:mm:ss',
  'dd.MM.yyyy HH:mm',
];

/// Earliest and latest year an imported date may have. intl's `yyyy`
/// accepts any run of digits, so `18.10.26` parsed as `dd.MM.yyyy` would
/// become the year 26; such dates are rejected instead.
const int csvMinYear = 1900;
const int csvMaxYear = 2100;

/// Strict parsing of one CSV date cell with [format]: the cell must have
/// the shape of the format (a `yy` year has exactly two digits, a `yyyy`
/// year four), parse strictly, and lie within [csvMinYear]..[csvMaxYear].
/// Returns `null` otherwise. The result is a local `DateTime` (callers turn
/// it into a calendar day).
DateTime? parseCsvDate(String value, String format) {
  final text = value.trim();
  if (text.isEmpty || !_shapeOf(format).hasMatch(text)) {
    return null;
  }
  final DateTime parsed;
  try {
    // Numeric patterns need no locale symbols; en_US is always built in.
    parsed = DateFormat(format, 'en_US').parseStrict(text);
  } on FormatException {
    return null;
  }
  if (parsed.year < csvMinYear || parsed.year > csvMaxYear) {
    return null;
  }
  return parsed;
}

/// Whether [format] writes the day before the month (German and most
/// European files) rather than month first (US files).
bool isDayFirstFormat(String format) {
  final day = format.indexOf('d');
  final month = format.indexOf('M');
  return day != -1 && month != -1 && day < month;
}

bool _isMonthFirstFormat(String format) {
  final day = format.indexOf('d');
  final month = format.indexOf('M');
  return day != -1 && month != -1 && month < day;
}

final Map<String, RegExp> _shapes = {};

/// A regular expression for the digit layout of [format]: `d`/`M`/`H`/`m`/
/// `s` runs become one or two digits, `yyyy` exactly four, `yy` exactly
/// two; everything else is literal.
RegExp _shapeOf(String format) => _shapes.putIfAbsent(format, () {
  final buffer = StringBuffer('^');
  var i = 0;
  while (i < format.length) {
    final c = format[i];
    var run = 1;
    while (i + run < format.length && format[i + run] == c) {
      run++;
    }
    switch (c) {
      case 'y':
        buffer.write(run >= 4 ? r'\d{4}' : r'\d{2}');
      case 'd' || 'M' || 'H' || 'm' || 's':
        buffer.write(r'\d{1,2}');
      default:
        buffer.write(RegExp.escape(format.substring(i, i + run)));
    }
    i += run;
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
});

/// The outcome of [detectCsvDateFormat].
class CsvDateDetection {
  /// The format to use.
  final String format;

  /// Every non-empty value parses with [format].
  final bool fitsAll;

  /// More than one format parses every value (for instance both
  /// `dd/MM/yyyy` and `MM/dd/yyyy` when no day is above 12). [format] is
  /// then the one matching the preferred day/month order; [candidates]
  /// lists all of them.
  final bool ambiguous;

  /// All formats that parse every value (empty when none does).
  final List<String> candidates;

  const CsvDateDetection({
    required this.format,
    required this.fitsAll,
    required this.ambiguous,
    required this.candidates,
  });

  /// The other candidate when [ambiguous] (the first that differs from
  /// [format]), else `null`.
  String? get alternative => candidates.where((c) => c != format).firstOrNull;
}

/// Chooses the date format of a whole column.
///
/// Every format of [csvDateFormats] is scored over all non-empty [values]
/// with [parseCsvDate]. A format that fits every value wins; when several
/// do, the one matching [preferDayFirst] (day before month, as in German
/// files) wins and the result is flagged [CsvDateDetection.ambiguous]. When
/// no format fits every value, the one fitting most values is returned
/// with [CsvDateDetection.fitsAll] false. Without any value the first
/// format of [csvDateFormats] is returned.
CsvDateDetection detectCsvDateFormat(
  Iterable<String> values, {
  bool preferDayFirst = false,
}) {
  final cells = [
    for (final v in values)
      if (v.trim().isNotEmpty) v.trim(),
  ];
  if (cells.isEmpty) {
    return CsvDateDetection(
      format: csvDateFormats.first,
      fitsAll: true,
      ambiguous: false,
      candidates: const [],
    );
  }

  final matches = <String, int>{};
  for (final format in csvDateFormats) {
    var count = 0;
    for (final cell in cells) {
      if (parseCsvDate(cell, format) != null) {
        count++;
      }
    }
    matches[format] = count;
  }

  int preference(String format) {
    if (preferDayFirst
        ? isDayFirstFormat(format)
        : _isMonthFirstFormat(format)) {
      return 0;
    }
    return 1;
  }

  final fitting = [
    for (final format in csvDateFormats)
      if (matches[format] == cells.length) format,
  ];
  if (fitting.isNotEmpty) {
    final ordered = [...fitting]
      ..sort((a, b) {
        final byPreference = preference(a).compareTo(preference(b));
        if (byPreference != 0) {
          return byPreference;
        }
        return csvDateFormats.indexOf(a).compareTo(csvDateFormats.indexOf(b));
      });
    return CsvDateDetection(
      format: ordered.first,
      fitsAll: true,
      ambiguous: fitting.length > 1,
      candidates: fitting,
    );
  }

  var best = csvDateFormats.first;
  for (final format in csvDateFormats) {
    final better =
        matches[format]! > matches[best]! ||
        (matches[format] == matches[best] &&
            preference(format) < preference(best));
    if (better) {
      best = format;
    }
  }
  return CsvDateDetection(
    format: best,
    fitsAll: false,
    ambiguous: false,
    candidates: const [],
  );
}
