import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Asks "Discard changes?"; returns `true` to discard.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('unsavedChanges.dialog'),
      title: Text(l10n.unsavedChangesTitle),
      content: Text(l10n.unsavedChangesMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('unsavedChanges.discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.discard),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// The unsaved-changes prompt of every edit form: while [dirty], leaving
/// the route (system back, back gesture, the app bar's back or close
/// button) asks first and only leaves on "Discard".
///
/// The form rebuilds the guard whenever [dirty] changes. Its own close
/// button calls `Navigator.maybePop`, so it goes through the guard; after
/// a successful save the form pops directly (`context.pop()`), which the
/// guard never blocks.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
    this.onDiscard,
  });

  final bool dirty;

  /// Runs after the user chose "Discard", before the route is left (e.g.
  /// to remove an autosaved draft).
  final FutureOr<void> Function()? onDiscard;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (!await confirmDiscardChanges(context) || !context.mounted) {
          return;
        }
        await onDiscard?.call();
        if (context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}
