import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for running BERT-based NLP inference using TensorFlow Lite.
///
/// This service handles:
/// - Loading the MobileBERT TFLite model
/// - Tokenizing text input
/// - Running inference to generate text embeddings
class BertService {
  static const String _modelAsset = 'assets/models/mobilebert.tflite';
  static const String _vocabAsset = 'assets/models/vocab.txt';
  static const int _maxSeqLength = 128;
  static const int _embeddingDim = 768;

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  bool _isInitialized = false;

  /// Whether the service is ready for inference.
  bool get isReady => _isInitialized;

  /// Initialize the BERT model and tokenizer.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load vocabulary for tokenization
      _vocab = await _loadVocabulary();

      // Load TFLite model
      _interpreter = await _loadModel();

      _isInitialized = true;
      debugPrint('BertService initialized successfully');
    } catch (e) {
      debugPrint('BertService initialization failed: $e');
      rethrow;
    }
  }

  /// Load the TFLite model from assets.
  Future<Interpreter> _loadModel() async {
    try {
      // Try loading from assets
      final interpreter = await Interpreter.fromAsset(_modelAsset);
      debugPrint('Loaded BERT model from assets');
      return interpreter;
    } catch (e) {
      debugPrint('Failed to load model from assets: $e');

      // Model not bundled - would need to download
      // For now, throw a helpful error
      throw Exception(
        'BERT model not found. Please add mobilebert.tflite to assets/models/',
      );
    }
  }

  /// Load vocabulary from assets.
  Future<Map<String, int>> _loadVocabulary() async {
    try {
      final vocabString = await rootBundle.loadString(_vocabAsset);
      final lines = vocabString.split('\n');
      final vocab = <String, int>{};

      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          vocab[token] = i;
        }
      }

      debugPrint('Loaded vocabulary with ${vocab.length} tokens');
      return vocab;
    } catch (e) {
      debugPrint('Failed to load vocabulary: $e');
      // Return basic vocabulary for fallback
      return _createBasicVocab();
    }
  }

  /// Create a basic vocabulary for fallback (character-level).
  Map<String, int> _createBasicVocab() {
    final vocab = <String, int>{
      '[PAD]': 0,
      '[UNK]': 1,
      '[CLS]': 2,
      '[SEP]': 3,
      '[MASK]': 4,
    };

    // Add basic ASCII characters
    for (int i = 32; i < 127; i++) {
      vocab[String.fromCharCode(i)] = vocab.length;
    }

    return vocab;
  }

  /// Tokenize text into BERT token IDs.
  List<int> tokenize(String text) {
    if (_vocab == null) {
      throw StateError('BertService not initialized');
    }

    final tokens = <int>[_vocab!['[CLS]']!];

    // Simple whitespace tokenization with WordPiece fallback
    final words = text.toLowerCase().split(RegExp(r'\s+'));

    for (final word in words) {
      if (tokens.length >= _maxSeqLength - 1) break;

      if (_vocab!.containsKey(word)) {
        tokens.add(_vocab![word]!);
      } else {
        // Try character-level tokenization for unknown words
        for (final char in word.split('')) {
          if (tokens.length >= _maxSeqLength - 1) break;
          tokens.add(_vocab![char] ?? _vocab!['[UNK]']!);
        }
      }
    }

    tokens.add(_vocab!['[SEP]']!);

    // Pad to max sequence length
    while (tokens.length < _maxSeqLength) {
      tokens.add(_vocab!['[PAD]']!);
    }

    return tokens.sublist(0, _maxSeqLength);
  }

  /// Generate text embedding for a given text.
  /// Returns a 768-dimensional vector representing the text.
  Future<List<double>> getEmbedding(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      throw StateError('BertService interpreter not available');
    }

    final inputIds = tokenize(text);
    final attentionMask = inputIds.map((id) => id != 0 ? 1 : 0).toList();
    final tokenTypeIds = List.filled(_maxSeqLength, 0);

    // Prepare inputs
    final inputBuffer = Int32List.fromList(inputIds);
    final maskBuffer = Int32List.fromList(attentionMask);
    final typeBuffer = Int32List.fromList(tokenTypeIds);

    // Prepare output buffer
    final outputBuffer = List.generate(
      1,
      (_) => List.filled(_embeddingDim, 0.0),
    );

    // Run inference
    try {
      _interpreter!.runForMultipleInputs(
        [inputBuffer, maskBuffer, typeBuffer],
        {0: outputBuffer},
      );
    } catch (e) {
      debugPrint('Inference error: $e');
      // Fallback: return simple character-based embedding
      return _simpleEmbedding(text);
    }

    return outputBuffer[0];
  }

  /// Simple character-based embedding as fallback.
  List<double> _simpleEmbedding(String text) {
    final embedding = List.filled(_embeddingDim, 0.0);
    final normalized = text.toLowerCase();

    for (int i = 0; i < normalized.length && i < _embeddingDim; i++) {
      embedding[i] = normalized.codeUnitAt(i) / 128.0;
    }

    return embedding;
  }

  /// Calculate cosine similarity between two embeddings.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Embeddings must have same dimension');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double sqrt(double x) => x > 0 ? x.toDouble().abs() : 0.0;

  /// Dispose resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Provider for BertService singleton.
final bertServiceProvider = Provider<BertService>((ref) {
  final service = BertService();
  ref.onDispose(() => service.dispose());
  return service;
});
