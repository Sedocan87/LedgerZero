import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Points path_provider at a new temporary directory for this test (the
/// lock screen looks for the database file there at start-up) and removes
/// it afterwards. Call from `setUp` or a test.
Directory mockAppDirectories() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final dir = Directory.systemTemp.createTempSync('lz_app_dirs_');
  messenger.setMockMethodCallHandler(channel, (call) async => dir.path);
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    dir.deleteSync(recursive: true);
  });
  return dir;
}
