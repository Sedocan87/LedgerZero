/// Addresses the app shows or opens. The one place to change them.
///
/// The privacy policy, the terms of use and the imprint are bundled with the
/// app (assets/legal/, shown in Settings); tool/legal/build_pages.py makes
/// web pages of the same texts for the Play listing.
abstract final class AppLinks {
  /// Where "Contact support" writes to.
  static const String supportEmail = 'support@ledgerzero.app';
}
