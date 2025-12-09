import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/reports/report_export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'dart:ui';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

class MockSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  bool shareCalled = false;
  List<XFile> sharedFiles = [];

  void reset() {
    shareCalled = false;
    sharedFiles = [];
  }

  // @override - The share method might have been removed or changed in the interface, check SharePlatform definition
  // However, looking at share_plus_platform_interface, share() is indeed there but might have different signature.
  // The error says "The method doesn't override an inherited method", which means SharePlatform does not have this method signature.
  // Checking share_plus_platform_interface:
  // It has share(String text, {String? subject, Rect? sharePositionOrigin}) in older versions,
  // or shareUri(Uri uri, {Rect? sharePositionOrigin})
  // or maybe it's completely gone in favor of shareXFiles in newer versions?
  // Let's assume for now we remove @override if it's not in the interface, or fix the signature.
  // But wait, the analysis said "The method doesn't override an inherited method".

  // Let's look at shareXFiles. That seems correct.

  // If I check the package version `share_plus_platform_interface`... I don't see it in pubspec.yaml in the file list I saw earlier (it was implied by share_plus).

  // Let's remove the @override annotation for share if it is not in the super class.
  // But wait, if it's not in the super class, then the MockSharePlatform isn't implementing it correctly if it's expected?
  // Or maybe the test code calls `share`?
  // The test code calls `service.shareCsv` which presumably calls `Share.shareXFiles` (since CSV is a file).
  // The first test `shareCsv generates CSV and shares it` expects `mockShare.shareCalled` to be true.

  // If `ReportExportService` uses `Share.shareXFiles` internally, then we don't need `share`.
  // Let's just remove the method if it's not part of the interface and not used.
  // But wait, `ReportExportService` might use `Share.share` for text?
  // `shareCsv` likely creates a file and shares it, so `shareXFiles`.

  // Let's look at the error again: `test/services/reports/report_export_service_test.dart:36:23 • override_on_non_overriding_member`
  // Line 36 is `Future<ShareResult> share(`.

  // So I will remove @override.

  @override
  Future<ShareResult> share(
    ShareParams params,
  ) async {
    print('MockSharePlatform.share called');
    shareCalled = true;
    return const ShareResult('success', ShareResultStatus.success);
  }

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    print('MockSharePlatform.shareXFiles called with ${files.length} files');
    shareCalled = true;
    sharedFiles = files;
    return const ShareResult('success', ShareResultStatus.success);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockShare = MockSharePlatform();

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    // Set instance only once or ensure it's set.
    // If SharePlus caches it, we want it to cache OUR mock.
    SharePlatform.instance = mockShare;
    mockShare.reset();
  });

  test('shareCsv generates CSV and shares it', () async {
    final service = ReportExportService();
    final data = <List<dynamic>>[
      ['Category', 'Amount'],
      ['Food', 100.0],
      ['Rent', 500.0]
    ];

    await service.shareCsv(data, 'test_report');

    expect(mockShare.shareCalled, true);
  });

  test('generateAndSharePdf generates PDF and shares it', () async {
    final service = ReportExportService();
    final headers = ['Category', 'Amount'];
    final data = <List<String>>[
      ['Food', '\$100.00'],
      ['Rent', '\$500.00']
    ];

    await service.generateAndSharePdf(
      title: 'Test Report',
      headers: headers,
      data: data,
      filename: 'test_report_pdf',
    );

    expect(mockShare.shareCalled, true);
  });
}
