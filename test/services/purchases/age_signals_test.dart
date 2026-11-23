import 'dart:async';

import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/purchases/age_signals.dart';
import 'package:play_age_features/play_age_features.dart';

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

  test('a request that never answers does not hold up later taps', () async {
    final signals = FakeAgeSignals(AgeSignalsStatus.verified)
      ..gate = Completer<void>();
    final gate = AgeSignalsGate(
      signals,
      timeout: const Duration(milliseconds: 20),
    );
    expect(await gate.status(), AgeSignalsStatus.unknown);
    signals.gate = null;
    expect(await gate.status(), AgeSignalsStatus.verified);
    expect(signals.calls, 2, reason: 'the next tap asks again');
  });

  /// California AB 1043: ask for the signal at launch, but only where Play
  /// says a law makes it share the user's age.
  group('the launch check', () {
    test('asks nothing when sharing is not mandatory', () async {
      final signals = FakeAgeSignals(AgeSignalsStatus.verified);
      await AgeSignalsGate(
        signals,
        isMandatorySharing: () async => false,
      ).checkAtLaunch();
      expect(signals.calls, 0);
    });

    test('asks once when mandatory, and Buy reuses the answer', () async {
      final signals = FakeAgeSignals(AgeSignalsStatus.supervisedApprovalDenied);
      final gate = AgeSignalsGate(
        signals,
        isMandatorySharing: () async => true,
      );
      await gate.checkAtLaunch();
      expect(signals.calls, 1);
      expect(await gate.status(), AgeSignalsStatus.supervisedApprovalDenied);
      expect(signals.calls, 1);
    });

    test('a Play failure is swallowed and Buy still asks', () async {
      final signals = FakeAgeSignals(AgeSignalsStatus.verified);
      final gate = AgeSignalsGate(
        signals,
        isMandatorySharing: () async =>
            throw const PlayAgeFeaturesException(-9, 'APP_NOT_OWNED'),
      );
      await gate.checkAtLaunch();
      expect(signals.calls, 0);
      expect(await gate.status(), AgeSignalsStatus.verified);
      expect(signals.calls, 1);
    });

    test('a Buy tap during the launch check shares its request', () async {
      final signals = FakeAgeSignals(AgeSignalsStatus.verified)
        ..gate = Completer<void>();
      final gate = AgeSignalsGate(
        signals,
        isMandatorySharing: () async => true,
      );
      final launch = gate.checkAtLaunch();
      await Future<void>.delayed(Duration.zero);
      final buy = gate.status();
      signals.gate!.complete();
      await launch;
      expect(await buy, AgeSignalsStatus.verified);
      expect(signals.calls, 1);
    });
  });
}
