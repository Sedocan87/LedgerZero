import 'package:ledger_zero/core/money/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:chrono_dart/chrono_dart.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

class ParsedTransaction {
  /// Parsed amount in minor units (always positive; see [isIncome]).
  final int? amount;
  final String? currency;
  final DateTime? date;
  final String? payeeName;
  final String? payeeId;
  final String? categoryId;
  final String? categoryName;
  final String? note;
  final double confidence;
  final bool isIncome;

  ParsedTransaction({
    this.amount,
    this.currency,
    this.date,
    this.payeeName,
    this.payeeId,
    this.categoryId,
    this.categoryName,
    this.note,
    this.confidence = 0.0,
    this.isIncome = false,
  });

  @override
  String toString() {
    return 'ParsedTransaction(amount: $amount, currency: $currency, date: $date, payee: $payeeName, category: $categoryName, confidence: $confidence, isIncome: $isIncome)';
  }
}

/// Parses quick-add text ("Coffee 4.50 yesterday") into a transaction
/// draft.
///
/// Order: (1) the parsing history — the payee/category the user last
/// confirmed for exactly this input (most recent entry wins); otherwise
/// (2) payee by name, (3) category from the payee's default, built-in
/// keywords or a category name. Amounts are read with [amountParser], i.e.
/// the app's active decimal separator ("1.234" is 1234.00 with a comma
/// separator and 1.234 -> 1.23 with a dot). Keywords, payee and category
/// names match whole words only (Unicode letters and digits are word
/// characters, so "bus" does not match "business" and "Café" or "Müller"
/// are words of their own).
class TransactionParser {
  final PayeeRepository _payeeRepository;
  final CategoryRepository _categoryRepository;
  final ParsingHistoryRepository _historyRepository;

  /// Reads amounts with the user's decimal separator.
  final MoneyParser amountParser;

  TransactionParser(
    this._payeeRepository,
    this._categoryRepository,
    this._historyRepository, {
    this.amountParser = const MoneyParser(),
  });

