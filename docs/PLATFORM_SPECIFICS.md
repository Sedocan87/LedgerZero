# Platform-Specific Behaviors and Configurations

This document outlines the platform-specific implementations, configurations, and behaviors for LedgerZero. v1 supports **Android** only.

## Responsive Design & Adaptivity

### Orientation & Layout
- **Phones**: Screens use scrollable layouts (`SingleChildScrollView`, lists) to adapt to portrait and landscape orientations.
- **Tablets / split screen**: `BudgetScreen`, `AccountsScreen`, `PayeesScreen` and `PayeeDetailScreen` limit their content to a maximum width of **800 logical pixels** (`ConstrainedBox`) to stay readable on wide screens.

### Adaptive Widgets
- The app uses Material Design 3 widgets.
- **Font Scaling**: Text-heavy areas use scrollable containers so larger system text sizes do not break the layout. See [ACCESSIBILITY.md](ACCESSIBILITY.md).

## Permissions & Capabilities

### Android
- **Permissions** (`android/app/src/main/AndroidManifest.xml`):
  - `INTERNET`: Required for cloud synchronization (Google Drive).
  - `ACCESS_NETWORK_STATE`: Used to detect Wi-Fi vs. cellular connections.
  - `USE_BIOMETRIC`: Required for `BiometricPrompt` (biometric unlock).
  - `VIBRATE`: For haptic feedback.
  - `POST_NOTIFICATIONS`: For local notifications (sync alerts, reminders).
  - `RECEIVE_BOOT_COMPLETED`: Lets scheduled local notifications survive a reboot.
- **Camera** (`CAMERA`, added by `mobile_scanner`): only for scanning the
  Wi-Fi sync pairing code; asked when the scanner opens.
- **Local network**: Wi-Fi sync listens on TCP 47321 and sends/receives UDP
  broadcasts on 47322 while the app is open. See
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md#local-wi-fi).
- **Notification listener**: `CardNotificationListener`, bound by the system
  (`BIND_NOTIFICATION_LISTENER_SERVICE`) only after the user grants
  notification access; reads notifications of the bank/card apps chosen in
  Settings > Card notifications. `<queries>` lists known bank and wallet
  apps for the app picker. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md).
- **Deep links**: `ledgerzero://` scheme.

### iOS
iOS is not supported in v1. The Flutter code and the `ios/` project stay in
the repository, but iOS is not built, tested or documented.

## Biometric Authentication
- **Implementation**: app-owned platform code behind the `com.ledgerzero.app/biometric_key` method channel (`lib/services/security/biometric_key_store.dart`); see [ENCRYPTION.md](ENCRYPTION.md#biometric-unlock).
- **Android**: `BiometricKeyChannel.kt` (Keystore key + `BiometricPrompt.CryptoObject`, BIOMETRIC_STRONG, `androidx.biometric`). `MainActivity.kt` extends `FlutterFragmentActivity`, as `BiometricPrompt` requires, and sets `FLAG_SECURE`.

## File System Access
- **Path Provider**: The encrypted database (`db.sqlite`) lives in the application documents directory. Exports, backups being built and restores in progress use the temporary/cache directory (not backed up); diagnostic logs use the cache directory.
