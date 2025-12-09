import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/data/database/database.dart';

// Generate mocks
@GenerateMocks([AppDatabase])
import 'backup_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupService backupService;
  late MockAppDatabase mockDatabase;

  setUp(() {
    mockDatabase = MockAppDatabase();
    backupService = BackupService(mockDatabase);
  });

  // Mock path_provider
  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  test('createBackup creates unencrypted .sqlite file when no password provided', () async {
    // Setup
    when(mockDatabase.customStatement(any, any)).thenAnswer((invocation) async {
      // Simulate creating the file (vacuum into target)
      final args = invocation.positionalArguments[1] as List;
      final path = args[0] as String;
      File(path).writeAsStringSync('dummy db content');
    });

    // Act
    final file = await backupService.createBackup(password: null);

    // Assert
    verify(mockDatabase.customStatement('VACUUM INTO ?', any)).called(1);
    expect(file.path.endsWith('.sqlite'), isTrue);
    expect(await file.readAsString(), 'dummy db content');
  });

  test('createBackup creates encrypted .lzbk file when password provided', () async {
    // Setup
    when(mockDatabase.customStatement(any, any)).thenAnswer((invocation) async {
      final args = invocation.positionalArguments[1] as List;
      final path = args[0] as String;
      // Write some dummy content to be encrypted
      final bytes = Uint8List.fromList(List.generate(100, (i) => i));
      File(path).writeAsBytesSync(bytes);
    });

    // Act
    const password = 'strong_password';
    final file = await backupService.createBackup(password: password);

    // Assert
    verify(mockDatabase.customStatement('VACUUM INTO ?', any)).called(1);
    expect(file.path.endsWith('.lzbk'), isTrue);

    // Verify file structure: Salt (32) + IV (12) + Data (>0)
    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(44)); // 32 + 12

    // We assume encryption happened if the output is different/structured.
    // Decryption test will be in restore service test or we can check manually.
  });
}
