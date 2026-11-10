import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<bool> configured(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c.read(syncConfiguredProvider);
  }

  test('Wi-Fi sync counts as sync', () async {
    expect(await configured({'sync_provider': 'localWifi'}), isTrue);
  });

  test('no sync without a provider or with a removed one (Google Drive, '
      'iCloud)', () async {
    expect(await configured({}), isFalse);
    expect(await configured({'sync_provider': 'none'}), isFalse);
    expect(await configured({'sync_provider': 'googleDrive'}), isFalse);
    expect(await configured({'sync_provider': 'iCloud'}), isFalse);
  });
}
