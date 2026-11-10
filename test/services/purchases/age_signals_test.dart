import 'dart:async';

import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/purchases/age_signals.dart';

import '../../helpers/fake_age_signals.dart';

void main() {
  test('only a pending or denied parent approval blocks purchases', () {
    const blocking = {
      AgeSignalsStatus.supervisedApprovalPending,
      AgeSignalsStatus.supervisedApprovalDenied,
    };
    for (final s in AgeSignalsStatus.values) {
      expect(blocksPurchases(s), blocking.contains(s), reason: '$s');
    }
    expect(blocksPurchases(null), isFalse);
  });

  test('the answer is asked once and kept for the session', () async {
    final signals = FakeAgeSignals(AgeSignalsStatus.supervised);
    final gate = AgeSignalsGate(signals);
    expect(await gate.status(), AgeSignalsStatus.supervised);
    expect(await gate.status(), AgeSignalsStatus.supervised);
    expect(signals.calls, 1);
  });

  test('two taps at once share one request', () async {
    final signals = FakeAgeSignals(AgeSignalsStatus.verified)
      ..gate = Completer<void>();
    final gate = AgeSignalsGate(signals);
    final first = gate.status();
    final second = gate.status();
    signals.gate!.complete();
    expect(await first, AgeSignalsStatus.verified);
    expect(await second, AgeSignalsStatus.verified);
    expect(signals.calls, 1);
  });

  test('an error counts as unknown and is not kept: the next tap asks '
      'again', () async {
    final signals = FakeAgeSignals(AgeSignalsStatus.supervisedApprovalDenied)
      ..error = Exception('no Play');
    final gate = AgeSignalsGate(signals);
    expect(await gate.status(), AgeSignalsStatus.unknown);
    signals.error = null;
    expect(await gate.status(), AgeSignalsStatus.supervisedApprovalDenied);
    expect(signals.calls, 2);
  });

  test(
    'a timeout counts as unknown; an answer that comes later is kept',
    () async {
      final signals = FakeAgeSignals(AgeSignalsStatus.supervisedApprovalPending)
        ..gate = Completer<void>();
      final gate = AgeSignalsGate(
        signals,
        timeout: const Duration(milliseconds: 20),
      );
      expect(await gate.status(), AgeSignalsStatus.unknown);
      signals.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(await gate.status(), AgeSignalsStatus.supervisedApprovalPending);
      expect(signals.calls, 1);
    },
  );
}
