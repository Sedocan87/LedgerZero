import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for extracting merchant/payee names from messy OCR text.
///
/// Uses pattern matching and NLP techniques to clean up OCR output
/// and identify the actual merchant name.
class EntityExtractor {
  /// Common patterns to remove from OCR text
  static final _removePatterns = [
    RegExp(r'IBAN\s+[A-Z]{2}\d{2}[\s\d]+', caseSensitive: false),
    RegExp(r'BIC\s+[A-Z0-9]+', caseSensitive: false),
    RegExp(r'VISA\s+Debitkartenumsatz', caseSensitive: false),
    RegExp(r'Lastschrift', caseSensitive: false),
    RegExp(r'Überweisung', caseSensitive: false),
    RegExp(r'Dauerauftrag', caseSensitive: false),
    RegExp(r'Kartenzahlung', caseSensitive: false),
    RegExp(r'\d{2}\.\d{2}\.\d{4}'), // Dates
    RegExp(r'-?\d+[.,]\d{2}(?:\s*€)?'), // Amounts
    RegExp(r'DE\d{2}\s*\d{4}\s*\d{4}\s*\d{4}\s*\d{4}\s*\d{2}'), // German IBAN
    RegExp(r'Buchung\s+\d+', caseSensitive: false),
    RegExp(r'Valuta\s+\d+', caseSensitive: false),
    RegExp(r'Referenz[:\s]+[\w\d]+', caseSensitive: false),
    RegExp(r'Mandatsreferenz[:\s]+[\w\d]+', caseSensitive: false),
    RegExp(r'Gläubiger[:\s-]+ID[:\s]+[\w\d]+', caseSensitive: false),
  ];

  /// Patterns that typically indicate merchant names
  static final _merchantIndicators = [
    RegExp(
      r'(?:bei|an|von|für)\s+(.+?)(?:\s+am|\s+vom|\s*$)',
      caseSensitive: false,
    ),
    RegExp(r'Einkauf\s+bei\s+(.+)', caseSensitive: false),
    RegExp(r'Zahlung\s+an\s+(.+)', caseSensitive: false),
  ];

  /// Words that are likely not part of merchant names
  static final _stopWords = {
    'gmbh',
    'ag',
    'kg',
    'ohg',
    'ug',
    'e.v.',
    'mbh',
    'straße',
    'str',
    'platz',
    'weg',
    'allee',
    'vielen',
    'dank',
    'danke',
    'rechnung',
    'nr',
    'deutschland',
    'germany',
    'münchen',
    'berlin',
    'hamburg',
  };

  /// Extract the best merchant name from OCR text lines.
  String? extractMerchant(List<String> lines) {
    // First, try to find a line that looks like a merchant name
    for (final line in lines) {
      final cleaned = _cleanText(line);
      if (_looksLikeMerchant(cleaned)) {
        return _normalizeMerchant(cleaned);
      }
    }

    // Try pattern matching on concatenated text
    final fullText = lines.join(' ');
    for (final pattern in _merchantIndicators) {
      final match = pattern.firstMatch(fullText);
      if (match != null && match.groupCount >= 1) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length >= 3) {
          return _normalizeMerchant(merchant);
        }
      }
    }

    // Fallback: take the first clean line that's not too short/long
    for (final line in lines) {
      final cleaned = _cleanText(line);
      if (cleaned.length >= 3 && cleaned.length <= 50) {
        if (!_isLikelyNoise(cleaned)) {
          return _normalizeMerchant(cleaned);
        }
      }
    }

    return null;
  }

  /// Clean a text line by removing known patterns.
  String _cleanText(String text) {
    var result = text.trim();

    for (final pattern in _removePatterns) {
      result = result.replaceAll(pattern, ' ');
    }

    // Remove extra whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Check if a text line looks like a merchant name.
  bool _looksLikeMerchant(String text) {
    if (text.isEmpty || text.length < 3 || text.length > 50) {
      return false;
    }

    // Should have at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      return false;
    }

    // Shouldn't be all numbers
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return false;
    }

    // Shouldn't contain too many numbers
    final digits = RegExp(r'\d').allMatches(text).length;
    if (digits > text.length / 2) {
      return false;
    }

    return true;
  }

  /// Check if text is likely noise (IBAN, dates, etc.).
  bool _isLikelyNoise(String text) {
    // Check for stopwords that indicate noise
    for (final pattern in _removePatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }

    // Too many numbers
    final digits = RegExp(r'\d').allMatches(text).length;
    if (digits > text.length * 0.5) {
      return true;
    }

    return false;
  }

  /// Normalize merchant name (title case, remove trailing indicators).
  String _normalizeMerchant(String text) {
    var result = text.trim();

    // Remove common suffixes
    result = result.replaceAll(
      RegExp(r'\s+(GmbH|AG|KG|OHG|UG|e\.V\.)$', caseSensitive: false),
      '',
    );

    // Title case for better readability
    final words = result.split(' ');
    final normalized = words
        .map((word) {
          if (word.isEmpty) return word;
          if (_stopWords.contains(word.toLowerCase())) {
            return word.toLowerCase();
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');

    return normalized.trim();
  }

  /// Extract amount from OCR text.
  double? extractAmount(String text) {
    // Pattern for German amounts: -12,34 or 1.234,56
    final patterns = [
      RegExp(r'(-?\d{1,3}(?:\.\d{3})*,\d{2})'), // German format
      RegExp(r'(-?\d+,\d{2})'), // Simple German
      RegExp(r'(-?\d{1,3}(?:,\d{3})*\.\d{2})'), // US format
      RegExp(r'(-?\d+\.\d{2})'), // Simple US
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var amountStr = match.group(1)!;
        // Normalize to decimal format
        if (amountStr.contains(',')) {
          amountStr = amountStr.replaceAll('.', '').replaceAll(',', '.');
        }
        return double.tryParse(amountStr);
      }
    }

    return null;
  }

  /// Extract date from OCR text.
  DateTime? extractDate(String text) {
    // Pattern for German dates: DD.MM.YYYY
    final pattern = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})');
    final match = pattern.firstMatch(text);

    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final year = int.tryParse(match.group(3)!);

      if (day != null && month != null && year != null) {
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }
}

/// Provider for EntityExtractor.
final entityExtractorProvider = Provider<EntityExtractor>((ref) {
  return EntityExtractor();
});
