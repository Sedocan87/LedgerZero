import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(AppLocalizations.of(context)!.payees),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/payees'),
          ),
          // Placeholder for other settings
        ],
      ),
    );
  }
}
