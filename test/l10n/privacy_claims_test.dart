import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The texts must say what is true: the database on the phone is not
/// encrypted by the app (backups and sync files are), there is no master
/// password or recovery key any more, and with Android backup on an
/// end-to-end encrypted copy of the budget is in the user's Google account,
/// so no text may claim that the data is only on the phone or never leaves
/// it (docs/SECURITY.md).
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
      r'master password|recovery key|unlock one last time|'
      // Android backup (when on) keeps a copy in the Google account.
      r'only on (this|your) (phone|device)|stored only|exists? only on|'
      r'(nothing|never) (ever )?leaves|never leave|no cloud|without any cloud|'
      // Google sign-in and Drive sync are gone.
      r'Google Drive (sync|account)|sign in to Google|Google account you',
      caseSensitive: false,
    ),
    'app_de.arb': RegExp(
      r'verschlüsselte[n]? Datenbank|Datenbank (ist )?verschlüsselt|'
      r'auf Ihrem Gerät .*verschlüsselt|verschlüsselt auf Ihrem|AES-256|'
      r'SQLCipher|verschlüsselt mit einem Schlüssel|Schlüssel der App|'
      r'Master-?Passwort|Wiederherstellungsschlüssel|'
      r'ein letztes Mal entsperren|'
      r'(liegen|liegt|gespeichert) nur auf|^nur auf (diesem|Ihrem)|'
      r'nur auf (diesem|Ihrem) (Telefon|Gerät) gespeichert|gibt es nur auf|'
      r'verlässt nie|nie(mals)? (das|dieses|Ihr) (Telefon|Gerät)|'
      r'keine Cloud|ohne Cloud|Google-Drive-Konto|bei Google anmelden',
      caseSensitive: false,
    ),
  };

  for (final entry in claims.entries) {
    test('${entry.key} claims no encrypted database, master password, '
        'recovery key, phone-only data or Google Drive', () {
      final offending = {
        for (final m in messages(entry.key).entries)
          if (entry.value.hasMatch(m.value)) m.key: m.value,
      };
      expect(offending, isEmpty);
    });
  }

  test('both languages say that a lost phone loses the budget without '
      'Android backup, a backup elsewhere or a second phone', () {
    final en = messages('app_en.arb')['dataLossWarning']!;
    final de = messages('app_de.arb')['dataLossWarning']!;
    expect(en, allOf(contains('lost'), contains('Android backup')));
    expect(de, allOf(contains('verloren'), contains('Android-Sicherung')));
  });

  test('where the texts mention Android backup, they say it is end-to-end '
      'encrypted', () {
    for (final (file, name, e2e) in [
      ('app_en.arb', 'Android backup', 'end-to-end encrypted'),
      ('app_de.arb', 'Android-Sicherung', 'Ende-zu-Ende-verschlüsselt'),
    ]) {
      for (final key in [
        'setupDeviceExplanation',
        'faqSafeA',
        'securityDataLocationBody',
        'androidBackupExplanation',
      ]) {
        final text = messages(file)[key]!;
        expect(text, contains(name), reason: '$file $key');
        expect(text, contains(e2e), reason: '$file $key');
      }
    }
  });
}
