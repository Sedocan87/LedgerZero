import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

/// The widgets the budget tutorial points at. Owned by the budget screen's
/// state (one set per screen instance, so keys are never shared).
class BudgetTutorialKeys {
  final tbb = GlobalKey();
  final monthSelector = GlobalKey();
  final categoryList = GlobalKey();
}

class BudgetTutorialManager {
  static void showTutorial(
    BuildContext context,
    WidgetRef ref,
    BudgetTutorialKeys keys,
  ) {
    final l10n = AppLocalizations.of(context)!;
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'budget_screen_intro',
      steps: [
        TutorialStep(
          title: l10n.tutBudgetWelcomeTitle,
          description: l10n.tutBudgetWelcomeBody,
        ),
        TutorialStep(
          title: l10n.tutBudgetMonthTitle,
          description: l10n.tutBudgetMonthBody,
          targetKey: keys.monthSelector,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: l10n.tutBudgetTbbTitle,
          description: l10n.tutBudgetTbbBody,
          targetKey: keys.tbb,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: l10n.tutBudgetCategoriesTitle,
          description: l10n.tutBudgetCategoriesBody,
          targetKey: keys.categoryList,
          position: TutorialPosition.top,
        ),
      ],
    );
  }
}
