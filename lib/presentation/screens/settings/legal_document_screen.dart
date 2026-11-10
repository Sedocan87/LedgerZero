import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/services/legal/legal_documents.dart';

final legalTextsProvider = Provider<LegalTexts>((ref) => const LegalTexts());

/// The publisher's details (for whether the imprint is shown).
final publisherProvider = FutureProvider<Publisher>(
  (ref) => ref.watch(legalTextsProvider).publisher(),
);

/// A legal text in a language ("de" or "en").
final legalTextProvider =
    FutureProvider.family<String, (LegalDocument, String)>(
      (ref, key) => ref.watch(legalTextsProvider).load(key.$1, key.$2),
    );

/// The privacy policy, the terms of use or the imprint, bundled with the
/// app (they work offline), in the app's language.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen(this.document, {super.key});

  final LegalDocument document;

  static String titleOf(LegalDocument document, AppLocalizations l10n) =>
      switch (document) {
        LegalDocument.privacy => l10n.aboutPrivacyPolicy,
        LegalDocument.terms => l10n.legalTermsOfUse,
        LegalDocument.imprint => l10n.aboutImprint,
      };

  /// Opens the page above the bottom navigation.
  static Future<void> show(BuildContext context, LegalDocument document) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(document)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    final text = ref.watch(legalTextProvider((document, language)));
    return Scaffold(
      appBar: AppBar(title: Text(titleOf(document, l10n))),
      body: text.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.legalLoadFailed, textAlign: TextAlign.center),
          ),
        ),
        data: (text) => SelectionArea(
          child: ListView(
            key: Key('legal.${document.name}'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final block in parseLegalText(text))
                // The page title is the app bar's.
                if (!(block is LegalHeading && block.level == 1)) _Block(block),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    return switch (block) {
      LegalHeading(:final text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      LegalParagraph(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(_inline(text, body), style: body),
      ),
      LegalBullet(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: body),
            Expanded(child: Text.rich(_inline(text, body), style: body)),
          ],
        ),
      ),
    };
  }

  /// `**bold**` spans.
  static TextSpan _inline(String text, TextStyle? style) {
    final parts = text.split('**');
    return TextSpan(
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
      ],
    );
  }
}
