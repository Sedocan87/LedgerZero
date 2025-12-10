import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/tutorial_provider.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_overlay.dart';

class TutorialController {
  final WidgetRef ref;

  TutorialController(this.ref);

  void showTutorial({
    required BuildContext context,
    required String tutorialId,
    required List<TutorialStep> steps,
  }) {
    // Check if tutorial is already completed
    final completed = ref.read(tutorialProvider).contains(tutorialId);
    if (completed) {
      return;
    }

    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) => TutorialOverlay(
        steps: steps,
        onComplete: () {
          ref.read(tutorialProvider.notifier).completeTutorial(tutorialId);
          entry?.remove();
        },
        onSkip: () {
          ref.read(tutorialProvider.notifier).completeTutorial(tutorialId);
          entry?.remove();
        },
      ),
    );

    Overlay.of(context).insert(entry);
  }
}
