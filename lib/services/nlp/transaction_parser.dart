import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_rules_repository.dart';
import 'package:chrono_dart/chrono_dart.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

class ParsedTransaction {
  final double? amount;
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

class TransactionParser {
  final PayeeRepository _payeeRepository;
  final CategoryRepository _categoryRepository;
  final ParsingHistoryRepository _historyRepository;
  final ParsingRulesRepository _rulesRepository;

  TransactionParser(
    this._payeeRepository,
    this._categoryRepository,
    this._historyRepository,
    this._rulesRepository,
  );

  Future<ParsedTransaction> parse(String input) async {
    // 0. Check History
    final history = await _historyRepository.getHistory(input);
    if (history.isNotEmpty) {
      final entry = history.first; // Use most recent match logic if multiple?
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

    // 1. Rules Logic
    final rules = await _rulesRepository.getAllRules();
    for (final rule in rules) {
      final keyword = rule['keyword'] as String;
      if (input.toLowerCase().contains(keyword.toLowerCase())) {
        final payeeId = rule['payeeId'] as String?;
        final categoryId = rule['categoryId'] as String?;

        Payee? payee;
        if (payeeId != null) {
          final payees = await _payeeRepository.getAllPayees();
          try {
            payee = payees.firstWhere((p) => p.id == payeeId);
          } catch (_) {}
        }

        Category? category;
        if (categoryId != null) {
          category = await _categoryRepository.getCategoryById(categoryId);
        }

        if (payee != null || category != null) {
          return ParsedTransaction(
            amount: amount,
            currency: currency,
            date: date,
            payeeName: payee?.name,
            payeeId: payee?.id,
            categoryId: category?.id,
            categoryName: category?.name,
            isIncome: detectIncome(input),
            confidence: 0.9, // High confidence from rule
          );
        }
      }
    }

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
    double? amount,
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
    ];

    for (final keyword in incomeKeywords) {
      if (lowerInput.contains(keyword)) {
        return true;
      }
    }
    return false;
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

    final lowerInput = input.toLowerCase();
    for (final payee in sortedPayees) {
      if (lowerInput.contains(payee.name.toLowerCase())) {
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
    final keywordMap = {
      'grocer': 'Groceries',
      'supermarket': 'Groceries',
      'food': 'Groceries',
      'market': 'Groceries',
      'restaurant': 'Dining Out',
      'dinner': 'Dining Out',
      'lunch': 'Dining Out',
      'coffee': 'Dining Out',
      'cafe': 'Dining Out',
      'uber': 'Transportation',
      'taxi': 'Transportation',
      'bus': 'Transportation',
      'train': 'Transportation',
      'gas': 'Transportation',
      'fuel': 'Transportation',
      'netflix': 'Entertainment',
      'cinema': 'Entertainment',
      'movie': 'Entertainment',
      'spotify': 'Entertainment',
    };

    final lowerInput = input.toLowerCase();

    // We need to fetch actual categories to match names/IDs
    // Assuming categories are fetched or we filter from a list.
    // Let's assume we can search by name or getting all categories.
    final allCategories = await _categoryRepository.getAllCategories();

    for (final entry in keywordMap.entries) {
      if (lowerInput.contains(entry.key)) {
        // Find category with this name
        try {
          // simple first match
          return allCategories.firstWhere((c) => c.name == entry.value);
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
      if (lowerInput.contains(category.name.toLowerCase())) {
        return category;
      }
    }

    // 4. Fuzzy matching on remaining words
    // Split input into words and check if any word closely resembles a category name
    // This uses the 'fuzzy' package
    final categoryNames = allCategories.map((c) => c.name).toList();
    final fuse = Fuzzy(
      categoryNames,
      options: FuzzyOptions(
        threshold:
            0.3, // Lower threshold means stricter matching (0.0 is perfect match)
      ),
    );

    // We try to fuzzy match chunks of text.
    // Since categories are usually 1-2 words, we can search the whole input against categories.
    // However, the input contains date/amount which might confuse fuzzy search.
    // For now, let's just run fuzzy search on the input against category names.
    final result = fuse.search(input);
    if (result.isNotEmpty) {
      // Return the best match
      final bestMatchName = result.first.item;
      return allCategories.firstWhere((c) => c.name == bestMatchName);
    }

    return null;
  }

  DateTime? extractDate(String input) {
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

  double? extractAmount(String input) {
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
      r'(?:[\$€£])?\s*((?:\d{1,3}(?:,\d{3})+)(?:\.\d+)?|\d+(?:\.\d+)?|\.\d+)\s*(?:[\$€£])?',
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

      String amountStr = match.group(1)!;
      // Remove commas
      amountStr = amountStr.replaceAll(',', '');

      final amount = double.tryParse(amountStr);

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
    ref.watch(parsingRulesRepositoryProvider),
  );
});
