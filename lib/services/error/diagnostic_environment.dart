import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What a diagnostic report says about the app and the phone it ran on:
/// the first questions of every support case. Nothing here identifies the
/// user (no device name, no ids).
class DiagnosticEnvironment {
  const DiagnosticEnvironment({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.androidSdk,
    required this.androidRelease,
    required this.deviceModel,
    required this.locale,
    required this.schemaVersion,
  });

  /// Null where the platform did not answer.
  final String? appName;
  final String? version;
  final String? buildNumber;

  /// The Android API level, for example 36; null off Android.
  final int? androidSdk;

  /// The Android version name, for example "16".
  final String? androidRelease;

  /// Manufacturer and model, for example "Google Pixel 8".
  final String? deviceModel;

  /// The system locale, for example "de_DE".
  final String locale;

  /// The database schema version this build of the app works with.
  final int schemaVersion;

  /// Reads the values from the platform. A part that cannot be read stays
  /// null: the report must still be written.
  static Future<DiagnosticEnvironment> fromPlatform() async {
    PackageInfo? package;
    try {
      package = await PackageInfo.fromPlatform();
    } catch (_) {
      // Reported as "unavailable".
    }

    int? sdk;
    String? release;
    String? model;
    try {
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        sdk = android.version.sdkInt;
        release = android.version.release;
        // Not the device name: it usually contains the owner's name.
        model = '${android.manufacturer} ${android.model}'.trim();
      } else {
        model = Platform.operatingSystem;
        release = Platform.operatingSystemVersion;
      }
    } catch (_) {
      // Reported as "unavailable".
    }

    return DiagnosticEnvironment(
      appName: package?.appName,
      version: package?.version,
      buildNumber: package?.buildNumber,
      androidSdk: sdk,
      androidRelease: release,
      deviceModel: model,
      locale: Platform.localeName,
      schemaVersion: AppDatabase.currentSchemaVersion,
    );
  }

  /// The header lines of the report (English, like the rest of the log).
  String describe() {
    const unavailable = 'unavailable';
    final app = version == null
        ? unavailable
        : '${appName ?? 'LedgerZero'} $version (build ${buildNumber ?? '?'})';
    final String system;
    if (androidSdk != null) {
      system = 'Android: ${androidRelease ?? '?'} (SDK $androidSdk)';
    } else {
      system = 'System: ${androidRelease ?? unavailable}';
    }
    return [
      'App: $app',
      system,
      'Device: ${deviceModel ?? unavailable}',
      'Locale: $locale',
      'Database schema: $schemaVersion',
    ].join('\n');
  }
}
