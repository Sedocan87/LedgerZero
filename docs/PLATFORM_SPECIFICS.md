# Platform-Specific Behaviors and Configurations

This document outlines the platform-specific implementations, configurations, and behaviors for LedgerZero. The app supports **iOS and Android** only.

## Responsive Design & Adaptivity

### Orientation & Layout
- **Phones**: Screens use scrollable layouts (`SingleChildScrollView`, lists) to adapt to portrait and landscape orientations.
- **Tablets / split screen**: `BudgetScreen`, `AccountsScreen`, `PayeesScreen` and `PayeeDetailScreen` limit their content to a maximum width of **800 logical pixels** (`ConstrainedBox`) to stay readable on wide screens.

### Adaptive Widgets
- The app uses Material Design 3 widgets on both platforms. The loading indicator (`AppLoadingIndicator`, `lib/presentation/widgets/common/app_loading_indicator.dart`) shows a `CupertinoActivityIndicator` on iOS.
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
- **Notification listener**: `CardNotificationListener`, bound by the system
  (`BIND_NOTIFICATION_LISTENER_SERVICE`) only after the user grants
  notification access; reads notifications of the bank/card apps chosen in
  Settings > Card notifications. `<queries>` lists known bank and wallet
  apps for the app picker. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md).
- **Deep links**: `ledgerzero://` scheme.

### iOS
- **Info.plist**:
  - `NSFaceIDUsageDescription`: "LedgerZero uses Face ID to securely access your financial data."
  - `NSUbiquitousContainers`: Configured for iCloud Drive access (`iCloud.com.ledgerzero.app`).
- **Entitlements** (`ios/Runner/Runner.entitlements`): iCloud container `iCloud.com.ledgerzero.app`, service `CloudDocuments`. See [ICLOUD_SETUP.md](ICLOUD_SETUP.md).
- **URL Schemes**:
  - `ledgerzero://`: Registered for deep linking.
  - The reversed Google iOS client ID (from `ios/Flutter/GoogleSignIn.xcconfig`) for Google Sign-In. See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md).

## Biometric Authentication
- **Implementation**: app-owned platform code behind the `com.ledgerzero.app/biometric_key` method channel (`lib/services/security/biometric_key_store.dart`); see [ENCRYPTION.md](ENCRYPTION.md#biometric-unlock).
- **Android**: `BiometricKeyChannel.kt` (Keystore key + `BiometricPrompt.CryptoObject`, BIOMETRIC_STRONG, `androidx.biometric`). `MainActivity.kt` extends `FlutterFragmentActivity`, as `BiometricPrompt` requires, and sets `FLAG_SECURE`.
- **iOS**: Keychain item with `.biometryCurrentSet` in `AppDelegate.swift`; `NSFaceIDUsageDescription` in `Info.plist`. The same file adds the app-switcher privacy cover (UIScene notifications).

## File System Access
- **Path Provider**: The encrypted database (`db.sqlite`) lives in the application documents directory. Exports, backups being built and restores in progress use the temporary/cache directory (not backed up); diagnostic logs use the cache directory.
- **iCloud Drive** (iOS only): accessed through the `icloud_storage` package (2.2.0), which works with the app's ubiquity container (`ICloudDriveService`, `lib/services/sync/icloud_drive_service.dart`). The user must be signed in to iCloud with iCloud Drive turned on for LedgerZero.
