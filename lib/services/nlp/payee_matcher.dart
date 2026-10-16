import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:ledger_zero/core/utils/logger.dart';
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
        Logger.debug(
          'PayeeMatcher: built cache with ${_payeeCache!.length} payees',
        );
      }
    } catch (e, st) {
      Logger.error('PayeeMatcher: failed to build cache', e, st);
    }
  }

  /// Get top N suggested matches for a given name.
  /// Returns list of (Payee, similarity score) pairs.
  Future<List<(Payee, double)>> getSuggestions(
    String payeeName, {
    int limit = 5,
  }) async {
    if (payeeName.isEmpty) {
      return [];
    }

    try {
      await _ensureCache();

      if (_fuzzyMatcher == null) {
        return [];
      }

      final results = _fuzzyMatcher!.search(payeeName);

      // Convert fuzzy scores to similarity (1 - score, since lower is better in fuzzy)
      return results.take(limit).map((r) => (r.item, 1.0 - r.score)).toList();
    } catch (e, st) {
      Logger.error('PayeeMatcher: failed to get suggestions', e, st);
      return [];
    }
  }

  /// Ensure cache is built before performing operations.
  Future<void> _ensureCache() async {
    if (_payeeCache == null || _fuzzyMatcher == null) {
      await buildCache();
    }
  }

  /// Drops the cache; the next lookup rebuilds it from the repository.
  void clearCache() {
    _payeeCache = null;
    _fuzzyMatcher = null;
  }
}

/// The app's [PayeeMatcher]. Its cache is cleared whenever the payees table
/// changes (created, renamed, merged or deleted payees).
final payeeMatcherProvider = Provider<PayeeMatcher>((ref) {
  final repository = ref.watch(payeeRepositoryProvider);
  final matcher = PayeeMatcher(repository);
  final subscription = repository.watchAllPayees().listen(
    (_) => matcher.clearCache(),
    onError: (Object _) => matcher.clearCache(),
  );
  ref.onDispose(subscription.cancel);
  return matcher;
});
