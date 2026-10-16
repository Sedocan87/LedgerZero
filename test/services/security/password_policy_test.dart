import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/security/password_policy.dart';

void main() {
  test('requires at least 10 characters', () {
    expect(PasswordPolicy.evaluate('Ab1!xyz'), PasswordStrength.tooShort);
    expect(PasswordPolicy.isAcceptable('Ab1!xyzQW'), isFalse);
    expect(PasswordPolicy.isAcceptable('Ab1!xyzQWe'), isTrue);
  });

  test('rejects common passwords, also with a numeric suffix', () {
    expect(PasswordPolicy.evaluate('password123'), PasswordStrength.common);
    expect(PasswordPolicy.evaluate('qwertyuiop'), PasswordStrength.common);
    expect(PasswordPolicy.evaluate('Sunshine2024'), PasswordStrength.common);
    expect(PasswordPolicy.isAcceptable('1234567890'), isFalse);
  });

  test('rates long mixed passphrases higher than short simple ones', () {
    final simple = PasswordPolicy.evaluate('aaaaaaaaaaaa');
    final strong = PasswordPolicy.evaluate('Correct-Horse-Battery-9-Staple');
    expect(simple.index, lessThan(strong.index));
    expect(strong, PasswordStrength.strong);
  });
}
