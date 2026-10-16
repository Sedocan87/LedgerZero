import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The German ARB must translate every English message, with the same
/// placeholders, and `flutter gen-l10n` must report nothing untranslated.
void main() {
  Map<String, dynamic> readArb(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  final en = readArb('app_en.arb');
  final de = readArb('app_de.arb');
  final messageKeys = en.keys.where((k) => !k.startsWith('@')).toList();

  /// Top-level placeholder names of an ICU message (`{name}` and the
  /// selector of `{count, plural, ...}`), ignoring plural-case text.
  Set<String> placeholders(String message) {
    final names = <String>{};
    var depth = 0;
    for (var i = 0; i < message.length; i++) {
      final c = message[i];
      if (c == '{') {
        depth++;
        final match = RegExp(r'\{\s*(\w+)\s*[,}]').matchAsPrefix(message, i);
        // Only even depths are argument positions; odd ones are the
        // text of plural/select cases.
        if (match != null && depth.isOdd) {
          names.add(match.group(1)!);
        }
      } else if (c == '}') {
        depth--;
      }
    }
    return names;
  }

  test('untranslated_messages.json is empty', () {
    final file = File('untranslated_messages.json');
    if (!file.existsSync()) {
      return; // gen-l10n writes it only when configured; nothing to check.
    }
    final untranslated = jsonDecode(file.readAsStringSync()) as Map;
    expect(
      untranslated,
      isEmpty,
      reason:
          'Translate these keys in lib/l10n/app_de.arb and run '
          '`flutter gen-l10n`.',
    );
  });

  test('German ARB has every English key, non-empty', () {
    final missing = [
      for (final key in messageKeys)
        if (de[key] is! String || (de[key] as String).trim().isEmpty) key,
    ];
    expect(missing, isEmpty, reason: 'Missing in app_de.arb');
  });

  test('German ARB has no keys the English template lacks', () {
    final extra = [
      for (final key in de.keys)
        if (!key.startsWith('@') && !en.containsKey(key)) key,
    ];
    expect(extra, isEmpty, reason: 'Stale keys in app_de.arb');
  });

  test('German messages use the same placeholders as English', () {
    final mismatched = <String>[];
    for (final key in messageKeys) {
      final german = de[key];
      if (german is! String) {
        continue;
      }
      if (!setEquals(placeholders(en[key] as String), placeholders(german))) {
        mismatched.add(key);
      }
    }
    expect(mismatched, isEmpty);
  });

  test('every placeholder is declared with a type', () {
    final untyped = <String>[];
    for (final key in messageKeys) {
      final names = placeholders(en[key] as String);
      if (names.isEmpty) {
        continue;
      }
      final declared =
          ((en['@$key'] as Map?)?['placeholders'] as Map?) ?? const {};
      for (final name in names) {
        final meta = declared[name];
        if (meta is! Map || meta['type'] == null) {
          untyped.add('$key.$name');
        }
      }
    }
    expect(untyped, isEmpty);
  });
}

bool setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
