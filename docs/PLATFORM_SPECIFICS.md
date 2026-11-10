# Platform-Specific Behaviors and Configurations

This document outlines the platform-specific implementations, configurations, and behaviors for LedgerZero. v1 supports **Android** only.

## Responsive Design & Adaptivity

### Orientation & Layout
- **Phones**: Screens use scrollable layouts (`SingleChildScrollView`, lists) to adapt to portrait and landscape orientations.
- **Tablets / split screen**: `BudgetScreen`, `AccountsScreen`, `PayeesScreen` and `PayeeDetailScreen` limit their content to a maximum width of **800 logical pixels** (`ConstrainedBox`) to stay readable on wide screens.

### Adaptive Widgets
- The app uses Material Design 3 widgets.
- **Font Scaling**: Text-heavy areas use scrollable containers so larger system text sizes do not break the layout. See [ACCESSIBILITY.md](ACCESSIBILITY.md).

## Locale, language and currency

* **App language**: `resolveAppLocale` (`lib/presentation/providers/l10n_provider.dart`)
  is the single rule: the language chosen in Settings, else the first
  supported locale in the device's locale list (all entries, in the user's
  order), else English. `MaterialApp.locale`, `appFormatterProvider`
  (amounts, dates) and `appLocalizationsProvider` (notifications, exports)
  all use it, so UI text and number formatting never disagree.
* **Budget currency**: on a fresh install Settings proposes the currency of
  the device locale (`defaultCurrencyForLocales`, `lib/core/money/currency.dart`:
  `de_DE` -> EUR, `en_US` -> USD, `de_CH` -> CHF; unsupported currencies
  fall back to USD). The first on-budget account stores it; afterwards it
  follows the accounts in the budget on every phone; see
  [BUDGETING_RULES.md](BUDGETING_RULES.md#budget-currency).

## Permissions & Capabilities

### Android
- **Permissions** (`android/app/src/main/AndroidManifest.xml`):
  - `INTERNET`: Required for the sockets of Wi-Fi sync (the app talks to no internet server).
  - `ACCESS_NETWORK_STATE`: Used to detect Wi-Fi vs. cellular connections.
  - `USE_BIOMETRIC`: Required for `BiometricPrompt` (the app lock).
  - `VIBRATE`: For haptic feedback.
  - `POST_NOTIFICATIONS`: For local notifications (sync alerts, reminders).
    Asked when a notification is first needed (a reminder is scheduled, a
    backup reminder, sync failure or budget alert is about to be shown; at
    the next unlock or resume if that happened while locked or in the
    background) and when a notification is turned on in Settings, not at
    the end of onboarding (`NotificationPermissionGate`).
  - `RECEIVE_BOOT_COMPLETED`: Lets scheduled local notifications survive a reboot.
- **Camera** (`CAMERA`, added by the `camera` plugin): only for scanning the
  Wi-Fi sync pairing code; asked when the scanner opens. The code is read on
  the phone by `flutter_zxing` (ZXing C++ through FFI). There is no Google
  ML Kit and no Play services in the scanner, so it reports nothing to
  anyone. The app manifest removes what the plugins declare beyond that
  (`RECORD_AUDIO`, the external-storage permissions, `image_picker`'s file
  provider and photo-picker module request) and marks the camera as optional
  (`android.hardware.camera.any`, `required="false"`): the pairing code can
  also be typed.
- **Local network**: Wi-Fi sync listens on TCP 47321 and sends/receives UDP
  broadcasts on 47322 while the app is open. See
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md#local-wi-fi).
- **Notification listener**: `CardNotificationListener`, bound by the system
  (`BIND_NOTIFICATION_LISTENER_SERVICE`) only after the user grants
  notification access; reads notifications of the bank/card apps chosen in
  Settings > Card notifications. `<queries>` lists known bank and wallet
  apps for the app picker. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md).
