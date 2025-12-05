import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

enum AppDateFormat {
  iso8601('yyyy-MM-dd'),
  european('dd.MM.yyyy'),
  us('MM/dd/yyyy');

  final String pattern;
  const AppDateFormat(this.pattern);
}

enum AppNumberFormat {
  dot('.'),
  comma(',');

  final String decimalSeparator;
  const AppNumberFormat(this.decimalSeparator);
}

enum AppFirstDayOfWeek {
  sunday(7),
  monday(1),
  saturday(6);

  final int value;
  const AppFirstDayOfWeek(this.value);
}

/// A generic wrapper to distinguish between "value explicitly passed as null"
/// versus "value not passed at all" in copyWith.
class Wrapped<T> {
  final T value;
  const Wrapped(this.value);
}

class SettingsState {
  final String currency;
  final AppDateFormat dateFormat;
  final AppNumberFormat numberFormat;
  final AppFirstDayOfWeek firstDayOfWeek;
  final Locale? language;
  final String? defaultAccountId;
  final String? defaultCategoryId;

  const SettingsState({
    this.currency = 'USD',
    this.dateFormat = AppDateFormat.iso8601,
    this.numberFormat = AppNumberFormat.dot,
    this.firstDayOfWeek = AppFirstDayOfWeek.sunday,
    this.language,
    this.defaultAccountId,
    this.defaultCategoryId,
  });

  SettingsState copyWith({
    String? currency,
    AppDateFormat? dateFormat,
    AppNumberFormat? numberFormat,
    AppFirstDayOfWeek? firstDayOfWeek,
    Wrapped<Locale?>? language,
    Wrapped<String?>? defaultAccountId,
    Wrapped<String?>? defaultCategoryId,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      numberFormat: numberFormat ?? this.numberFormat,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      language: language != null ? language.value : this.language,
      defaultAccountId: defaultAccountId != null ? defaultAccountId.value : this.defaultAccountId,
      defaultCategoryId: defaultCategoryId != null ? defaultCategoryId.value : this.defaultCategoryId,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _keyCurrency = 'settings_currency';
  static const String _keyDateFormat = 'settings_date_format';
  static const String _keyNumberFormat = 'settings_number_format';
  static const String _keyFirstDayOfWeek = 'settings_first_day_of_week';
  static const String _keyLanguage = 'settings_language';
  static const String _keyDefaultAccount = 'settings_default_account';
  static const String _keyDefaultCategory = 'settings_default_category';

  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _loadState();
  }

  SettingsState _loadState() {
    final currency = _prefs.getString(_keyCurrency) ?? 'USD';
    final dateFormatIdx = _prefs.getInt(_keyDateFormat) ?? 0;
    final numberFormatIdx = _prefs.getInt(_keyNumberFormat) ?? 0;
    final firstDayOfWeekIdx = _prefs.getInt(_keyFirstDayOfWeek) ?? 0;
    final languageCode = _prefs.getString(_keyLanguage);
    final defaultAccountId = _prefs.getString(_keyDefaultAccount);
    final defaultCategoryId = _prefs.getString(_keyDefaultCategory);

    // Map indices to enums safely
    final dateFormat = AppDateFormat.values.elementAtOrNull(dateFormatIdx) ?? AppDateFormat.iso8601;
    final numberFormat = AppNumberFormat.values.elementAtOrNull(numberFormatIdx) ?? AppNumberFormat.dot;
    final firstDayOfWeek = AppFirstDayOfWeek.values.elementAtOrNull(firstDayOfWeekIdx) ?? AppFirstDayOfWeek.sunday;

    final language = languageCode != null ? Locale(languageCode) : null;

    return SettingsState(
      currency: currency,
      dateFormat: dateFormat,
      numberFormat: numberFormat,
      firstDayOfWeek: firstDayOfWeek,
      language: language,
      defaultAccountId: defaultAccountId,
      defaultCategoryId: defaultCategoryId,
    );
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    await _prefs.setString(_keyCurrency, currency);
  }

  Future<void> setDateFormat(AppDateFormat dateFormat) async {
    state = state.copyWith(dateFormat: dateFormat);
    await _prefs.setInt(_keyDateFormat, dateFormat.index);
  }

  Future<void> setNumberFormat(AppNumberFormat numberFormat) async {
    state = state.copyWith(numberFormat: numberFormat);
    await _prefs.setInt(_keyNumberFormat, numberFormat.index);
  }

  Future<void> setFirstDayOfWeek(AppFirstDayOfWeek firstDayOfWeek) async {
    state = state.copyWith(firstDayOfWeek: firstDayOfWeek);
    await _prefs.setInt(_keyFirstDayOfWeek, firstDayOfWeek.index);
  }

  Future<void> setLanguage(Locale? language) async {
    state = state.copyWith(language: Wrapped(language));
    if (language != null) {
      await _prefs.setString(_keyLanguage, language.languageCode);
    } else {
      await _prefs.remove(_keyLanguage);
    }
  }

  Future<void> setDefaultAccountId(String? accountId) async {
    state = state.copyWith(defaultAccountId: Wrapped(accountId));
    if (accountId != null) {
      await _prefs.setString(_keyDefaultAccount, accountId);
    } else {
      await _prefs.remove(_keyDefaultAccount);
    }
  }

  Future<void> setDefaultCategoryId(String? categoryId) async {
    state = state.copyWith(defaultCategoryId: Wrapped(categoryId));
    if (categoryId != null) {
      await _prefs.setString(_keyDefaultCategory, categoryId);
    } else {
      await _prefs.remove(_keyDefaultCategory);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
