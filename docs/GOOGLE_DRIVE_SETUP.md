# Google Drive Sync Setup

LedgerZero uses your Google Drive to synchronize data between devices.

## How it works

1. LedgerZero creates a folder named `LedgerZero` in your Google Drive.
2. Inside, it creates a `Sync` folder.
3. Your data changes (deltas) are uploaded as small files to this folder.
4. Other devices download these files to stay in sync.

## Setup Instructions

1. Open **Settings**.
2. Tap **Sync Settings**.
3. Tap **Connect to Google Drive**.
4. Sign in with your Google account.
   - You will see a request for LedgerZero to access "See, edit, create, and delete only the specific Google Drive files you use with this app".
   - This permission (scope: `drive.file`) ensures LedgerZero cannot see or modify your other files.
5. Once connected, your device will automatically sync.

## Troubleshooting

- **Sync Failed**: Check your internet connection and try "Sync Now".
- **Storage Quota**: Ensure your Google Drive has free space.
- **Multiple Accounts**: Ensure all devices use the same Google account.
