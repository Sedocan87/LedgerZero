import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

/// Formats and parses amounts and dates according to the user's settings
/// (currency, language, number format, date format, first day of week).
///
/// Amounts are minor units (`int`). Calendar dates are stored as UTC
/// midnight and are formatted by their own fields; timestamps are shown in
/// local time.
class AppFormatter {
  /// Language used for patterns and month names (`en` / `de`).
  final String locale;

  /// Default currency from Settings.
  final String currency;

  final AppDateFormat dateFormat;
  final AppFirstDayOfWeek firstDayOfWeekSetting;

  /// Formatter for amounts.
  final MoneyFormatter money;

  AppFormatter({
    required this.locale,
    required this.currency,
    required String decimalSeparator,
    this.dateFormat = AppDateFormat.iso8601,
    this.firstDayOfWeekSetting = AppFirstDayOfWeek.sunday,
  }) : money = MoneyFormatter(
         locale: locale,
         defaultCurrency: currency,
         decimalSeparator: decimalSeparator,
       );

  /// Builds a formatter from [settings]. The language is resolved with
  /// [resolveAppLocale] (Settings, else the first supported one of
  /// [deviceLocales], else English), the same way the UI text is.
  factory AppFormatter.fromSettings(
    SettingsState settings, {
    List<Locale> deviceLocales = const [],
  }) {
    final locale = resolveAppLocale(
      settings.language,
      deviceLocales,
    ).languageCode;
    return AppFormatter(
      locale: locale,
      currency: settings.currency,
      decimalSeparator:
          settings.numberFormat.decimalSeparator ??
          decimalSeparatorForLocale(locale),
      dateFormat: settings.dateFormat,
      firstDayOfWeekSetting: settings.firstDayOfWeek,
    );
  }

  /// Languages the app is localised in.
  static const supportedLanguageCodes = ['en', 'de'];

  /// The active decimal separator.
  String get decimalSeparator => money.decimalSeparator;

  /// Parser for amount text fields.
  MoneyParser get parser => money.parser;

  /// `$1,234.50` / `1.234,50 €`. [currencyCode] defaults to the setting.
  String formatMoney(int minor, {String? currencyCode, bool signed = false}) =>
      money.format(minor, currency: currencyCode, signed: signed);

  /// `$1.2K` style, for chart axes.
  String formatMoneyCompact(int minor, {String? currencyCode}) =>
      money.formatCompact(minor, currency: currencyCode);

  /// Number with grouping and no symbol, e.g. `1.234,50`.
  String formatAmountNumber(int minor, {String? currencyCode}) =>
      money.formatNumber(minor, currency: currencyCode);

  /// Plain value for pre-filling text fields ("12,50" / "12.50").
  String formatAmountForInput(int minor) => money.formatForInput(minor);

  /// Parses user input ("12,50", "€12.50", "1.234,56") into minor units;
  /// `null` if empty or invalid.
  int? parseAmount(String? text) => parser.tryParse(text);

  /// Currency symbol, e.g. `€`.
  String currencySymbol([String? currencyCode]) =>
      money.symbolFor(currencyCode);

  /// A calendar day using the date-format setting (e.g. `31.12.2024`).
  String formatDate(DateTime date) => _date(dateFormat.pattern).format(date);

  /// A timestamp (stored in UTC) in local time, e.g. `2024-12-31 18:05`.
  String formatDateTime(DateTime timestamp) =>
      _date('${dateFormat.pattern} HH:mm').format(timestamp.toLocal());

  /// Weekday plus date, e.g. `Tue, 31.12.2024`.
  String formatWeekdayDate(DateTime date) =>
      '${_date('EEE').format(date)}, ${formatDate(date)}';

  /// Month and year, e.g. `December 2024` / `Dezember 2024`.
  String formatMonthYear(DateTime date) => _date('yMMMM').format(date);

  /// Abbreviated month and year, e.g. `Dec 2024`.
  String formatMonthYearShort(DateTime date) => _date('yMMM').format(date);

  /// Abbreviated month, e.g. `Dec`.
  String formatMonthShort(DateTime date) => _date('MMM').format(date);

  /// "November".
  String formatMonthName(DateTime date) => _date('MMMM').format(date);

  /// Day and abbreviated month, e.g. `Dec 31` / `31. Dez.`.
  String formatMonthDay(DateTime date) => _date('MMMd').format(date);

  /// First day of the week as a [DateTime] weekday constant
  /// (`DateTime.monday` ... `DateTime.sunday`).
  int get firstDayOfWeek => firstDayOfWeekSetting.value;

  /// Start of the week containing [day] honouring [firstDayOfWeek]
  /// (calendar day, UTC midnight).
  DateTime startOfWeek(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final offset = (d.weekday - firstDayOfWeek + 7) % 7;
    return DateTime.utc(d.year, d.month, d.day - offset);
  }

  final Map<String, DateFormat> _dateFormats = {};

  DateFormat _date(String pattern) {
    return _dateFormats.putIfAbsent(pattern, () {
      try {
        return _create(pattern, locale);
      } catch (_) {
        // Date symbols are normally loaded by the Flutter localisation
        // delegates. Outside the widget tree (unit tests, background
        // services) load the bundled data; it is available synchronously.
        unawaited(initializeDateFormatting(locale));
        try {
          return _create(pattern, locale);
        } catch (_) {
          return _create(pattern, 'en');
        }
      }
    });
  }

  static DateFormat _create(String pattern, String locale) {
    return switch (pattern) {
      'yMMMM' => DateFormat.yMMMM(locale),
      'yMMM' => DateFormat.yMMM(locale),
      'MMM' => DateFormat.MMM(locale),
      'MMMd' => DateFormat.MMMd(locale),
      'EEE' => DateFormat.E(locale),
      _ => DateFormat(pattern, locale),
    };
  }
}

/// The app-wide formatter for amounts and dates, rebuilt whenever a
/// relevant setting changes. Its language is [appLocaleProvider], so
/// amounts and dates follow the same locale as the UI text.
final appFormatterProvider = Provider<AppFormatter>((ref) {
  final settings = ref.watch(settingsProvider);
  final locale = ref.watch(appLocaleProvider);
  return AppFormatter(
    locale: locale.languageCode,
    currency: settings.currency,
    decimalSeparator:
        settings.numberFormat.decimalSeparator ??
        decimalSeparatorForLocale(locale.languageCode),
    dateFormat: settings.dateFormat,
    firstDayOfWeekSetting: settings.firstDayOfWeek,
  );
});
