import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/nlp/bert_service.dart';

/// Service for predicting transaction categories using text embeddings.
///
/// Learns from user's historical categorization patterns and suggests
/// categories for new transactions based on description/payee text.
class CategoryPredictor {
  final BertService _bertService;
  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;

  // Cache of category embeddings built from historical data
  final Map<String, List<double>> _categoryEmbeddings = {};
  bool _modelTrained = false;

  CategoryPredictor(
    this._bertService,
    this._categoryRepository,
    this._transactionRepository,
  );

  /// Minimum confidence to return a prediction (0.5 = 50%)
  static const double minConfidence = 0.5;

  /// Train the category model from user's historical transactions.
  Future<void> train() async {
    if (_modelTrained) return;

    try {
      await _bertService.initialize();

      // Get all transactions with categories
      final transactions = await _transactionRepository.getAllTransactions();

      // Group transaction descriptions by category
      final categoryTexts = <String, List<String>>{};

      for (final tx in transactions) {
        if (tx.categoryId == null) continue;

        // Build text from payee + memo
        String text = '';
        // We don't have payee name directly, but we can use memo or other info
        if (tx.memo != null && tx.memo!.isNotEmpty) {
          text = tx.memo!;
        }

        if (text.isEmpty) continue;

        categoryTexts.putIfAbsent(tx.categoryId!, () => []).add(text);
      }

      // Build average embedding for each category
      for (final entry in categoryTexts.entries) {
        if (entry.value.length < 2) continue; // Need at least 2 examples

        final embeddings = <List<double>>[];

        for (final text in entry.value.take(10)) {
          // Limit to 10 samples
          final embedding = await _bertService.getEmbedding(text);
          embeddings.add(embedding);
        }

        if (embeddings.isNotEmpty) {
          _categoryEmbeddings[entry.key] = _averageEmbedding(embeddings);
        }
      }

      _modelTrained = true;
      debugPrint(
        'CategoryPredictor: Trained with ${_categoryEmbeddings.length} categories',
      );
    } catch (e) {
      debugPrint('CategoryPredictor: Training failed: $e');
    }
  }

  /// Calculate average of multiple embeddings.
  List<double> _averageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];

    final dim = embeddings.first.length;
    final result = List.filled(dim, 0.0);

    for (final emb in embeddings) {
      for (int i = 0; i < dim; i++) {
        result[i] += emb[i];
      }
    }

    for (int i = 0; i < dim; i++) {
      result[i] /= embeddings.length;
    }

    return result;
  }

  /// Predict the most likely category for a given text.
  /// Returns (Category, confidence) or null if no prediction.
  Future<(Category, double)?> predict(String text) async {
    if (text.isEmpty) return null;

    try {
      await train();

      if (_categoryEmbeddings.isEmpty) {
        return null; // No training data
      }

      final inputEmbedding = await _bertService.getEmbedding(text);

      final categories = await _categoryRepository.getAllCategories();
      final categoryMap = {for (var c in categories) c.id: c};

      Category? bestCategory;
      double bestScore = 0.0;

      for (final entry in _categoryEmbeddings.entries) {
        final similarity = _bertService.cosineSimilarity(
          inputEmbedding,
          entry.value,
        );

        if (similarity > bestScore && similarity >= minConfidence) {
          bestScore = similarity;
          bestCategory = categoryMap[entry.key];
        }
      }

      if (bestCategory != null) {
        debugPrint(
          'CategoryPredictor: Predicted "${bestCategory.name}" with score $bestScore',
        );
        return (bestCategory, bestScore);
      }

      return null;
    } catch (e) {
      debugPrint('CategoryPredictor: Prediction failed: $e');
      return null;
    }
  }

  /// Get top N category suggestions for a given text.
  Future<List<(Category, double)>> getSuggestions(
    String text, {
    int limit = 3,
  }) async {
    if (text.isEmpty) return [];

    try {
      await train();

      if (_categoryEmbeddings.isEmpty) {
        return [];
      }

      final inputEmbedding = await _bertService.getEmbedding(text);

      final categories = await _categoryRepository.getAllCategories();
      final categoryMap = {for (var c in categories) c.id: c};

      final scores = <(Category, double)>[];

      for (final entry in _categoryEmbeddings.entries) {
        final category = categoryMap[entry.key];
        if (category == null) continue;

        final similarity = _bertService.cosineSimilarity(
          inputEmbedding,
          entry.value,
        );

        if (similarity >= minConfidence) {
          scores.add((category, similarity));
        }
      }

      scores.sort((a, b) => b.$2.compareTo(a.$2));

      return scores.take(limit).toList();
    } catch (e) {
      debugPrint('CategoryPredictor: Suggestions failed: $e');
      return [];
    }
  }

  /// Clear training data (call when categories change).
  void reset() {
    _categoryEmbeddings.clear();
    _modelTrained = false;
  }
}

/// Provider for CategoryPredictor.
final categoryPredictorProvider = Provider<CategoryPredictor>((ref) {
  return CategoryPredictor(
    ref.watch(bertServiceProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
  );
});
