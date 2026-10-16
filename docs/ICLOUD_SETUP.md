# iCloud Setup Requirements

## User Requirements

To use iCloud Sync in LedgerZero, users must meet the following requirements:

### Hardware & Software
- **iPhone or iPad** with the LedgerZero app. iCloud sync is offered on iOS only
  (Android devices sync through Google Drive; there is no macOS app).

### Account Setup
1.  **Apple ID:** A valid Apple ID signed in on the device.
2.  **iCloud Drive:** Settings -> [Your Name] -> iCloud -> iCloud Drive -> On.
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
    *   Key: `com.apple.developer.ubiquity-container-identifiers`
    *   Value: `['iCloud.com.ledgerzero.app']`
    *   (`ios/Runner/Runner.entitlements`)

### Info.plist Configuration
Ensure `ios/Runner/Info.plist` contains:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.ledgerzero.app</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <false/>
        <key>NSUbiquitousContainerName</key>
        <string>LedgerZero</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
    </dict>
</dict>
```

### Provisioning Profiles
- Ensure your provisioning profile includes the iCloud capability and the specific container identifier.

## How sync uses the container

* Change files (`*.lzsync`), snapshots (`*.lzsnap`) and the manifest
  (`ledgerzero-sync-manifest.json`) live at the root of the container;
  backups in `Backups/`. All sync files are encrypted with the key derived
  from your sync passphrase (see [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)).
* `icloud_storage` 2.2.0 (`ICloudDriveService`,
  `lib/services/sync/icloud_drive_service.dart`, which takes an injectable
  `ICloudStoragePlatform` for tests) returns from `upload`/`download` before
  the transfer is complete. LedgerZero waits for the end of the progress
  stream (with a timeout) and checks the size of every download before using
  it; a slow upload is left to iCloud, because the file is already in the
  ubiquity container.
* "Not signed in / container unavailable" errors are permanent until the
  user fixes the account; network, timeout and native transfer errors are
  retried.
* Only devices signed in to the same Apple ID share the container. To sync
  an iPhone with an Android device, use Google Drive on both.
