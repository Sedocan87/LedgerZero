import 'package:flutter/widgets.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Localised, user-facing text for an error. Never includes exception
/// details (those go to the log).
class ErrorMessageMapper {
  static String mapType(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context)!;

    if (error is ServerException) {
      return l10n.serverError;
    } else if (error is CacheException) {
      return l10n.cacheError;
    } else if (error is DatabaseException) {
      return l10n.databaseError;
    } else if (error is SyncException) {
      return l10n.syncError;
    } else {
      return l10n.errorOccurred;
    }
  }
}
