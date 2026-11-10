/// The features LedgerZero Pro (a one-time purchase) can unlock.
enum ProFeature {
  /// Wi-Fi sync between the phones of a household.
  wifiSync,

  /// Booking card payments from bank and wallet notifications.
  cardCapture,

  /// Reports exported as PDF.
  pdfReports,

  /// Budget templates (save, apply) and the automatic fill of new months.
  budgetTemplates,

  /// Rules that categorise and rename transactions.
  rules,
}

/// The free/Pro split, in one place.
abstract final class ProFeatures {
  /// The features that need Pro. Every feature not listed here is free:
  /// removing a feature from this set makes it free everywhere (its gate,
  /// its badge and its line on the Pro screen all read this set).
  static const Set<ProFeature> gated = {
    ProFeature.wifiSync,
    ProFeature.cardCapture,
    ProFeature.pdfReports,
    ProFeature.budgetTemplates,
    ProFeature.rules,
  };

  /// The Google Play product (a one-time, non-consumable in-app product)
  /// that unlocks Pro. Create it with this id in the Play Console.
  static const String productId = 'ledgerzero_pro';

  static bool needsPro(ProFeature feature) => gated.contains(feature);
}
