import 'dart:convert';
import 'dart:typed_data';

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

  test(
    'password change is one write, keeps the key and the recovery key',
    () async {
      final pending = await createVault('old password 123');
      final recoveryText = pending.recoveryKey.format();
      final writesBefore = store.writeCount;

      await vault.changePassword(
        currentPassword: 'old password 123',
        newPassword: 'new password 456',
      );

      expect(store.writeCount, writesBefore + 1);
      expect(await vault.unlockWithPassword('new password 456'), pending.dek);
      expect(
        () => vault.unlockWithPassword('old password 123'),
        throwsA(isA<WrongPasswordException>()),
      );
      expect(await vault.unlockWithRecoveryKey(recoveryText), pending.dek);
    },
  );

  test(
    'password change with a wrong current password changes nothing',
    () async {
      await createVault('old password 123');
      final before = store.values[KeyVault.storageKey];
      await expectLater(
        vault.changePassword(
          currentPassword: 'nope nope nope',
          newPassword: 'new password 456',
        ),
        throwsA(isA<WrongPasswordException>()),
      );
      expect(store.values[KeyVault.storageKey], before);
    },
  );

  test(
    'recovery login can set a new password; recovery key stays valid',
    () async {
      final pending = await createVault('forgotten password');
      final recoveryText = pending.recoveryKey.format();
      final dek = await vault.unlockWithRecoveryKey(recoveryText);

      await vault.setPassword(dek: dek, newPassword: 'brand new password');

      expect(await vault.unlockWithPassword('brand new password'), pending.dek);
      expect(await vault.unlockWithRecoveryKey(recoveryText), pending.dek);
    },
  );

  test('setPassword refuses a key that does not belong to the vault', () async {
    await createVault('some password 1');
    expect(
      () => vault.setPassword(
        dek: Uint8List(32),
        newPassword: 'other password 2',
      ),
      throwsA(isA<VaultCorruptException>()),
    );
  });

  test('recovery key can be shown again and rotated', () async {
    final pending = await createVault('some password 1');
    final shown = await vault.revealRecoveryKey(pending.dek);
    expect(shown.format(), pending.recoveryKey.format());

    final rotation = await vault.prepareRecoveryKeyRotation(pending.dek);
    // Not active until saved.
    expect(
      await vault.unlockWithRecoveryKey(pending.recoveryKey.format()),
      pending.dek,
    );
    await vault.save(rotation.record);
    expect(
      () => vault.unlockWithRecoveryKey(pending.recoveryKey.format()),
      throwsA(isA<InvalidRecoveryKeyException>()),
    );
    expect(
      await vault.unlockWithRecoveryKey(rotation.recoveryKey.format()),
      pending.dek,
    );
    expect(await vault.unlockWithPassword('some password 1'), pending.dek);
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
