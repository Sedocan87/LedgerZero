import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ExpansionTile(
            title: Text('How does the envelope budgeting work?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Envelope budgeting involves assigning every dollar you earn to a specific category or "envelope". You only spend what is available in that envelope. If you overspend, you must move money from another envelope to cover it.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('Is my data safe?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Yes. LedgerZero is a local-first application. Your data is stored encrypted on your device and only leaves your device if you enable synchronization to your own cloud storage.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('How do I sync my data?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Go to Settings > Sync Settings to enable synchronization via Google Drive or iCloud. You will need to sign in to your cloud provider.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('Can I use this app offline?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Absolutely. LedgerZero is designed to be fully functional offline. Synchronization will occur automatically when you reconnect to the internet.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('What happens if I lose my password?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'If you set up a Recovery Key, you can use it to reset your password. Otherwise, since we do not store your data on our servers, we cannot recover your data for you.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
