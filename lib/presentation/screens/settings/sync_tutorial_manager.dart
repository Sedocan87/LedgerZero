import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

final providerKey = GlobalKey();
final connectKey = GlobalKey();

class SyncTutorialManager {
  static void showTutorial(BuildContext context, WidgetRef ref) {
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'sync_setup_intro',
      steps: [
        TutorialStep(
          title: 'Choose Provider',
          description:
              'Select Google Drive or iCloud to sync your data securely.',
          targetKey: providerKey,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: 'Connect',
          description:
              'Authenticate with your provider to enable synchronization.',
          targetKey: connectKey,
          position: TutorialPosition.top,
        ),
      ],
    );
  }
}
