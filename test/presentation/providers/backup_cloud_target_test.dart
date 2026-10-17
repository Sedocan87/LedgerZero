import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<BackupCloudTarget?> target(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c.read(backupCloudTargetProvider);
  }

  test('Google Drive sync uploads backups to Drive', () async {
    expect(
      await target({'sync_provider': 'googleDrive'}),
      BackupCloudTarget.googleDrive,
    );
  });

  test('no target without sync or with a removed provider (iCloud)', () async {
    expect(await target({}), isNull);
    expect(await target({'sync_provider': 'iCloud'}), isNull);
  });
}
