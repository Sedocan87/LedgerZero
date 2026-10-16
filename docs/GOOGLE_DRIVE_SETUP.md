# Google Drive Sync Setup

LedgerZero uses your Google Drive to synchronize data between devices.

## How it works

1. LedgerZero creates a folder named `LedgerZero` in your Google Drive.
2. Inside, it creates a `Sync` folder.
3. Your changes are uploaded as small encrypted change files (`.lzsync`) to
   this folder, plus a manifest and occasional snapshots (`.lzsnap`). They
   are encrypted with your sync passphrase; Google cannot read them.
4. Other devices download these files to stay in sync.

## Setup Instructions

1. Open **Settings**.
2. Tap **Sync Settings**.
3. Tap **Connect to Google Drive**.
4. Sign in with your Google account.
   - You will see a request for LedgerZero to access "See, edit, create, and delete only the specific Google Drive files you use with this app".
   - This permission (scope: `drive.file`) ensures LedgerZero cannot see or modify your other files.
5. Set a **sync passphrase** on the first device (at least 10 characters,
   typed twice). On every other device, connect the same Google account and
   enter the same passphrase. The passphrase never leaves your devices;
   without it the sync files cannot be read.
6. Once connected, your device syncs automatically (unless the frequency is
   *Manual*).

## Troubleshooting

- **Sync Failed**: Check your internet connection and try "Sync Now".
- **Storage Quota**: Ensure your Google Drive has free space.
- **Multiple Accounts**: Ensure all devices use the same Google account.

## Developer setup: iOS client ID

Google Sign-In on iOS needs an OAuth client ID of type **iOS** (Google Cloud
Console > APIs & Services > Credentials) for the bundle ID
`com.ledgerzero.app`. The ID is not committed to the repository.

1. Create `ios/Flutter/GoogleSignIn.xcconfig` (git-ignored) with:

   ```
   GOOGLE_IOS_CLIENT_ID = 1234567890-abcdef.apps.googleusercontent.com
   GOOGLE_IOS_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234567890-abcdef
   ```

2. Build as usual. `ios/Flutter/Debug.xcconfig` and `Release.xcconfig`
   include this file; `Info.plist` uses the values for `GIDClientID` and the
   Google URL scheme.

Without the file, `GIDClientID` is empty and the URL scheme is the
placeholder `com.ledgerzero.google-sign-in-not-configured`. The app then
detects the missing configuration (`GoogleAuthService.isConfigured`, via the
`com.ledgerzero.app/platform` channel) and Google Drive sync is unavailable
on iOS: connecting reports "Google Drive is not configured in this iOS
build" instead of the Google SDK aborting the app. Android does not need
this file (the OAuth client is matched by package name and signing
certificate).
