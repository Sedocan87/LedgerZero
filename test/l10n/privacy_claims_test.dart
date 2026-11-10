import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The texts must say what is true: the database on the phone is not
/// encrypted by the app (backups and sync files are), and there is no
/// master password or recovery key any more (docs/SECURITY.md).
void main() {
  Map<String, String> messages(String name) {
    final arb =
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };
  }

  final claims = {
    'app_en.arb': RegExp(
      r'encrypted database|database is encrypted|data is encrypted on|'
      r'encrypted on your device|stored encrypted|AES-256|SQLCipher|'
      r'device and encrypted|encrypted with a key|app.s key|'
      r'master password|recovery key|unlock one last time',
      caseSensitive: false,
    ),
    'app_de.arb': RegExp(
      r'verschlüsselte[n]? Datenbank|Datenbank (ist )?verschlüsselt|'
      r'auf Ihrem Gerät .*verschlüsselt|verschlüsselt auf Ihrem|AES-256|'
      r'SQLCipher|verschlüsselt mit einem Schlüssel|Schlüssel der App|'
      r'Master-?Passwort|Wiederherstellungsschlüssel|'
      r'ein letztes Mal entsperren',
      caseSensitive: false,
    ),
  };

  for (final entry in claims.entries) {
    test('${entry.key} claims no encrypted database, master password or '
        'recovery key', () {
      final offending = {
        for (final m in messages(entry.key).entries)
          if (entry.value.hasMatch(m.value)) m.key: m.value,
      };
      expect(offending, isEmpty);
    });
  }

  test('both languages say that a lost phone loses the budget without a '
      'backup elsewhere or a second phone', () {
    expect(messages('app_en.arb')['dataLossWarning'], contains('lost'));
    expect(messages('app_de.arb')['dataLossWarning'], contains('verloren'));
  });
}
