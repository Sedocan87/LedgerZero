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
  fall back to USD). The first on-budget account stores it; see
  [BUDGETING_RULES.md](BUDGETING_RULES.md#budget-currency).

## Permissions & Capabilities

### Android
- **Permissions** (`android/app/src/main/AndroidManifest.xml`):
  - `INTERNET`: Required for cloud synchronization (Google Drive).
  - `ACCESS_NETWORK_STATE`: Used to detect Wi-Fi vs. cellular connections.
  - `USE_BIOMETRIC`: Required for `BiometricPrompt` (biometric unlock).
  - `VIBRATE`: For haptic feedback.
  - `POST_NOTIFICATIONS`: For local notifications (sync alerts, reminders).
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
- **Deep links**: none. The app registers no URL scheme and no app links,
  and `flutter_deeplinking_enabled` is false on `MainActivity`, so neither
  web pages nor another app's explicit intent with a URI can open a screen
  in it. Notification taps
  carry a payload that the app routes itself
  (`lib/services/notifications/notification_tap_router.dart`).

### iOS
iOS is not supported in v1. The Flutter code and the `ios/` project stay in
the repository, but iOS is not built, tested or documented.

## Biometric Authentication
- **Implementation**: app-owned platform code behind the `com.ledgerzero.app/biometric_key` method channel (`lib/services/security/biometric_key_store.dart`); see [ENCRYPTION.md](ENCRYPTION.md#biometric-unlock).
- **Android**: `BiometricKeyChannel.kt` (Keystore key + `BiometricPrompt.CryptoObject`, BIOMETRIC_STRONG, `androidx.biometric`). `MainActivity.kt` extends `FlutterFragmentActivity`, as `BiometricPrompt` requires, and sets `FLAG_SECURE`.

## File System Access
- **Path Provider**: The encrypted database (`db.sqlite`) lives in the application documents directory. Exports, backups being built and restores in progress use the temporary/cache directory (not backed up); diagnostic logs use the cache directory.