- **Save to…** (Backup screen): the system's create-document picker
  (`ACTION_CREATE_DOCUMENT` through `file_picker`'s `saveFile`; the
  manifest declares the matching `<queries>` intent). No storage
  permission and no account: the picked location (a folder, a USB stick,
  a cloud app's provider) receives the bytes.
- **Google components**: none of the app's own. The merged manifest has no
  Google sign-in or Play services activity, service or meta-data since
  `google_sign_in` was removed; `<queries>` still names
  `com.google.android.apps.walletnfcrel` and `com.google.android.gms`
  because card capture offers Google Wallet (whose tap-to-pay notifications
  Play services posts) in its app picker.
- **Deep links**: none. The app registers no URL scheme and no app links,
  and `flutter_deeplinking_enabled` is false on `MainActivity`, so neither
  web pages nor another app's explicit intent with a URI can open a screen
  in it. Notification taps
  carry a payload that the app routes itself
  (`lib/services/notifications/notification_tap_router.dart`).

### iOS
iOS is not supported in v1. The Flutter code and the `ios/` project stay in
the repository, but iOS is not built, tested or documented.

## App lock (biometric authentication)
- **Implementation**: `lib/services/security/app_lock_authenticator.dart` behind the `com.ledgerzero.app/app_lock` method channel; see [ENCRYPTION.md](ENCRYPTION.md#app-lock). It gates the UI only and releases no key.
- **Android**: `AppLockChannel.kt` (`BiometricPrompt` without a CryptoObject: BIOMETRIC_STRONG or DEVICE_CREDENTIAL, below API 30 BIOMETRIC_WEAK or DEVICE_CREDENTIAL; `androidx.biometric`). `MainActivity.kt` extends `FlutterFragmentActivity`, as `BiometricPrompt` requires, and sets `FLAG_SECURE`.

## File System Access
- **Path Provider**: The database (`db.sqlite`, a plain SQLite file) lives in the application documents directory (`app_flutter/` in the app's private storage). Exports, backups being built and restores in progress use the temporary/cache directory (not backed up); diagnostic logs use the cache directory.
- **No-backup directory**: `Context.getNoBackupFilesDir()` (method channel `com.ledgerzero.app/install`, `MainActivity.kt`) holds the install marker that tells a moved install from the original; Android never backs it up or moves it.

## Backup and moving to a new phone (Android)
- `android:allowBackup="true"`, `android:dataExtractionRules="@xml/data_extraction_rules"` (Android 12+), `android:fullBackupContent="@xml/backup_rules"` (Android 7–11; `res/xml-v28/backup_rules.xml` for 9–11).
- **Cloud backup** (Android backup to the user's Google account), only end-to-end encrypted with the screen lock: `app_flutter/db.sqlite`, `app_flutter/db.sqlite-wal` (domain `root`) and `FlutterSharedPreferences.xml` (domain `sharedpref`).
  - Android 12+: `<cloud-backup disableIfNoEncryptionCapabilities="true">`. The attribute belongs to the `cloud-backup` section only (the framework turns it into the required transport flag `FLAG_CLIENT_SIDE_ENCRYPTION_ENABLED` for the whole section); without it, a phone without a screen lock would upload unencrypted.
  - Android 9–11: each include carries `requireFlags="clientSideEncryption"`. A second include per file carries `requireFlags="deviceToDeviceTransfer"` for the transfer: `requireFlags` with several values (`a|b`) means all of them (`(transportFlags & required) == required` in `BackupAgent`), so two includes give "either".
  - Android 7.0–8.1: nothing (`requireFlags` needs API 28; there is no way to require encryption).
- **Device-to-device transfer**: the same three files on Android 9 and later, with or without a screen lock (`<device-transfer>` on 12+, the `deviceToDeviceTransfer` includes on 9–11). Nothing on 7.0–8.1.
- Left out on purpose: the flutter_secure_storage files (KeyStore-encrypted; the key cannot move), the card capture store (`ledgerzero_capture.xml`, KeyStore-encrypted), the cache, exports, the sync folder (`app_flutter/sync`) and the automatic backups (external storage).
- **When**: Android backs up about once a day (backup on, 24 hours since the last one, device idle, on Wi-Fi unless mobile data is allowed), skips apps in the foreground, and restores right after the app is installed (Play Store, setup of a new phone, `adb install`), before it can be launched. The app checkpoints the WAL (`PRAGMA wal_checkpoint(TRUNCATE)`) whenever it goes to the background, so `db.sqlite` alone holds every committed change by then, and the `-wal` is included for the rest.
- **Quota**: 25 MB per app; above it Android calls `onQuotaExceeded` and backs nothing up until the data shrinks. The Backup screen notes a database above 20 MB (`androidBackupSizeNote`).
- **Settings**: the app cannot read whether backup is on (`BackupManager.isBackupEnabled` needs the system permission `BACKUP`) and Android has no public intent action for the backup settings, so the Backup screen explains the setting without a button.
- A restored or moved install gets a new sync device id at its first start; see [SECURITY.md](SECURITY.md#android-backup-and-moving-to-a-new-phone) and [BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md#7-moving-to-a-new-phone). Verifying needs real phones: `adb shell bmgr backupnow` with the GMS transport and a reinstall for the cloud backup, a phone setup for the transfer (the checks are listed in ROADMAP.md).
