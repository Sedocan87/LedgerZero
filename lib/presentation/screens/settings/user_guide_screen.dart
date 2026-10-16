import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (l10n.guideStartTitle, l10n.guideStartBody),
      (l10n.guideAccountsTitle, l10n.guideAccountsBody),
      (l10n.guideBudgetTitle, l10n.guideBudgetBody),
      (l10n.guideTransactionsTitle, l10n.guideTransactionsBody),
      (l10n.guideOverspendingTitle, l10n.guideOverspendingBody),
      (l10n.guideReconcileTitle, l10n.guideReconcileBody),
      (l10n.guideSyncTitle, l10n.guideSyncBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.userGuide)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, content) in sections)
            UserGuideSection(title: title, content: content),
        ],
      ),
    );
  }
}

class UserGuideSection extends StatelessWidget {
  final String title;
  final String content;

  const UserGuideSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
