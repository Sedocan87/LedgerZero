import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpAndSupport)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: Text(l10n.faq),
            subtitle: Text(l10n.faqSubtitle),
            onTap: () {
              context.pushNamed('faq');
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: Text(l10n.userGuide),
            subtitle: Text(l10n.userGuideSubtitle),
            onTap: () {
              context.pushNamed('user-guide');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(l10n.contactSupport),
            subtitle: Text(l10n.contactSupportSubtitle),
            onTap: () async {
              final url = Uri.parse('mailto:support@ledgerzero.app');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
        ],
      ),
    );
  }
}
