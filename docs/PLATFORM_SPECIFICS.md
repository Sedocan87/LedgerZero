# Platform-Specific Behaviors and Configurations

This document outlines the platform-specific implementations, configurations, and behaviors for LedgerZero across Android, iOS, and macOS.

## Responsive Design & Adaptivity

### Orientation & Layout
- **Mobile Devices**: The application utilizes `SingleChildScrollView` and `Column` layouts to adapt to both portrait and landscape orientations.
- **Tablets/Desktop**: Screens such as `BudgetScreen` and `AccountsScreen` enforce a maximum width of **800 logical pixels** (via `ConstrainedBox`) to maintain readability on large screens or in split-screen mode.
- **Split-Screen**: Verified to work gracefully down to mobile-width constraints.

### Adaptive Widgets
- The application uses a `PlatformWidget` abstraction to render platform-appropriate controls:
  - **iOS/macOS**: Uses Cupertino widgets (e.g., `CupertinoSwitch`, `CupertinoActivityIndicator`) where appropriate.
  - **Android/Windows/Linux**: Uses Material Design 3 widgets.
- **Font Scaling**: The UI is verified to handle dynamic type sizes (up to 200%) without breaking layout integrity, utilizing scrollable containers for text-heavy areas.

## Permissions & Capabilities

### Android
- **Permissions** (`AndroidManifest.xml`):
  - `INTERNET`: Required for cloud synchronization (Google Drive).
  - `ACCESS_NETWORK_STATE`: Used to detect Wi-Fi vs. Cellular connections.
  - `USE_BIOMETRIC`: Required for `local_auth` to access fingerprint/face unlock.
  - `VIBRATE`: For haptic feedback.
  - `POST_NOTIFICATIONS`: For local notifications (sync alerts, reminders).
  - `RECEIVE_BOOT_COMPLETED` & `SCHEDULE_EXACT_ALARM`: For scheduling background notifications/backups.

### iOS
- **Permissions** (`Info.plist`):
  - `NSFaceIDUsageDescription`: "LedgerZero uses Face ID to securely access your financial data."
  - `NSUbiquitousContainers`: Configured for iCloud Drive access (`iCloud.com.ledgerzero.app`).
- **URL Schemes**:
  - `ledgerzero://`: Registered for deep linking.

### macOS
- **Entitlements**:
  - `com.apple.security.app-sandbox`: **Enabled** (Required for App Store).
  - `com.apple.security.network.client`: **Enabled** (Required for Google Drive API calls).
  - `com.apple.security.network.server`: Enabled in Debug profile for tooling.
  - `com.apple.developer.icloud-services`: `CloudDocuments`.
  - `com.apple.developer.icloud-container-identifiers`: `iCloud.com.ledgerzero.app`.

## Biometric Authentication
- **Implementation**: Uses `local_auth` package.
- **Android**: `MainActivity.kt` extends `FlutterFragmentActivity` to support the required `FragmentActivity` API for biometric dialogs.
- **iOS/macOS**: Relies on system-standard Face ID / Touch ID APIs via the plugin.

## File System Access
- **Path Provider**:
  - **Android/iOS**: Uses application documents directory for storing the database and temporary files.
  - **macOS**: Sandboxed application support directory.
- **iCloud Drive**:
  - Accessible via `icloud_storage` package which interacts with the ubiquitous container.
  - **Requirement**: User must be signed into iCloud on the device.

## Known Limitations
- **Google Drive on macOS**: Requires `com.apple.security.network.client` entitlement (added).
- **Biometrics on Linux**: Not currently supported by `local_auth`.
- **Window Resizing**: Minimum window size constraints are not explicitly enforced but the responsive layout handles narrow widths effectively.
