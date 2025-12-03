import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/reports/report_export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

class MockSharePlatform extends SharePlatform
    with MockPlatformInterfaceMixin {
  bool shareCalled = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    shareCalled = true;
    return const ShareResult('success', ShareResultStatus.success);
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSharePlatform mockShare;

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    mockShare = MockSharePlatform();
    SharePlatform.instance = mockShare;
  });

  test('exportReport generates CSV and shares it', () async {
    final service = ReportExportService();
    final data = <String, double>{'Food': 100.0, 'Rent': 500.0};

    await service.exportReport(
      type: ReportType.spendingByCategory,
      format: ExportFormat.csv,
      data: data,
      title: 'Test Report',
      csvHeaders: ['Category', 'Amount'],
    );

    expect(mockShare.shareCalled, true);

    // Verify file creation in temp dir
    final dir = Directory.systemTemp;
    final files = dir.listSync().where((f) => f.path.endsWith('.csv'));
    expect(files.isNotEmpty, true);

    final file = File(files.last.path);
    final content = await file.readAsString();
    expect(content, contains('Food,100.0'));
    expect(content, contains('Rent,500.0'));
  });

  test('exportReport throws if image bytes missing for PDF', () async {
    final service = ReportExportService();
    expect(
      () => service.exportReport(
        type: ReportType.spendingTrends,
        format: ExportFormat.pdf,
        data: {},
        title: 'Test',
      ),
      throwsArgumentError,
    );
  });
}
