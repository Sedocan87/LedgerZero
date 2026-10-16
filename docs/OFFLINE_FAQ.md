# Offline Mode FAQ

### Q: Can I use LedgerZero without any internet connection?
**A:** Yes! LedgerZero is a "Local-First" app. It works 100% offline. You never need an internet connection to use the core features (budgeting, transaction entry, reports). Internet is only required if you want to sync data between multiple devices.

### Q: What happens if I add a transaction while in Airplane Mode?
**A:** The transaction is saved immediately to your device. It appears in your lists and affects your budget instantly. A background record of this change is queued up. The next time the app is open, unlocked and online, LedgerZero will quietly upload this change to your cloud storage to keep your other devices in sync.

### Q: Will I lose my data if I don't sync for a long time?
**A:** No. Your data is safely stored on your device. Syncing is for sharing your data with your other devices; to protect against losing the device, also create encrypted backups (Settings > Backup & Export). You could stay offline for a year, and the moment you reconnect, all your changes will sync up (though it might take a few minutes if there are thousands of changes!).

### Q: Does offline mode save battery?
**A:** Generally, yes. With the frequency *Manual* the app only syncs when you tap *Sync Now* or pull to refresh on the Home screen. Other frequencies sync after changes, on resume and on a timer (Real-time: every 5 minutes).

### Q: Can I force the app to stay offline even if I have internet?
**A:** While there isn't a global "Offline Mode" switch in the app, you can:
1.  Go to **Settings > Sync Settings**.
2.  Enable **"Sync only on Wi-Fi"** (if you are on cellular).
3.  Or simply tap **Disconnect** to stop syncing entirely. You can reconnect later.

### Q: What if I edit the same transaction on two devices while both are offline?
**A:** LedgerZero uses a "Last-Writer-Wins" policy per row. When both devices sync, the edit made *latest* is kept on both. The device whose edit lost lists it under **Sync settings → Sync conflicts**; tap **Keep mine** to apply your version again on all devices, or **Dismiss**.

### Q: Sync settings says "N changes waiting to upload". What does this mean?
**A:** These are changes made on this device that have not reached the cloud yet (for example because you are offline). You don't need to do anything; they are uploaded at the next sync.

### Q: I am asked for a sync passphrase. Which one?
**A:** The first device you set up sync on asks you to choose a sync passphrase; every other device asks for that same passphrase. It encrypts everything in your cloud folder. It cannot be recovered, so keep it safe; without it a new device cannot read the folder.

### Q: Sync settings says a change file could not be applied.
**A:** A file from one of your devices was damaged or incomplete. The app retries it automatically; changes from that device wait, all other devices keep syncing. You can tap **Retry**, share the diagnostics (file names and error messages only), or skip the file.
