/// Addresses the app shows or opens: the support contact and the legal
/// pages. The one place to change them.
abstract final class AppLinks {
  /// Where "Contact support" writes to.
  static const String supportEmail = 'support@ledgerzero.app';

  /// The hosted privacy policy. While null, About shows no entry for it.
  static const String? privacyPolicyUrl = null;

  /// The hosted imprint (Impressum). While null, About shows no entry for
  /// it.
  static const String? imprintUrl = null;
}
