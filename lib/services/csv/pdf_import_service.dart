import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'csv_import_service.dart';

/// Represents a text line with its vertical position for sorting.
class _PositionedLine {
  final String text;
  final double y; // Top Y coordinate
  final double x; // Left X coordinate

  _PositionedLine(this.text, this.y, this.x);
}

/// Service for extracting text from PDF files using ML Kit OCR.
class PdfImportService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extracts text from a PDF file and returns structured data.
  Future<CsvImportData> extractFromPdf(String filePath) async {
    if (kIsWeb) {
      throw ImportException('PDF import is not supported on web.');
    }

    try {
      final document = await PdfDocument.openFile(filePath);
      final pageCount = document.pagesCount;

      final allLines = <_PositionedLine>[];
      double pageOffset = 0;

      // Process each page
      for (int i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);

        // Render page to image (2x scale for good OCR quality)
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );

        if (pageImage == null) continue;

        // Save image temporarily for ML Kit
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/pdf_page_$i.png');
        await tempFile.writeAsBytes(pageImage.bytes);

        // Run OCR
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        // Collect text lines WITH position data
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final boundingBox = line.boundingBox;
            if (boundingBox != null) {
              // Add page offset so multi-page PDFs sort correctly
              allLines.add(
                _PositionedLine(
                  line.text,
                  boundingBox.top + pageOffset,
                  boundingBox.left,
                ),
              );
            }
          }
        }

        // Add page height to offset for next page
        pageOffset += page.height * 2;

        // Cleanup temp file
        await tempFile.delete();
        await page.close();
      }

      await document.close();

      if (allLines.isEmpty) {
        throw ImportException(
          'No text found in PDF. The document might be image-only or protected.',
        );
      }

      // Sort lines by Y coordinate (top to bottom), then by X (left to right)
      allLines.sort((a, b) {
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) return yCompare;
        return a.x.compareTo(b.x);
      });

      // Parse using Date Anchor algorithm
      return _parseLinesWithDateAnchor(allLines);
    } catch (e) {
      if (e is ImportException) rethrow;
      throw ImportException('Failed to process PDF: $e');
    }
  }

  /// Parses lines using the "Date Anchor" algorithm.
  /// - Lines starting with a date begin a new transaction
  /// - Lines without dates are continuations of the current description
  /// - Amount-only lines complete the transaction
  CsvImportData _parseLinesWithDateAnchor(List<_PositionedLine> lines) {
    final transactions = <Map<String, String>>[];
    Map<String, String>? currentTransaction;

    // Patterns
    final datePattern = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})');
    final amountOnlyPattern = RegExp(r'^-?\d+[.,]\d{2}$');

    // Skip patterns for header/footer content
    final skipPatterns = [
      RegExp(r'^DKB$', caseSensitive: false),
      RegExp(r'Deutsche Kreditbank', caseSensitive: false),
      RegExp(r'^Date$', caseSensitive: false),
      RegExp(r'^Description$', caseSensitive: false),
      RegExp(r'^Amount$', caseSensitive: false),
      RegExp(r'Vorsitzender', caseSensitive: false),
      RegExp(r'Vorstand', caseSensitive: false),
      RegExp(r'Excerpt', caseSensitive: false),
      RegExp(r'Landesbank', caseSensitive: false),
      RegExp(r'^Seite \d', caseSensitive: false),
    ];

    debugPrint(
      'Processing ${lines.length} sorted lines with Date Anchor algorithm',
    );

    for (final posLine in lines) {
      final text = posLine.text.trim();
      if (text.isEmpty) continue;

      // Skip header/footer content
      bool shouldSkip = false;
      for (final pattern in skipPatterns) {
        if (pattern.hasMatch(text)) {
          shouldSkip = true;
          break;
        }
      }
      if (shouldSkip) continue;

      final dateMatch = datePattern.firstMatch(text);

      if (dateMatch != null) {
        // This line starts with a date - BEGIN NEW TRANSACTION
        // First, save the previous transaction if complete
        if (currentTransaction != null &&
            currentTransaction['date'] != null &&
            currentTransaction['amount'] != null) {
          transactions.add(currentTransaction);
          debugPrint(
            'Saved transaction: ${currentTransaction['date']} | ${currentTransaction['description']} | ${currentTransaction['amount']}',
          );
        }

        // Start new transaction
        final dateStr = dateMatch.group(0)!;
        final remainder = text.substring(dateMatch.end).trim();

        currentTransaction = {'date': dateStr, 'description': '', 'amount': ''};

        // Check if remainder contains amount
        final amountMatch = amountOnlyPattern.firstMatch(remainder);
        if (amountMatch != null) {
          currentTransaction['amount'] = amountMatch.group(0)!;
          final desc = remainder.replaceFirst(amountMatch.group(0)!, '').trim();
          if (desc.isNotEmpty) {
            currentTransaction['description'] = desc;
          }
        } else if (remainder.isNotEmpty) {
          currentTransaction['description'] = remainder;
        }
      } else if (amountOnlyPattern.hasMatch(text)) {
        // This is an amount-only line - COMPLETE CURRENT TRANSACTION
        if (currentTransaction != null) {
          currentTransaction['amount'] = text;
        }
      } else {
        // This is a description continuation line
        if (currentTransaction != null) {
          // Skip IBAN lines but don't add to description
          if (text.contains('IBAN') ||
              RegExp(r'^[A-Z]{2}\d{2}').hasMatch(text)) {
            continue;
          }
          // Skip transaction type lines
          if (text.toLowerCase().contains('visa debitkartenumsatz') ||
              text.toLowerCase().contains('lastschrift') ||
              text.toLowerCase().contains('dauerauftrag')) {
            continue;
          }

          // Append to description (use first line only for payee)
          if (currentTransaction['description']!.isEmpty) {
            currentTransaction['description'] = text;
          }
        }
      }
    }

    // Don't forget the last transaction
    if (currentTransaction != null &&
        currentTransaction['date'] != null &&
        currentTransaction['amount'] != null &&
        currentTransaction['amount']!.isNotEmpty) {
      transactions.add(currentTransaction);
      debugPrint(
        'Saved final transaction: ${currentTransaction['date']} | ${currentTransaction['description']} | ${currentTransaction['amount']}',
      );
    }

    debugPrint('Total transactions found: ${transactions.length}');

    if (transactions.isEmpty) {
      throw ImportException(
        'Could not detect transaction patterns in PDF. '
        'Please ensure the PDF contains bank statement data.',
      );
    }

    // Convert to rows
    final rows = transactions
        .map(
          (t) => [t['date'] ?? '', t['description'] ?? '', t['amount'] ?? ''],
        )
        .toList();

    return CsvImportData(
      headers: ['Date', 'Payee', 'Amount'],
      rows: rows,
      delimiter: ',',
    );
  }

  /// Releases resources used by the text recognizer.
  void dispose() {
    _textRecognizer.close();
  }
}
