import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
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

  // Exports are written to the temporary directory (and deleted after the
  // share sheet), not to Documents.
  @override
  Future<String?> getTemporaryPath() async {
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
    sharedFiles = params.files ?? [];
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
    final service = ReportExportService(
      files: ExportFileService(deferDeletion: false),
    );
    final data = <List<dynamic>>[
      ['Category', 'Amount'],
      ['Food', 100.0],
      ['Rent', 500.0],
    ];

    await service.shareCsv(data, 'test_report');

    expect(mockShare.shareCalled, true);
    // Not left behind on disk (deletion is deferred only on Android).
    expect(File(mockShare.sharedFiles.single.path).existsSync(), isFalse);
  });

  test('generateAndSharePdf generates PDF and shares it', () async {
    final service = ReportExportService();
    final headers = ['Category', 'Amount'];
    final data = <List<String>>[
      ['Food', '\$100.00'],
      ['Rent', '\$500.00'],
      // Characters outside Latin-1 need the embedded font.
      ['Lebensmittel „Bio“', '12,50 €'],
    ];

    // The pdf package prints a warning for every glyph it cannot draw.
    final printed = <String>[];
    await runZoned(
      () => service.generateAndSharePdf(
        title: 'Test Report',
        headers: headers,
        data: data,
        filename: 'test_report_pdf',
        labels: ReportPdfLabels(
          createdOn: 'Erstellt am 16.10.2026',
          footer: 'Erstellt mit LedgerZero',
          pageOf: (page, pages) => 'Seite $page von $pages',
          shareText: 'Bericht: Ausgaben – 12,50 € „Lebensmittel“',
        ),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );

    expect(mockShare.shareCalled, true);
    expect(
      printed.where((l) => l.contains('Unable to find a font')),
      isEmpty,
      reason: '€, „“ and – must be drawable',
    );
  });
}
