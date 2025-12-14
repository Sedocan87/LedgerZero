import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_provider_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  late MockSharedPreferences mockPrefs;
  late ProviderContainer container;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SettingsNotifier', () {
    test('loads default values when no prefs are set', () {
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getBool(any)).thenReturn(null);

      final notifier = container.read(settingsProvider.notifier);
      final state = notifier.state;

      expect(state.currency, 'USD');
      expect(state.scheduledTransactionNotifications, true);
      expect(state.budgetAlertNotifications, true);
      expect(state.syncStatusNotifications, true);
      expect(state.developerMode, false);
    });

    test('loads saved values from prefs', () {
      when(mockPrefs.getString('settings_currency')).thenReturn('EUR');
      when(mockPrefs.getBool('settings_notif_scheduled_tx')).thenReturn(false);
      when(mockPrefs.getBool('settings_notif_budget_alert')).thenReturn(false);
      when(mockPrefs.getBool('settings_notif_sync_status')).thenReturn(false);
      when(mockPrefs.getBool('settings_developer_mode')).thenReturn(true);

      // Stub other calls to return null/default
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getString('settings_language')).thenReturn(null);
      when(mockPrefs.getString('settings_default_account')).thenReturn(null);
      when(mockPrefs.getString('settings_default_category')).thenReturn(null);

      final notifier = container.read(settingsProvider.notifier);
      final state = notifier.state;

      expect(state.currency, 'EUR');
      expect(state.scheduledTransactionNotifications, false);
      expect(state.budgetAlertNotifications, false);
      expect(state.syncStatusNotifications, false);
      expect(state.developerMode, true);
    });

    test('updates scheduledTransactionNotifications and persists', () async {
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getBool(any)).thenReturn(null);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

      final notifier = container.read(settingsProvider.notifier);

      await notifier.setScheduledTransactionNotifications(false);

      expect(notifier.state.scheduledTransactionNotifications, false);
      verify(mockPrefs.setBool('settings_notif_scheduled_tx', false)).called(1);
    });

    test('updates budgetAlertNotifications and persists', () async {
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getBool(any)).thenReturn(null);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

      final notifier = container.read(settingsProvider.notifier);

      await notifier.setBudgetAlertNotifications(false);

      expect(notifier.state.budgetAlertNotifications, false);
      verify(mockPrefs.setBool('settings_notif_budget_alert', false)).called(1);
    });

    test('updates syncStatusNotifications and persists', () async {
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getBool(any)).thenReturn(null);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

      final notifier = container.read(settingsProvider.notifier);

      await notifier.setSyncStatusNotifications(false);

      expect(notifier.state.syncStatusNotifications, false);
      verify(mockPrefs.setBool('settings_notif_sync_status', false)).called(1);
    });

    test('updates developerMode and persists', () async {
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getBool(any)).thenReturn(null);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

      final notifier = container.read(settingsProvider.notifier);

      await notifier.setDeveloperMode(true);

      expect(notifier.state.developerMode, true);
      verify(mockPrefs.setBool('settings_developer_mode', true)).called(1);
    });
  });
}
