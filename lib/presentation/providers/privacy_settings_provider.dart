import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

const String kNotificationAmountsKey = 'privacy_notification_amounts';

class PrivacySettings {
  /// Save scrubbed crash reports on this device (opt-in).
  final bool crashReports;

  /// Show amounts in reminder notifications (opt-in; the lock screen may
  /// show notification text).
  final bool notificationAmounts;

  const PrivacySettings({
    this.crashReports = false,
    this.notificationAmounts = false,
  });
}

class PrivacySettingsNotifier extends Notifier<PrivacySettings> {
  @override
  PrivacySettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    ref.watch(settingsGenerationProvider); // reload after a factory reset
    final crashReports = prefs.getBool(kCrashReportsEnabledKey) ?? false;
    LocalErrorReportingService.crashReportsEnabled = crashReports;
    return PrivacySettings(
      crashReports: crashReports,
      notificationAmounts: prefs.getBool(kNotificationAmountsKey) ?? false,
    );
  }

  Future<void> setCrashReports(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kCrashReportsEnabledKey, value);
    LocalErrorReportingService.crashReportsEnabled = value;
    state = PrivacySettings(
      crashReports: value,
      notificationAmounts: state.notificationAmounts,
    );
  }

  Future<void> setNotificationAmounts(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kNotificationAmountsKey, value);
    state = PrivacySettings(
      crashReports: state.crashReports,
      notificationAmounts: value,
    );
  }
}

final privacySettingsProvider =
    NotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
      PrivacySettingsNotifier.new,
    );

/// Localisations in the app language (Settings, else the device locale), for
/// text produced outside the widget tree (notifications).
AppLocalizations appLocalizationsFor(Ref ref) =>
    ref.read(appLocalizationsProvider);
