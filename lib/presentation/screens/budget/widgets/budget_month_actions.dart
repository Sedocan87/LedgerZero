import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/undo/budget_undo_actions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// Asks whether to replace the budgeted amounts of a month that is not
/// empty. Returns true when the operation may go ahead (the month is empty
/// or the user confirmed).
Future<bool> confirmMonthOverwrite(
  BuildContext context,
  WidgetRef ref, {
  required DateTime month,
  required String message,
}) async {
  if (await ref.read(budgetingServiceProvider).isMonthEmpty(month)) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.budgetOverwriteTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('budget.overwriteConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.budgetOverwriteConfirm),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Runs a month operation, records it on the undo stack and shows
/// [message] with Undo (an undo that fails shows the generic error).
/// Nothing is recorded or shown when the operation changed nothing.
Future<void> runMonthAction(
  BuildContext context,
  WidgetRef ref, {
  required Future<BudgetMonthChange> Function() run,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final budgeting = ref.read(budgetingServiceProvider);
  final undoService = ref.read(undoServiceProvider);
  final BudgetMonthChange change;
  try {
    change = await run();
  } catch (e, stack) {
    Logger.error('Budget month operation failed', e, stack);
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    return;
  }
  if (change.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.budgetNothingChanged)));
    return;
  }
  final action = BudgetMonthChangeAction(
    budgetingService: budgeting,
    change: change,
  );
  undoService.addAction(action);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => undoService.undo(action).catchError((
            Object e,
            StackTrace st,
          ) {
            Logger.error('Undoing a month operation failed', e, st);
            messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
          }),
        ),
      ),
    );
}
