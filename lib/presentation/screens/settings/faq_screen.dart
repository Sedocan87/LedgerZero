import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = [
      (l10n.faqBudgetingQ, l10n.faqBudgetingA),
      (l10n.faqSafeQ, l10n.faqSafeA),
      (l10n.faqSavingQ, l10n.faqSavingA),
      (l10n.faqSyncQ, l10n.faqSyncA),
      (l10n.faqPersonalQ, l10n.faqPersonalA),
      (l10n.faqOfflineQ, l10n.faqOfflineA),
      (l10n.faqLockQ, l10n.faqLockA),
      (l10n.faqBackupQ, l10n.faqBackupA),
      (l10n.faqImportQ, l10n.faqImportA),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.faq)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (question, answer) in entries)
            ExpansionTile(
              title: Text(question),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(answer),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
