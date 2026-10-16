import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

/// The widgets the transaction-entry tutorial points at. Owned by the form
/// screen's state (one set per screen instance, so keys are never shared).
class TransactionTutorialKeys {
  final amount = GlobalKey();
  final payee = GlobalKey();
  final category = GlobalKey();
  final save = GlobalKey();
}

class TransactionTutorialManager {
  static void showTutorial(
    BuildContext context,
    WidgetRef ref,
    TransactionTutorialKeys keys,
  ) {
    final l10n = AppLocalizations.of(context)!;
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'transaction_entry_intro',
      steps: [
        TutorialStep(
          title: l10n.tutTxAmountTitle,
          description: l10n.tutTxAmountBody,
          targetKey: keys.amount,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: l10n.tutTxPayeeTitle,
          description: l10n.tutTxPayeeBody,
          targetKey: keys.payee,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: l10n.tutTxCategoryTitle,
          description: l10n.tutTxCategoryBody,
          targetKey: keys.category,
          position: TutorialPosition.top,
        ),
        TutorialStep(
          title: l10n.tutTxSaveTitle,
          description: l10n.tutTxSaveBody,
          targetKey: keys.save,
          position: TutorialPosition.left,
        ),
      ],
    );
  }
}
