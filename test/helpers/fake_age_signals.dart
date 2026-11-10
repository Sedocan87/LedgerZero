import 'dart:async';

import 'package:age_range_signals/age_range_signals.dart';
import 'package:ledger_zero/services/purchases/age_signals.dart';

/// The store's age answer, set by the test.
class FakeAgeSignals implements AgeSignals {
  FakeAgeSignals([this.answer = AgeSignalsStatus.unknown]);

  AgeSignalsStatus answer;

  /// Thrown instead of answering.
  Object? error;

  /// Holds the answer back until completed.
  Completer<void>? gate;

  int calls = 0;

  @override
  Future<AgeSignalsStatus> status() async {
    calls++;
    final g = gate;
    if (g != null) {
      await g.future;
    }
    final e = error;
    if (e != null) {
      throw e;
    }
    return answer;
  }
}
