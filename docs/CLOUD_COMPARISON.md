# Cloud Provider Comparison: iCloud vs Google Drive

LedgerZero supports "Bring Your Own Cloud" (BYOC) sync. Here is a comparison to help you choose the best provider for your needs.

## Summary

| Feature | iCloud Drive | Google Drive |
| :--- | :--- | :--- |
| **Best For** | Apple Ecosystem Users | Cross-Platform Users |
| **Setup** | Zero Config (Native) | Web Login (OAuth) |
| **Platform Support** | iOS, macOS | iOS, Android, macOS, Windows, Linux |
| **Privacy** | High (Apple Encrypted) | Standard (Google Security) |
| **Speed** | Instant (Push-based) | Polling-based (Slower) |

## Detailed Breakdown

### 1. Platform Support

*   **iCloud Drive:**
    *   **Pros:** deeply integrated into iOS and macOS.
    *   **Cons:** Not available on Android, Windows, or Linux versions of LedgerZero.
    *   **Verdict:** Choose this if you *only* use Apple devices (e.g., iPhone + MacBook).

*   **Google Drive:**
    *   **Pros:** Works on every platform LedgerZero supports.
    *   **Cons:** Requires a Google account.
    *   **Verdict:** Choose this if you use Android, Windows, or a mix of devices (e.g., iPhone + Windows PC).

### 2. Setup Complexity

*   **iCloud Drive:**
    *   **Experience:** "It just works". No login required within the app if you are signed in to your device.
    *   **Friction:** Near zero.

*   **Google Drive:**
    *   **Experience:** Requires tapping "Connect", signing in via a web browser, and approving permissions.
    *   **Friction:** Low, but requires initial authorization.

### 3. Performance & Sync Speed

*   **iCloud Drive:**
    *   Uses native system background processes.
    *   Often pushes changes faster between Apple devices.
    *   Efficient battery usage due to OS-level optimization.

*   **Google Drive:**
    *   Rely on the app checking for changes (polling) or manual sync.
    *   Might have slight delay compared to iCloud on iOS.

### 4. Privacy & Security

*   **iCloud Drive:**
    *   Apple's Advanced Data Protection (optional) offers end-to-end encryption for iCloud Drive.
    *   Files are stored in a private container.

*   **Google Drive:**
    *   Files are stored in your Google Drive.
    *   LedgerZero uses the specific `drive.file` scope, meaning it can *only* see files it created, not your entire Drive.

## Recommendation

*   **Use iCloud** if you are fully invested in the Apple ecosystem.
*   **Use Google Drive** if you need to sync with an Android phone or Windows/Linux computer.
