// SettingsNotifier with the shared_preferences test store: defaults,
// restoring saved values and persisting every change across a restart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> restart() async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> start([
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    return restart();
  }

  test('defaults', () async {
    final s = (await start()).read(settingsProvider);
    expect(s.currency, 'USD');
    expect(s.language, isNull);
    expect(s.defaultAccountId, isNull);
    expect(s.scheduledTransactionNotifications, isTrue);
    expect(s.budgetAlertNotifications, isTrue);
    expect(s.syncStatusNotifications, isTrue);
  });

  test('a fresh install proposes the currency of the device locale', () async {
    Future<String> currencyFor(List<Locale> locales) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(locales),
        ],
      );
      addTearDown(c.dispose);
      return c.read(settingsProvider).currency;
    }

    expect(await currencyFor(const [Locale('de', 'DE')]), 'EUR');
    expect(await currencyFor(const [Locale('de')]), 'EUR');
    expect(await currencyFor(const [Locale('de', 'CH')]), 'CHF');
    expect(await currencyFor(const [Locale('en', 'GB')]), 'GBP');
    expect(await currencyFor(const [Locale('en', 'US')]), 'USD');
    // Unsupported currency (INR): the next locale, else USD.
    expect(
      await currencyFor(const [Locale('en', 'IN'), Locale('de', 'AT')]),
      'EUR',
    );
    expect(await currencyFor(const [Locale('en', 'IN')]), 'USD');
    expect(await currencyFor(const []), 'USD');
  });

  test('a stored currency wins over the device locale', () async {
    SharedPreferences.setMockInitialValues({'settings_currency': 'USD'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(const [Locale('de', 'DE')]),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).currency, 'USD');
  });

  test('restores saved values', () async {
    final s = (await start({
      'settings_currency': 'EUR',
      'settings_notif_scheduled_tx': false,
      'settings_notif_budget_alert': false,
      'settings_notif_sync_status': false,
    })).read(settingsProvider);
    expect(s.currency, 'EUR');
    expect(s.scheduledTransactionNotifications, isFalse);
    expect(s.budgetAlertNotifications, isFalse);
    expect(s.syncStatusNotifications, isFalse);
  });

  test('every change is applied and survives a restart', () async {
    final c = await start();
    final n = c.read(settingsProvider.notifier);
    await n.setCurrency('JPY');
    await n.setLanguage(const Locale('de'));
    await n.setDefaultAccountId('acc-1');
    await n.setDefaultCategoryId('cat-1');
    await n.setScheduledTransactionNotifications(false);
    await n.setBudgetAlertNotifications(false);
    await n.setSyncStatusNotifications(false);
    final dateFormat = AppDateFormat.values.last;
    final numberFormat = AppNumberFormat.values.last;
    final firstDay = AppFirstDayOfWeek.values.last;
    await n.setDateFormat(dateFormat);
    await n.setNumberFormat(numberFormat);
    await n.setFirstDayOfWeek(firstDay);
    expect(c.read(settingsProvider).currency, 'JPY');

    final s = (await restart()).read(settingsProvider);
    expect(s.currency, 'JPY');
    expect(s.language, const Locale('de'));
    expect(s.defaultAccountId, 'acc-1');
    expect(s.defaultCategoryId, 'cat-1');
    expect(s.scheduledTransactionNotifications, isFalse);
    expect(s.budgetAlertNotifications, isFalse);
    expect(s.syncStatusNotifications, isFalse);
    expect(s.dateFormat, dateFormat);
    expect(s.numberFormat, numberFormat);
    expect(s.firstDayOfWeek, firstDay);

    // Clearing the language follows the device again.
    await (await restart()).read(settingsProvider.notifier).setLanguage(null);
    expect((await restart()).read(settingsProvider).language, isNull);
  });
}
