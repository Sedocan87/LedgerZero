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

## Developer setup: Google Cloud (Android)

Google Drive sync needs a one-time setup in the
[Google Cloud Console](https://console.cloud.google.com/). Nothing goes into
the repository: there is no `google-services.json` and no client ID in the
code. With `google_sign_in` 6 and only the `drive.file` scope, Google
recognises the app by its **package name + signing certificate SHA-1**.

### 1. Project and Drive API

Create a project (or reuse one) and enable the **Google Drive API**
(*APIs & Services > Library*). Without it, sign-in succeeds but every Drive
call fails with HTTP 403.

### 2. OAuth consent screen

Under *Google Auth Platform* (*Branding*, *Audience*, *Data access*):

- User type **External**; app name, user support email, developer contact.
- Scope: `https://www.googleapis.com/auth/drive.file` only.
- Homepage and privacy policy URLs, if asked (the Play Store needs a privacy
  policy anyway).
- **Publish the app** (*Audience > Publish app*, status *In production*).
  In *Testing*, only listed test users can sign in and their authorisation
  expires after 7 days, so sync silently stops every week.

`drive.file` is a non-sensitive scope (the app only sees files it created),
so publishing takes effect immediately: no Google review, no "unverified
app" warning, no 100-user cap. Exception: uploading a **logo** to the
consent screen requires brand verification first (usually a few business
days). Leave the logo out to go live at once; it can be added later.
Re-check this when publishing: if the console asks to submit the app for
verification, a scope other than `drive.file` was added.

### 3. Android OAuth clients

Create one OAuth client of type **Android** (*Credentials > Create
credentials > OAuth client ID*) for each package name and signing key you
use:

| Build | Package name | SHA-1 of |
|---|---|---|
| `--flavor development` | `com.ledgerzero.app.dev` | debug keystore |
| `--flavor staging` | `com.ledgerzero.app.staging` | debug keystore |
| `--flavor production` | `com.ledgerzero.app` | release key, **and** the Play App Signing key when distributed through Google Play (Play Console > *Test and release > App integrity*) |

One client holds one SHA-1, so a package signed with two keys needs two
clients. Until `android/key.properties` exists, release builds are signed
with the debug key (`android/app/build.gradle.kts`), so the debug SHA-1 is
also the one for `com.ledgerzero.app`.

Debug SHA-1 (Gradle's JDK from Android Studio; the system Java may not
work):

```sh
export JAVA_HOME="/Volumes/Lexar2TB/Apps/Android Studio.app/Contents/jbr/Contents/Home"
"$JAVA_HOME/bin/keytool" -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android | grep SHA1
```

Release key: the same command with the keystore, alias and password from
`android/key.properties`.

### Costs

None on the Google Cloud side: the project, the OAuth clients and Drive API
calls are free, and no billing account is needed. The Drive API's quotas are
far above what the small sync files use. Sync files are stored in each
user's own Drive and count against their storage, not the developer's.
(Separate from Cloud: a Google Play developer account is a one-time $25
fee.)

### Troubleshooting

- **`ApiException: 10` (DEVELOPER_ERROR) on sign-in**: the package name or
  SHA-1 does not match an Android OAuth client. Check the flavor's package
  name and the key the APK was actually signed with
  (`apksigner verify --print-certs app.apk`). New or changed clients can
  take a few minutes to take effect.
- **403 "Google Drive API has not been used in project …"**: the Drive API
  is not enabled (step 1).
- **Sign-in works for you but not for others, or stops after a week**: the
  consent screen is still in *Testing* (step 2).

## Developer setup: iOS client ID

Not needed for v1 (Android only); kept for a later iOS release.

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
