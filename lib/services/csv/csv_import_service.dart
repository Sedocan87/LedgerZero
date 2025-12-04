import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class CsvImportData {
  final List<String> headers;
  final List<List<dynamic>> rows;
  final String delimiter;

  CsvImportData({
    required this.headers,
    required this.rows,
    required this.delimiter,
  });
}

class CsvImportService {
  Future<CsvImportData> parseCsvFile(PlatformFile file) async {
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      throw Exception('File content not available');
    }

    return compute(_parseCsvInternal, content);
  }

  static CsvImportData _parseCsvInternal(String content) {
    String delimiter = ',';
    // Detect EOL
    String? eol;
    if (content.contains('\r\n')) {
      eol = '\r\n';
    } else if (content.contains('\n')) {
      eol = '\n';
    } else if (content.contains('\r')) {
      eol = '\r';
    }

    // Simple heuristic: if more semicolons than commas in the first line, use semicolon
    final firstLine = content.split(RegExp(r'\r\n|\r|\n')).firstOrNull ?? '';
    if (firstLine.split(';').length > firstLine.split(',').length) {
      delimiter = ';';
    }

    // Convert CSV
    List<List<dynamic>> rawRows = const CsvToListConverter().convert(
      content,
      fieldDelimiter: delimiter,
      eol: eol,
      shouldParseNumbers: false,
    );

    if (rawRows.isEmpty) {
       return CsvImportData(headers: [], rows: [], delimiter: delimiter);
    }

    // Assume first row is header
    List<String> headers = rawRows.first.map((e) => e.toString()).toList();
    List<List<dynamic>> rows = rawRows.skip(1).toList();

    return CsvImportData(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
    );
  }
}