  /// Whether [text] contains [phrase] as whole word(s), ignoring case. A
  /// word boundary is any character that is not a Unicode letter, mark or
  /// digit (or the start/end of the text).
  static bool containsWord(String text, String phrase) {
    final needle = phrase.trim();
    if (needle.isEmpty) {
      return false;
    }
    return RegExp(
      '(?<![\\p{L}\\p{M}\\p{N}])${RegExp.escape(needle)}(?![\\p{L}\\p{M}\\p{N}])',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(text);
  }

  Future<ParsedTransaction> parse(String input) async {
    // 0. History: the most recent confirmation for exactly this input.
    final history = await _historyRepository.getHistory(input);
    if (history.isNotEmpty) {
      final entry = history.first;
      final payeeId = entry['payeeId'] as String?;
      final categoryId = entry['categoryId'] as String?;

      Payee? payee;
      if (payeeId != null) {
        // Try fetching payee (might be deleted?) - assuming generic fetch
        final payees = await _payeeRepository.getAllPayees();
        try {
          payee = payees.firstWhere((p) => p.id == payeeId);
        } catch (_) {}
      }

      Category? category;
      if (categoryId != null) {
        category = await _categoryRepository.getCategoryById(categoryId);
      }

      // If we found something relevant in history, combine with standard extraction for Amount/Date
      final amount = extractAmount(input);
      final currency = extractCurrency(input);
      final date = extractDate(input);

      return ParsedTransaction(
        amount: amount,
        currency: currency,
        date: date,
        payeeName: payee?.name,
        payeeId: payee?.id,
        categoryId: category?.id,
        categoryName: category?.name,
        isIncome: detectIncome(input),
        confidence: 1.0, // High confidence from history
      );
    }

    final amount = extractAmount(input);
    final currency = extractCurrency(input);
    final date = extractDate(input);

    final payeeMatch = await extractPayee(input);
    final categoryMatch = await extractCategory(input, payeeMatch);
    final isIncome = detectIncome(input);

    final confidence = calculateConfidence(
      amount,
      date,
      payeeMatch,
      categoryMatch,
    );

    return ParsedTransaction(
      amount: amount,
      currency: currency,
      date: date,
      payeeName: payeeMatch?.name,
      payeeId: payeeMatch?.id,
      categoryId: categoryMatch?.id,
      categoryName: categoryMatch?.name,
      isIncome: isIncome,
      confidence: confidence,
    );
  }

  double calculateConfidence(
    int? amount,
    DateTime? date,
    Payee? payee,
    Category? category,
  ) {
    double score = 0.0;

    // Amount is crucial for a transaction
    if (amount != null) {
      score += 0.4;
    }

    // Payee is also very important
    if (payee != null) {
      score += 0.3;
    }

    // Category adds significant value
    if (category != null) {
      score += 0.2;
    }

    // Date adds some confidence, but default (today/tomorrow) is often implicit
    if (date != null) {
      score += 0.1;
    }

    return score;
  }

  bool detectIncome(String input) {
    final lowerInput = input.toLowerCase();
    const incomeKeywords = [
      'deposit',
      'income',
      'refund',
      'salary',
      'paycheck',
      'dividend',
      'transfer in',
      // German
      'gehalt',
      'lohn',
      'einnahme',
      'erstattung',
      'dividende',
      'gutschrift',
    ];

    return incomeKeywords.any((keyword) => containsWord(lowerInput, keyword));
  }

  Future<Payee?> extractPayee(String input) async {
    // 1. Get all payees from repository
    // Note: In a real app with thousands of payees, we should optimize this
    // by only fetching names or using a trie/search index.
    // For now, we fetch all.
    final payees = await _payeeRepository.getAllPayees();

    // 2. Simple case-insensitive contains check
    // Sort by length descending to match longest payee first ("Mario's Pizza" vs "Mario")
    // Use List.of to avoid mutating the original list
    final sortedPayees = List.of(payees)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (final payee in sortedPayees) {
      if (containsWord(input, payee.name)) {
        return payee;
      }
    }

    // 3. Fuzzy matching for Payees
    final payeeNames = payees.map((p) => p.name).toList();
    final fuse = Fuzzy(payeeNames, options: FuzzyOptions(threshold: 0.3));

    final result = fuse.search(input);
    if (result.isNotEmpty) {
      final bestMatchName = result.first.item;
      return payees.firstWhere((p) => p.name == bestMatchName);
    }

    return null;
  }

  Future<Category?> extractCategory(String input, Payee? matchedPayee) async {
    // 1. If payee has a default category (auto-assign), use it.
    if (matchedPayee?.autoCategoryId != null) {
      final category = await _categoryRepository.getCategoryById(
        matchedPayee!.autoCategoryId!,
      );
      if (category != null) {
        return category;
      }
    }

    // 2. Keyword matching
    // In a real app, this map would be user-configurable or larger.
    // For now, hardcode some common mappings.
    // Keyword -> default category names (English and German seeds, see
    // defaultCategoryNames); the first one that exists is used.
    const groceries = ['Groceries', 'Lebensmittel'];
    const diningOut = ['Dining Out', 'Essen gehen'];
    const transportation = ['Transportation', 'Mobilität'];
    const entertainment = ['Entertainment', 'Freizeit'];
    final keywordMap = {
      'grocer': groceries,
      'grocery': groceries,
      'groceries': groceries,
      'supermarket': groceries,
      'food': groceries,
      'market': groceries,
      'supermarkt': groceries,
      'lebensmittel': groceries,
      'einkauf': groceries,
      'restaurant': diningOut,
      'dinner': diningOut,
      'lunch': diningOut,
      'coffee': diningOut,
      'cafe': diningOut,
      'café': diningOut,
      'kaffee': diningOut,
      'mittagessen': diningOut,
      'abendessen': diningOut,
      'uber': transportation,
      'taxi': transportation,
      'bus': transportation,
      'train': transportation,
      'gas': transportation,
      'fuel': transportation,
      'tanken': transportation,
      'benzin': transportation,
      'bahn': transportation,
      'netflix': entertainment,
      'cinema': entertainment,
      'movie': entertainment,
      'spotify': entertainment,
      'kino': entertainment,
    };

    final lowerInput = input.toLowerCase();

    // We need to fetch actual categories to match names/IDs
    // Assuming categories are fetched or we filter from a list.
    // Let's assume we can search by name or getting all categories.
    final allCategories = await _categoryRepository.getAllCategories();

    for (final entry in keywordMap.entries) {
      if (containsWord(lowerInput, entry.key)) {
        // Find category with this name
        try {
          // simple first match
          return allCategories.firstWhere((c) => entry.value.contains(c.name));
        } catch (e) {
          // Category might not exist in user's DB
        }
      }
    }

    // 3. Direct category name match (including fuzzy matching)
    // Check if input contains any category name
    // Use List.of to avoid mutating the original list
    final sortedCategories = List.of(allCategories)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    // First pass: exact substring match
    for (final category in sortedCategories) {
      if (containsWord(lowerInput, category.name)) {
        return category;
      }
    }

    // 4. Fuzzy matching on remaining words
    // Split input into words and check if any word closely resembles a category name
    // This uses the 'fuzzy' package
    final categoryNames = allCategories.map((c) => c.name).toList();
    final fuse = Fuzzy<String>(
      categoryNames,
      options: FuzzyOptions(
        threshold:
            0.3, // Lower threshold means stricter matching (0.0 is perfect match)
      ),
    );

    // The whole input first, then each word on its own (amounts and dates
    // in the input would otherwise hide a misspelt category such as
    // "Groceris 50").
    final bestMatchName = _fuzzyBest(fuse, input);
    if (bestMatchName != null) {
      return allCategories.firstWhere((c) => c.name == bestMatchName);
    }

    return null;
  }

  /// The best fuzzy match of [input], or of one of its words (letters
  /// only, at least four characters), or `null`.
  static String? _fuzzyBest(Fuzzy<String> fuse, String input) {
    final whole = fuse.search(input);
    if (whole.isNotEmpty) {
      return whole.first.item;
    }
    String? best;
    var bestScore = double.infinity;
    final words = RegExp(
      r'[\p{L}\p{M}]{4,}',
      unicode: true,
    ).allMatches(input).map((m) => m.group(0)!);
    for (final word in words) {
      final result = fuse.search(word);
      if (result.isNotEmpty && result.first.score < bestScore) {
        bestScore = result.first.score;
        best = result.first.item;
      }
    }
    return best;
  }

  DateTime? extractDate(String input) {
    final german = _germanRelativeDay(input);
    if (german != null) {
      return german;
    }
    try {
      final results = Chrono.parse(input);
      if (results.isNotEmpty) {
        return results.first.start.date();
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  /// German relative day words ("vorgestern", "gestern", "heute",
  /// "morgen"); Chrono only understands English. "heute morgen" (this
  /// morning) is today.
  DateTime? _germanRelativeDay(String input) {
    final lower = input.toLowerCase();
    bool has(String word) =>
        RegExp('(^|\\s)$word(\$|\\s|[.,!?])').hasMatch(lower);
    final int? offset;
    if (has('vorgestern')) {
      offset = -2;
    } else if (has('gestern')) {
      offset = -1;
    } else if (has('heute')) {
      offset = 0;
    } else if (has('übermorgen')) {
      offset = 2;
    } else if (has('morgen')) {
      offset = 1;
    } else {
      offset = null;
    }
    if (offset == null) {
      return null;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, 12);
  }

  /// Extracts the first amount in [input] as minor units, e.g.
  /// "$45.50" -> 4550, "12,50€" -> 1250, "1,200" -> 120000 (dot decimal
  /// separator). Ambiguous groups such as "1.234" / "1,234" are resolved
  /// with [amountParser]'s decimal separator.
  int? extractAmount(String input) {
    // Regex to match amounts while avoiding dates (YYYY-MM-DD)
    // 1. Optional currency symbol (before or after)
    // 2. Number with optional commas
    // 3. Optional decimal part
    // Examples: $45.50, 45.50, 1,200.00, .99, 50, 45€

    // Improved logic:
    // We try to exclude numbers that look like years (4 digits starting with 19 or 20 followed by dash)

    // Regex explanation:
    // Group 1: Comma separated numbers (e.g. 1,000.50)
    // Group 2: Plain numbers (e.g. 50.50 or 2023)
    // Group 3: Decimal only (e.g. .99)
    final regex = RegExp(
      r'(?:[\$€£])?\s*((?:\d{1,3}(?:,\d{3})+)(?:\.\d+)?|\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?(?!\d)|\d+[.,]\d{1,2}(?!\d)|\d+(?:\.\d+)?|\.\d+)\s*(?:[\$€£])?',
    );

    final matches = regex.allMatches(input);
    for (final match in matches) {
      // Check context to avoid parts of dates like "2023-10-15"
      // If the match is immediately followed by a dash, it's likely a year part.
      // If the match is immediately preceded by a dash, it's likely a month/day part.
      if (match.end < input.length && input[match.end] == '-') {
        continue;
      }
      if (match.start > 0 && input[match.start - 1] == '-') {
        continue;
      }

      final amountStr = match.group(1)!;
      final amount = amountParser.tryParse(amountStr);

      if (amount != null) {
        // Additional heuristic: If it's an integer 1900-2100, checking context is safer.
        // But for now, the dash check handles "2023-10-15".
        return amount;
      }
    }
    return null;
  }

  String? extractCurrency(String input) {
    final regex = RegExp(r'([\$€£])');
    final match = regex.firstMatch(input);
    return match?.group(1);
  }
}

final transactionParserProvider = Provider<TransactionParser>((ref) {
  return TransactionParser(
    ref.watch(payeeRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(parsingHistoryRepositoryProvider),
    amountParser: ref.watch(appFormatterProvider).parser,
  );
});
