import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

final tbbKey = GlobalKey();
final monthSelectorKey = GlobalKey();
final categoryListKey = GlobalKey();

class BudgetTutorialManager {
  static void showTutorial(BuildContext context, WidgetRef ref) {
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'budget_screen_intro',
      steps: [
        TutorialStep(
          title: 'Welcome to your Budget',
          description: 'This is where you plan your spending.',
        ),
        TutorialStep(
          title: 'Select Month',
          description:
              'Navigate between months to plan ahead or review past budgets.',
          targetKey: monthSelectorKey,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: 'To Be Budgeted',
          description:
              'This is your available money. Assign it to categories until it reaches zero.',
          targetKey: tbbKey,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: 'Budget Categories',
          description:
              'Tap on a category to assign money. You can also move money between categories.',
          targetKey: categoryListKey,
          position: TutorialPosition.top,
        ),
      ],
    );
  }
}
