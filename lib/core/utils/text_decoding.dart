import 'dart:convert';

/// Decodes text files picked by the user (bank CSV exports and similar).
///
/// A UTF-8 byte order mark is removed. Bytes that are not valid UTF-8 are
/// decoded as Windows-1252 (the "ANSI" code page of Western European
/// Windows, which bank exports use), so `0x80` becomes the euro sign `€`
/// instead of a C1 control character as plain Latin-1 would give.
String decodeText(List<int> bytes, {bool windows1252Fallback = false}) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final body = start == 0 ? bytes : bytes.sublist(start);
  try {
    final text = utf8.decode(body);
    // A BOM can also survive as U+FEFF when the bytes came pre-decoded.
    return text.startsWith('﻿') ? text.substring(1) : text;
  } on FormatException {
    if (!windows1252Fallback) {
      rethrow;
    }
    return decodeWindows1252(body);
  }
}

/// Decodes [bytes] as Windows-1252. Bytes `0x80`-`0x9F` use the code page's
/// table; the five bytes the code page leaves undefined map to the C1
/// control character of the same value (as browsers do). Every other byte
/// is identical to Latin-1.
String decodeWindows1252(List<int> bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    if (b >= 0x80 && b <= 0x9F) {
      buffer.writeCharCode(_cp1252High[b - 0x80]);
    } else {
      buffer.writeCharCode(b & 0xFF);
    }
  }
  return buffer.toString();
}

/// Unicode code points of Windows-1252 bytes 0x80..0x9F.
const List<int> _cp1252High = [
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, // 80-87
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, // 88-8F
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 90-97
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178, // 98-9F
];
