# Offline Mode FAQ

### Q: Can I use LedgerZero without any internet connection?
**A:** Yes! LedgerZero is a "Local-First" app. It works 100% offline. You never need an internet connection to use the core features (budgeting, transaction entry, reports). Internet is only required if you want to sync data between multiple devices.

### Q: What happens if I add a transaction while in Airplane Mode?
**A:** The transaction is saved immediately to your device. It appears in your lists and affects your budget instantly. A background record of this change is queued up. The next time you have internet access, LedgerZero will quietly upload this change to your cloud storage to keep your other devices in sync.

### Q: Will I lose my data if I don't sync for a long time?
**A:** No. Your data is safely stored on your device. Syncing is just for backing up to the cloud or sharing with other devices. You could stay offline for a year, and the moment you reconnect, all your changes will sync up (though it might take a few minutes if there are thousands of changes!).

### Q: Does offline mode save battery?
**A:** Generally, yes. The app doesn't constantly poll a server. It only uses the network when there are changes to sync or when you perform a manual sync.

### Q: Can I force the app to stay offline even if I have internet?
**A:** While there isn't a global "Offline Mode" switch in the app, you can:
1.  Go to **Settings > Sync Settings**.
2.  Enable **"Sync only on Wi-Fi"** (if you are on cellular).
3.  Or simply tap **Disconnect** to stop syncing entirely. You can reconnect later.

### Q: What if I edit the same transaction on two devices while both are offline?
**A:** LedgerZero uses a "Last-Writer-Wins" policy. When both devices eventually sync, the change that happened *latest* (by timestamp) will be the one that is kept.

### Q: I see "Offline: Changes queued" in the settings. What does this mean?
**A:** This confirms that you have made changes that haven't been uploaded to the cloud yet because of no internet connection. You don't need to do anything; the app will handle it automatically when connection is restored.
