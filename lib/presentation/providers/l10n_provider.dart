import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

/// Resolves the app language: the one chosen in Settings, else the first
/// supported device locale, else English.
Locale resolveAppLocale(Locale? chosen, [List<Locale>? deviceLocales]) {
  return basicLocaleListResolution([
    ?chosen,
    ...(deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales),
  ], AppLocalizations.supportedLocales);
}

/// The active app locale (Settings, else the device locale).
final appLocaleProvider = Provider<Locale>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.language));
  return resolveAppLocale(chosen);
});

/// Localised strings for code outside the widget tree (providers, services,
/// notifications, exports). Rebuilt when the language setting changes.
///
/// Widgets use `AppLocalizations.of(context)` instead.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  return lookupAppLocalizations(ref.watch(appLocaleProvider));
});
