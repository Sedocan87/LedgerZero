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

  @override
  Future<ShareResult> share(
    ShareParams params, {
    Map<String, dynamic>? data,
  }) async {
    shareCalled = true;
    return const ShareResult('success', ShareResultStatus.success);
  }

  // Not marking as @override since it might not be in the interface anymore or signature changed,
  // but keeping it if needed by logic (though ReportExportService likely calls share() via SharePlus.instance)
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
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
    SharePlatform.instance = mockShare;
    mockShare.reset();
  });

  test('shareCsv generates CSV and shares it', () async {
    final service = ReportExportService();
    final data = <List<dynamic>>[
      ['Category', 'Amount'],
      ['Food', 100.0],
      ['Rent', 500.0],
    ];

    await service.shareCsv(data, 'test_report');

    expect(mockShare.shareCalled, true);
  });

  test('generateAndSharePdf generates PDF and shares it', () async {
    final service = ReportExportService();
    final headers = ['Category', 'Amount'];
    final data = <List<String>>[
      ['Food', '\$100.00'],
      ['Rent', '\$500.00'],
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
