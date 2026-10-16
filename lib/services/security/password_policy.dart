import 'package:ledger_zero/services/security/common_passwords.dart';

enum PasswordStrength { tooShort, common, weak, fair, good, strong }

/// Local password rules: at least [minLength] characters, not a common
/// password, plus a simple strength estimate for the meter (length,
/// character classes, repeats and sequences). Nothing is sent anywhere.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 10;

  /// Whether [password] may be used as a master or backup password.
  static bool isAcceptable(String password) {
    final s = evaluate(password);
    return s != PasswordStrength.tooShort && s != PasswordStrength.common;
  }

  static PasswordStrength evaluate(String password) {
    if (password.runes.length < minLength) {
      return PasswordStrength.tooShort;
    }
    final lower = password.toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'[^a-z]+$'), '');
    if (commonPasswords.contains(lower) ||
        (stripped.length >= 4 &&
            commonPasswords.contains(stripped) &&
            lower.length - stripped.length <= 4)) {
      return PasswordStrength.common;
    }

    var score = 0;
    final length = password.runes.length;
    if (length >= 12) {
      score++;
    }
    if (length >= 16) {
      score++;
    }
    if (length >= 20) {
      score++;
    }
    var classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) {
      classes++;
    }
    if (RegExp(r'[A-Z]').hasMatch(password)) {
      classes++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) {
      classes++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      classes++;
    }
    if (classes >= 3) {
      score++;
    }
    if (classes == 1) {
      score--;
    }
    if (RegExp(r'(.)\1\1').hasMatch(password)) {
      score--;
    }
    if (_hasSequence(lower)) {
      score--;
    }
    final unique = lower.runes.toSet().length;
    if (unique < length / 2) {
      score--;
    }

    if (score <= 0) {
      return PasswordStrength.weak;
    }
    if (score == 1) {
      return PasswordStrength.fair;
    }
    if (score == 2) {
      return PasswordStrength.good;
    }
    return PasswordStrength.strong;
  }

  static bool _hasSequence(String s) {
    const rows = [
      'abcdefghijklmnopqrstuvwxyz',
      '01234567890',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ];
    for (var i = 0; i + 4 <= s.length; i++) {
      final part = s.substring(i, i + 4);
      for (final row in rows) {
        if (row.contains(part) ||
            row.contains(part.split('').reversed.join())) {
          return true;
        }
      }
    }
    return false;
  }
}
