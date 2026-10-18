import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

/// Resolves the app language: the one chosen in Settings, else the first
/// supported one of the device locales (all of them, in the user's order),
/// else English.
///
/// The single rule for the UI text (`MaterialApp.locale`), the formatter
/// (`appFormatterProvider`) and text produced outside the widget tree
/// (`appLocalizationsProvider`: notifications, exports), so they agree.
Locale resolveAppLocale(Locale? chosen, [List<Locale>? deviceLocales]) {
  final preferred = [
    ?chosen,
    ...(deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales),
  ];
  const supported = AppLocalizations.supportedLocales;
  final hasMatch = preferred.any(
    (l) => supported.any((s) => s.languageCode == l.languageCode),
  );
  if (!hasMatch) {
    // basicLocaleListResolution would fall back to the first supported
    // locale (German); the app's fallback is English.
    return const Locale('en');
  }
  return basicLocaleListResolution(preferred, supported);
}

/// The active app locale (Settings, else the device locales).
final appLocaleProvider = Provider<Locale>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.language));
  return resolveAppLocale(chosen, ref.watch(deviceLocalesProvider));
});

/// Localised strings for code outside the widget tree (providers, services,
/// notifications, exports). Rebuilt when the language setting changes.
///
/// Widgets use `AppLocalizations.of(context)` instead.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  return lookupAppLocalizations(ref.watch(appLocaleProvider));
});
