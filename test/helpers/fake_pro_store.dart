import 'dart:async';

import 'package:ledger_zero/services/purchases/pro_store.dart';

/// A Google Play stand-in: tests set what it answers and push purchase
/// updates by hand.
class FakeProStore implements ProStore {
  FakeProStore({
    this.available = true,
    this.ownedAnswer = false,
    this.priceText = '€14.99',
  });

  bool available;

  /// What [owned] answers (null: the store could not answer).
  bool? ownedAnswer;
  String? priceText;

  /// What [buy] returns (false: the sheet could not be opened).
  bool opens = true;
  int buyCalls = 0;
  int ownedCalls = 0;

  final _updates = StreamController<ProPurchaseUpdate>.broadcast();

  void push(ProPurchaseStatus status) =>
      _updates.add(ProPurchaseUpdate(status));

  @override
  Stream<ProPurchaseUpdate> get updates => _updates.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> price() async => priceText;

  @override
  Future<bool> buy() async {
    buyCalls++;
    return opens;
  }

  @override
  Future<bool?> owned() async {
    ownedCalls++;
    return ownedAnswer;
  }

  @override
  void dispose() => unawaited(_updates.close());
}
