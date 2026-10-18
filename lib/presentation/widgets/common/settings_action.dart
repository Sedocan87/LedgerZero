import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// The app bar button that opens Settings, the same on every tab.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('appbar.settings'),
      icon: const Icon(Icons.settings),
      tooltip: AppLocalizations.of(context)!.settings,
      onPressed: () => context.push('/settings'),
    );
  }
}
