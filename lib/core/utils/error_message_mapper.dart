import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';

class ErrorMessageMapper {
  static String map(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context)!;

    if (error is ServerException) {
      return l10n.serverError;
    } else if (error is CacheException) {
      return l10n.cacheError;
    } else if (error is DatabaseException) {
      return '${l10n.databaseError}: ${error.message}';
    } else if (error is SyncException) {
      return '${l10n.syncError}: ${error.message}';
    } else {
      return error.toString();
    }
  }

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
