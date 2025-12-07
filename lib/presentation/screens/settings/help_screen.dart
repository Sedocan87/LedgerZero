import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'), // TODO: l10n
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: const Text('FAQ'),
            subtitle: const Text('Frequently asked questions'),
            onTap: () {
              context.pushNamed('faq');
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('User Guide'),
            subtitle: const Text('Comprehensive documentation'),
            onTap: () {
              context.pushNamed('user-guide');
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Keyboard Shortcuts'),
            subtitle: const Text('List of available shortcuts'),
            onTap: () {
              context.pushNamed('keyboard-shortcuts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video Tutorials'),
            subtitle: const Text('Learn by watching on YouTube'),
            onTap: () async {
               // Placeholder channel URL
               final url = Uri.parse('https://www.youtube.com/channel/UC_placeholder');
               if (await canLaunchUrl(url)) {
                 await launchUrl(url);
               }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contact Support'),
            subtitle: const Text('support@ledgerzero.app'),
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
