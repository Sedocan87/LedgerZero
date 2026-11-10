# Offline Mode FAQ

### Q: Can I use LedgerZero without any internet connection?
**A:** Yes! LedgerZero is a "Local-First" app. It works 100% offline. You never need an internet connection: budgeting, transaction entry and reports work on the phone, sync runs directly between two phones on the same Wi-Fi (no internet needed on that Wi-Fi), and backups are files you save where you like.

### Q: What happens if I add a transaction while in Airplane Mode?
**A:** The transaction is saved immediately to your device. It appears in your lists and affects your budget instantly. A background record of this change is queued up. The next time LedgerZero is open on both phones on the same Wi-Fi, the change goes to the other phone.

### Q: Will I lose my data if I don't sync for a long time?
**A:** No. Your data is safely stored on your device. Syncing is for sharing your data with your other devices; to protect against losing the device, also create encrypted backups (Settings > Backup & Export) and save them somewhere else, or turn on Android backup. You could stay offline for a year, and the moment you reconnect, all your changes will sync up (though it might take a few minutes if there are thousands of changes!).

### Q: Does offline mode save battery?
**A:** Generally, yes. With the frequency *Manual* the app only syncs when you tap *Sync Now* or pull to refresh on the Home screen. Other frequencies sync after changes, on resume and on a timer (Real-time: every 5 minutes).

### Q: Can I stop syncing for a while?
**A:** Yes. In **Settings > Sync Settings** choose the provider **None** (the app asks you to confirm); choosing Wi-Fi sync again later sends everything you changed or deleted in the meantime. **Turn off Wi-Fi sync** also forgets the pairing: pair the phones again to sync. Sync never uses mobile data: it only reaches the other phone on the same Wi-Fi.

### Q: What if I edit the same transaction on two devices while both are offline?
**A:** LedgerZero uses a "Last-Writer-Wins" policy per row. When both devices sync, the edit made *latest* is kept on both. The device whose edit lost lists it under **Sync settings → Sync conflicts**; tap **Keep mine** to apply your version again on all devices, or **Dismiss**.

### Q: Sync settings says "N changes waiting to upload". What does this mean?
**A:** These are changes made on this device that have not reached the other phone yet (for example because the phones were not on the same Wi-Fi). You don't need to do anything; they are sent at the next sync.

### Q: I am asked for a sync passphrase. Which one?
**A:** With Wi-Fi sync you never type one: the pairing QR code carries the sync passphrase, and every change file is encrypted with it. If a phone asks for a passphrase, turn Wi-Fi sync off on both phones and pair them again.

### Q: Sync settings says a change file could not be applied.
**A:** A file from one of your devices was damaged or incomplete. The app retries it automatically; changes from that device wait, all other devices keep syncing. You can tap **Retry**, share the diagnostics (file names and error messages only), or skip the file.
