import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/legal/legal_documents.dart';

String _asset(String name) => File('assets/legal/$name').readAsStringSync();

void main() {
  const complete = Publisher(
    name: 'Erika Mustermann',
    address: ['Musterstraße 1', '12345 Musterstadt', 'Deutschland'],
    email: 'support@ledgerzero.app',
    phone: '+49 30 1234567',
    vatId: 'DE123456789',
    effectiveDate: '2026-11-10',
  );

  test('every page exists in English and German, and every field in it '
      'is filled in', () {
    for (final document in LegalDocument.values) {
      for (final language in ['en', 'de']) {
        final text = LegalTexts.fill(
          _asset('${document.name}_$language.md'),
          complete,
          language,
        );
        expect(text, isNot(contains('{{')), reason: '$document $language');
        expect(text, contains('Erika Mustermann'));
        expect(text, isNot(contains('[to be added]')));
        expect(text, isNot(contains('[wird ergänzt]')));
      }
    }
  });

  test('the publisher block lists name, address, contact and VAT ID on '
      'their own lines, labelled in the page language', () {
    final de = LegalTexts.fill('{{publisherBlock}}', complete, 'de');
    expect(de.split('\n'), [
      'Erika Mustermann',
      'Musterstraße 1',
      '12345 Musterstadt',
      'Deutschland',
      'E-Mail: support@ledgerzero.app',
      'Telefon: +49 30 1234567',
      'USt-IdNr.: DE123456789',
    ]);
    final en = LegalTexts.fill('{{publisherBlock}}', complete, 'en');
    expect(en, contains('Email: support@ledgerzero.app'));
    expect(en, contains('VAT ID: DE123456789'));
  });

  test('missing details show a visible placeholder', () {
    const empty = Publisher(email: 'support@ledgerzero.app');
    expect(empty.isComplete, isFalse);
    expect(
      LegalTexts.fill('{{name}} / {{email}}', empty, 'en'),
      '[to be added] / support@ledgerzero.app',
    );
    expect(LegalTexts.fill('{{name}}', empty, 'de'), '[wird ergänzt]');
    expect(complete.isComplete, isTrue);
  });

  test('the shipped publisher file parses (fill it in before a release)', () {
    final json = jsonDecode(_asset('publisher.json')) as Map<String, Object?>;
    final publisher = Publisher.fromJson(json);
    expect(publisher.email, isNotEmpty);
    expect(publisher.effectiveDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('the Markdown subset: headings, paragraphs with their line breaks, '
      'bullets', () {
    final blocks = parseLegalText(
      '# Title\n\nIntro line one\nline two\n\n## Section\n\n- **A.** one\n- two\n\nEnd.',
    );
    expect(blocks, hasLength(6));
    expect((blocks[0] as LegalHeading).level, 1);
    expect((blocks[1] as LegalParagraph).text, 'Intro line one\nline two');
    expect((blocks[2] as LegalHeading).text, 'Section');
    expect((blocks[3] as LegalBullet).text, '**A.** one');
    expect((blocks[4] as LegalBullet).text, 'two');
    expect((blocks[5] as LegalParagraph).text, 'End.');
  });
}
