/// What happened to a Pro purchase the store reports.
enum ProPurchaseStatus {
  /// Bought, but the payment is not through yet (for example cash at a
  /// shop). Pro is not unlocked until the store reports [purchased].
  pending,

  /// Bought (or restored) and paid.
  purchased,

  /// The user closed the purchase sheet.
  cancelled,

  /// The store reported an error.
  failed,
}

/// One update from the store's purchase flow.
class ProPurchaseUpdate {
  final ProPurchaseStatus status;

  /// The store's message for [ProPurchaseStatus.failed], for the log.
  final String? error;

  const ProPurchaseUpdate(this.status, {this.error});
}

/// The store that sells LedgerZero Pro: a single one-time product. The app
/// talks to the store directly (Google Play Billing on the phone); there is
/// no server of ours in between.
abstract interface class ProStore {
  /// Purchase flow results, also for purchases finished while the app was
  /// closed (delivered after the next start).
  Stream<ProPurchaseUpdate> get updates;

  /// Whether purchases can be made on this phone (the Play Store is
  /// installed and reachable).
  Future<bool> isAvailable();

  /// The product's price, formatted by the store in the user's currency;
  /// null when the store does not know the product.
  Future<String?> price();

  /// Opens the store's purchase sheet. False when it could not be opened;
  /// the outcome arrives on [updates].
  Future<bool> buy();

  /// Whether the store's account owns Pro: true or false, or null when the
  /// store could not answer (offline, Play Store unavailable). Finishes
  /// (acknowledges) a purchase that was paid but not acknowledged yet.
  Future<bool?> owned();

  void dispose();
}

/// A store that sells nothing: platforms without Google Play billing
/// (tests, desktop, iOS until the App Store product exists).
class UnavailableProStore implements ProStore {
  const UnavailableProStore();

  @override
  Stream<ProPurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> price() async => null;

  @override
  Future<bool> buy() async => false;

  @override
  Future<bool?> owned() async => null;

  @override
  void dispose() {}
}
