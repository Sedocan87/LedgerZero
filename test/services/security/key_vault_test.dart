import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/security/key_vault.dart';

import '../../helpers/security_fakes.dart';

void main() {
  late InMemorySecureStore store;
  late KeyVault vault;

  setUp(() {
    store = InMemorySecureStore();
    vault = KeyVault(store, newKdfParams: fastKdf);
  });

  Future<PendingVault> createVault(String password) async {
    final pending = await vault.build(password);
    await vault.save(pending.record);
    return pending;
  }

  test('wraps a random 256-bit key and unwraps it with the password', () async {
    final pending = await createVault('correct horse battery');
    expect(pending.dek.length, 32);
    expect(
      await vault.unlockWithPassword('correct horse battery'),
      pending.dek,
    );
  });

  test('wrong password fails the GCM tag', () async {
    await createVault('correct horse battery');
    expect(
      () => vault.unlockWithPassword('wrong password!'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test(
    'stores only wrapped blobs: no plaintext key, no verifier hash',
    () async {
      final pending = await createVault('correct horse battery');
      final raw = store.values[KeyVault.storageKey]!;
      expect(raw, isNot(contains(base64.encode(pending.dek))));
      expect(raw, isNot(contains(base64Url.encode(pending.dek))));
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(
        json.keys,
        containsAll(['v', 'password', 'recovery', 'recoveryKey']),
      );
      expect(raw.toLowerCase(), isNot(contains('verifier')));
      // KDF algorithm, parameters and salt are stored with the blob.
      final kdf = (json['password'] as Map)['kdf'] as Map;
      expect(kdf['alg'], 'argon2id');
      expect(kdf.keys, containsAll(['m', 't', 'p', 'salt']));
    },
  );

  test(
    'recovery key unwraps the same key independently of the password',
    () async {
      final pending = await createVault('correct horse battery');
      final typed = pending.recoveryKey.format().toLowerCase().replaceAll(
        '-',
        ' ',
      );
      expect(await vault.unlockWithRecoveryKey(typed), pending.dek);
      expect(
        () => vault.unlockWithRecoveryKey(
          '0000-0000-0000-0000-0000-0000-0000-0000',
        ),
        throwsA(isA<InvalidRecoveryKeyException>()),
      );
      expect(
        () => vault.unlockWithRecoveryKey('not a key'),
        throwsA(isA<InvalidRecoveryKeyException>()),
      );
    },
  );

  test('recovery key can be shown again', () async {
    final pending = await createVault('some password 1');
    final shown = await vault.revealRecoveryKey(pending.dek);
    expect(shown.format(), pending.recoveryKey.format());
  });

  test('swapping in weaker KDF parameters makes the unwrap fail', () async {
    await createVault('some password 1');
    final json =
        jsonDecode(store.values[KeyVault.storageKey]!) as Map<String, dynamic>;
    final password = json['password'] as Map<String, dynamic>;
    final kdf = Map<String, dynamic>.from(password['kdf'] as Map);
    kdf['m'] = 32;
    password['kdf'] = kdf;
    store.values[KeyVault.storageKey] = jsonEncode(json);
    expect(
      () => vault.unlockWithPassword('some password 1'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('missing vault is reported', () async {
    expect(await vault.exists(), isFalse);
    expect(
      () => vault.unlockWithPassword('x'),
      throwsA(isA<VaultMissingException>()),
    );
  });
}
