import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_data.dart';

final amountKey = GlobalKey();
final payeeKey = GlobalKey();
final categoryKey = GlobalKey();
final saveKey = GlobalKey();

class TransactionTutorialManager {
  static void showTutorial(BuildContext context, WidgetRef ref) {
    TutorialController(ref).showTutorial(
      context: context,
      tutorialId: 'transaction_entry_intro',
      steps: [
        TutorialStep(
          title: 'Enter Amount',
          description: 'Start by entering the transaction amount.',
          targetKey: amountKey,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: 'Select Payee',
          description: 'Choose who you paid or who paid you. New payees are saved automatically.',
          targetKey: payeeKey,
          position: TutorialPosition.bottom,
        ),
        TutorialStep(
          title: 'Assign Category',
          description: 'Categorize this transaction to update your budget.',
          targetKey: categoryKey,
          position: TutorialPosition.top,
        ),
        TutorialStep(
          title: 'Save',
          description: 'Tap here to save. You can also "Save & Add Another" below.',
          targetKey: saveKey,
          position: TutorialPosition.left,
        ),
      ],
    );
  }
}
