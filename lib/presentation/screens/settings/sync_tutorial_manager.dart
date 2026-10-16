import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

/// The widgets the sync tutorial points at. Owned by the sync settings
/// screen's state (one set per screen instance).
class SyncTutorialKeys {
  final provider = GlobalKey();
  final connect = GlobalKey();
}

class SyncTutorialManager {
  static void showTutorial(
    BuildContext context,
    WidgetRef ref,
    SyncTutorialKeys keys,
  ) {
    final l10n = AppLocalizations.of(context)!;
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'sync_setup_intro',
      steps: [
        TutorialStep(
          title: l10n.tutSyncProviderTitle,
          description: l10n.tutSyncProviderBody,
          targetKey: keys.provider,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: l10n.tutSyncConnectTitle,
          description: l10n.tutSyncConnectBody,
          targetKey: keys.connect,
          position: TutorialPosition.top,
        ),
      ],
    );
  }
}
