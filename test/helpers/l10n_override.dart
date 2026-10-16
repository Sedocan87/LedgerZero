import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';

/// English strings for providers and services that read
/// [appLocalizationsProvider], in containers without SharedPreferences.
final Override englishL10nOverride = appLocalizationsProvider.overrideWithValue(
  lookupAppLocalizations(const Locale('en')),
);
