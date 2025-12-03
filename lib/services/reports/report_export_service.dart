import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';

enum ReportType {
  spendingTrends,
  spendingByCategory,
  categoryBreakdown,
  incomeVsExpense,
  netWorth,
  topPayees,
}

enum ExportFormat {
  csv,
  pdf,
  image,
}

class ReportExportService {
  Future<void> exportReport({
    required ReportType type,
    required ExportFormat format,
    required dynamic data, // Map, List, etc.
    Uint8List? imageBytes, // For PDF/Image
    List<String>? csvHeaders,
    required String title,
  }) async {
    final filename = '${type.name}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    File? file;

    switch (format) {
      case ExportFormat.csv:
        if (csvHeaders == null) {
          throw ArgumentError('csvHeaders required for CSV export');
        }
        file = await _generateCsv(type, data, filename, csvHeaders);
        break;
      case ExportFormat.pdf:
        if (imageBytes == null) {
          throw ArgumentError('Image bytes required for PDF export');
        }
        file = await _generatePdf(title, imageBytes, filename);
        break;
      case ExportFormat.image:
        if (imageBytes == null) {
          throw ArgumentError('Image bytes required for Image export');
        }
        file = await _generateImage(imageBytes, filename);
        break;
    }

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Report: $title');
  }

  Future<File> _generateCsv(ReportType type, dynamic data, String filename, List<String> headers) async {
    final rows = <List<dynamic>>[];

    // Add Header
    rows.add(headers);

    switch (type) {
      case ReportType.spendingTrends:
        final map = data as Map<DateTime, double>;
        final sortedKeys = map.keys.toList()..sort();
        for (var key in sortedKeys) {
          rows.add([DateFormat('yyyy-MM-dd').format(key), map[key]]);
        }
        break;
      case ReportType.spendingByCategory:
      case ReportType.categoryBreakdown: // Both use Map<String, double>
        final map = data as Map<String, double>;
        final sortedKeys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
        for (var key in sortedKeys) {
          rows.add([key, map[key]]);
        }
        break;
      case ReportType.incomeVsExpense:
      case ReportType.netWorth:
         // List<ChartSeries>
         final list = data as List<ChartSeries>;
         for (var series in list) {
           for (var point in series.points) {
             rows.add([series.name, DateFormat('yyyy-MM-dd').format(point.date), point.value]);
           }
         }
         break;
      case ReportType.topPayees:
         final list = data as List<MapEntry<String, double>>;
         for (var entry in list) {
           rows.add([entry.key, entry.value]);
         }
         break;
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<File> _generatePdf(String title, Uint8List imageBytes, String filename) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Image(image),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _generateImage(Uint8List imageBytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename.png');
    await file.writeAsBytes(imageBytes);
    return file;
  }
}
