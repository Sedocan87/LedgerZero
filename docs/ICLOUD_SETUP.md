# iCloud Setup Requirements

## User Requirements

To use iCloud Sync in LedgerZero, users must meet the following requirements:

### Hardware & Software
- **iOS Device:** Running iOS 11.0 or later.
- **macOS Device:** Running macOS 10.13 High Sierra or later.
- **LedgerZero App:** Installed on a supported device.

### Account Setup
1.  **Apple ID:** A valid Apple ID signed in on the device.
2.  **iCloud Drive:** Enabled in System Settings.
    *   **iOS:** Settings -> [Your Name] -> iCloud -> iCloud Drive -> On.
    *   **macOS:** System Settings -> Apple ID -> iCloud -> iCloud Drive -> On.
3.  **App Permissions:** LedgerZero must be allowed to access iCloud Drive.
    *   **iOS:** Settings -> [Your Name] -> iCloud -> Apps using iCloud -> Show All -> LedgerZero -> On.

## Developer Requirements

To build and run LedgerZero with iCloud support:

### Apple Developer Program
- A valid Apple Developer Program membership is required to create iCloud Containers.

### Capabilities & Entitlements
1.  **iCloud Capability:** Must be enabled in Xcode for the App ID.
2.  **iCloud Container:** Create a container named `iCloud.com.ledgerzero.app`.
3.  **Entitlements File:**
    *   Key: `com.apple.developer.icloud-container-identifiers`
    *   Value: `['iCloud.com.ledgerzero.app']`
    *   Key: `com.apple.developer.icloud-services`
    *   Value: `['CloudDocuments']`
    *   Key: `com.apple.developer.ubiquity-container-identifiers` (for legacy support, usually same as container)

### Info.plist Configuration
Ensure `ios/Runner/Info.plist` and `macos/Runner/Info.plist` contain:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.ledgerzero.app</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>LedgerZero</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
    </dict>
</dict>
```

### Provisioning Profiles
- Ensure your provisioning profile includes the iCloud capability and the specific container identifier.
