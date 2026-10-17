import 'dart:typed_data';

import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';

/// One-way move of installs from before [DeviceKeyStore] (data key wrapped
/// by the master password, recovery key and biometric key).
///
/// After one unlock with the old password, recovery key or biometrics
/// (`UnlockService`), [adopt] stores the data key in [DeviceKeyStore] and
/// deletes everything of the old design. The database keeps its key, so it
/// is not rewritten. The device key is written first: an interruption
/// leaves the old entries behind, which [deleteLeftovers] removes on the
/// next start.
class LegacyKeyMigration {
  const LegacyKeyMigration({
    required this.deviceKeys,
    required this.vault,
    required this.legacy,
    required this.biometrics,
  });

  final DeviceKeyStore deviceKeys;
  final KeyVault vault;
  final LegacyKeyMaterial legacy;
  final BiometricKeyStore biometrics;

  /// Whether this install still has a master-password vault or pre-v2 key
  /// material and no device key.
  Future<bool> isPending() async =>
      await deviceKeys.read() == null &&
      (await vault.exists() || await legacy.exists());

  Future<void> adopt(Uint8List dek) async {
    await deviceKeys.write(dek);
    await deleteLeftovers();
  }

  /// Deletes the vault, legacy entries and the biometric key.
  Future<void> deleteLeftovers() async {
    await vault.delete();
    await legacy.deleteAll();
    await biometrics.delete();
  }
}
