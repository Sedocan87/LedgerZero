import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

/// Service for fuzzy payee name matching using the fuzzy package.
///
/// Compares new payee names against existing payees to find matches
/// even when names are slightly different (e.g., "EDEKA Munich" vs "EDEKA M").
class PayeeMatcher {
  final PayeeRepository _payeeRepository;

  // Cache of payees for faster matching
  List<Payee>? _payeeCache;
  Fuzzy<Payee>? _fuzzyMatcher;

  PayeeMatcher(this._payeeRepository);

  /// Threshold for considering a match (0.0 = exact, 1.0 = any)
  /// Lower is stricter. Using 0.3 for good balance.
  static const double matchThreshold = 0.3;

  /// Threshold for suggestions (more lenient)
  static const double suggestThreshold = 0.5;

  /// Build the cache of payees for fuzzy matching.
  Future<void> buildCache() async {
    try {
      _payeeCache = await _payeeRepository.getAllPayees();

      if (_payeeCache != null && _payeeCache!.isNotEmpty) {
        _fuzzyMatcher = Fuzzy<Payee>(
          _payeeCache!,
          options: FuzzyOptions(
            keys: [
              WeightedKey(
                name: 'name',
                getter: (payee) => payee.name,
                weight: 1.0,
              ),
            ],
            threshold: suggestThreshold,
            findAllMatches: true,
            tokenize: true,
            matchAllTokens: false,
          ),
        );
        debugPrint(
          'PayeeMatcher: Built cache with ${_payeeCache!.length} payees',
        );
      }
    } catch (e) {
      debugPrint('PayeeMatcher: Failed to build cache: $e');
    }
  }

  /// Find the best matching payee for a given name.
  /// Returns the matching payee if similarity is good enough, null otherwise.
  Future<Payee?> findBestMatch(String payeeName) async {
    if (payeeName.isEmpty) return null;

    try {
      await _ensureCache();

      if (_fuzzyMatcher == null) return null;

      final results = _fuzzyMatcher!.search(payeeName);

      if (results.isNotEmpty && results.first.score <= matchThreshold) {
        final bestMatch = results.first.item;
        debugPrint(
          'PayeeMatcher: Found match "${bestMatch.name}" with score ${results.first.score}',
        );
        return bestMatch;
      }

      return null;
    } catch (e) {
      debugPrint('PayeeMatcher: Error finding match: $e');
      return null;
    }
  }

  /// Get top N suggested matches for a given name.
  /// Returns list of (Payee, similarity score) pairs.
  Future<List<(Payee, double)>> getSuggestions(
    String payeeName, {
    int limit = 5,
  }) async {
    if (payeeName.isEmpty) return [];

    try {
      await _ensureCache();

      if (_fuzzyMatcher == null) return [];

      final results = _fuzzyMatcher!.search(payeeName);

      // Convert fuzzy scores to similarity (1 - score, since lower is better in fuzzy)
      return results.take(limit).map((r) => (r.item, 1.0 - r.score)).toList();
    } catch (e) {
      debugPrint('PayeeMatcher: Error getting suggestions: $e');
      return [];
    }
  }

  /// Ensure cache is built before performing operations.
  Future<void> _ensureCache() async {
    if (_payeeCache == null || _fuzzyMatcher == null) {
      await buildCache();
    }
  }

  /// Clear the cache (call when payee data changes).
  void clearCache() {
    _payeeCache = null;
    _fuzzyMatcher = null;
  }

  /// Add a new payee to the cache.
  void invalidateCache() {
    clearCache();
  }
}

/// Provider for PayeeMatcher.
final payeeMatcherProvider = Provider<PayeeMatcher>((ref) {
  return PayeeMatcher(ref.watch(payeeRepositoryProvider));
});
