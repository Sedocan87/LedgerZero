import 'dart:convert';

import 'package:flutter/services.dart';

/// The legal pages bundled with the app (assets/legal/, English and
/// German). The same files make the web pages for the Play listing
/// (tool/legal/build_pages.py).
enum LegalDocument { privacy, terms, imprint }

/// Who publishes the app (assets/legal/publisher.json).
class Publisher {
  const Publisher({
    this.name = '',
    this.address = const [],
    this.email = '',
    this.phone = '',
    this.vatId = '',
    this.effectiveDate = '',
  });

  factory Publisher.fromJson(Map<String, Object?> json) => Publisher(
    name: (json['name'] as String? ?? '').trim(),
    address: [
      for (final line in json['address'] as List<Object?>? ?? const [])
        if ((line as String).trim().isNotEmpty) line.trim(),
    ],
    email: (json['email'] as String? ?? '').trim(),
    phone: (json['phone'] as String? ?? '').trim(),
    vatId: (json['vatId'] as String? ?? '').trim(),
    effectiveDate: (json['effectiveDate'] as String? ?? '').trim(),
  );

  final String name;
  final List<String> address;
  final String email;
  final String phone;
  final String vatId;
  final String effectiveDate;

  /// Name, address and email are there: the legal pages are complete (a
  /// release is refused otherwise, see tool/release.sh).
  bool get isComplete =>
      name.isNotEmpty && address.isNotEmpty && email.isNotEmpty;
}

/// Loads and fills in the bundled legal texts.
class LegalTexts {
  const LegalTexts([this._bundle]);

  final AssetBundle? _bundle;

  static const String publisherAsset = 'assets/legal/publisher.json';

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<Publisher> publisher() async => Publisher.fromJson(
    jsonDecode(await _assets.loadString(publisherAsset, cache: false))
        as Map<String, Object?>,
  );

  /// The text of [document] in [languageCode] (German for "de", English
  /// otherwise), with the publisher's details filled in.
  Future<String> load(LegalDocument document, String languageCode) async {
    final language = languageCode == 'de' ? 'de' : 'en';
    // Not cached: opened rarely, and always the bundled file.
    final text = await _assets.loadString(
      'assets/legal/${document.name}_$language.md',
      cache: false,
    );
    return fill(text, await publisher(), language);
  }

  /// Replaces the `{{…}}` fields of [text]. A field without a value shows
  /// a visible placeholder.
  static String fill(String text, Publisher p, String language) {
    final de = language == 'de';
    final missing = de ? '[wird ergänzt]' : '[to be added]';
    String or(String value) => value.isEmpty ? missing : value;
    final block = [
      or(p.name),
      if (p.address.isEmpty) missing else ...p.address,
      '${de ? 'E-Mail' : 'Email'}: ${or(p.email)}',
      if (p.phone.isNotEmpty) '${de ? 'Telefon' : 'Phone'}: ${p.phone}',
      if (p.vatId.isNotEmpty) '${de ? 'USt-IdNr.' : 'VAT ID'}: ${p.vatId}',
    ];
    final fields = {
      'name': or(p.name),
      'email': or(p.email),
      'effectiveDate': or(p.effectiveDate),
      // One line per entry; the renderer keeps the line breaks of a block.
      'publisherBlock': block.join('\n'),
    };
    return text.replaceAllMapped(
      RegExp(r'\{\{(\w+)\}\}'),
      (m) => fields[m.group(1)] ?? m.group(0)!,
    );
  }
}

/// A block of a legal text: the small Markdown subset the files use.
sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.text, {required this.level});
  final String text;

  /// 1 for "# ", 2 for "## ".
  final int level;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);

  /// May contain line breaks (an address) and `**bold**`.
  final String text;
}

class LegalBullet extends LegalBlock {
  const LegalBullet(this.text);
  final String text;
}

/// Splits [text] into headings ("# ", "## "), bullets ("- ") and paragraphs
/// (lines separated by an empty line; the lines of one paragraph keep their
/// line breaks).
List<LegalBlock> parseLegalText(String text) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isNotEmpty) {
      blocks.add(LegalParagraph(paragraph.join('\n')));
      paragraph.clear();
    }
  }

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(LegalHeading(line.substring(3).trim(), level: 2));
    } else if (line.startsWith('# ')) {
      flush();
      blocks.add(LegalHeading(line.substring(2).trim(), level: 1));
    } else if (line.startsWith('- ')) {
      flush();
      blocks.add(LegalBullet(line.substring(2).trim()));
    } else {
      paragraph.add(line.trim());
    }
  }
  flush();
  return blocks;
}
