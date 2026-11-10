import 'dart:async';
import 'dart:io' show Platform;

import 'package:age_range_signals/age_range_signals.dart';
import 'package:ledger_zero/core/utils/logger.dart';

/// The user's age status from Google Play Age Signals (or, on iOS, Apple's
/// Declared Age Range); faked in tests. The stores' terms allow using it
/// only for an age-appropriate experience: here, whether Pro may be bought.
abstract interface class AgeSignals {
  /// `unknown` when the store has no answer: the user did not share it, Play
  /// is missing, the app was not installed from Play, the region is not
  /// covered, or Apple does not require the check. Throws when the store
  /// cannot be asked.
  Future<AgeSignalsStatus> status();
}

/// Whether buying Pro is refused for [status]: only while a parent or
/// guardian has not approved (`supervisedApprovalPending`) or has declined
/// (`supervisedApprovalDenied`) the app's latest significant change. Texas
/// SB 2420 §121.053(b) counts "new monetization features … including new
/// purchase opportunities" as such a change, and Play does not take the app
/// away while approval is missing, so the app holds purchases back itself.
///
/// `supervised` alone means only that the reported age is below the age
/// gate (18; age_range_signals 0.8.0+), a 17-year-old with their own
/// account too: purchases on such accounts go through Google Play's own
/// parental approval (Family Link), which arrives as a pending purchase.
/// Restoring is never blocked: it buys nothing.
bool blocksPurchases(AgeSignalsStatus? status) => switch (status) {
  AgeSignalsStatus.supervisedApprovalPending ||
  AgeSignalsStatus.supervisedApprovalDenied => true,
  _ => false,
};

/// How long Buy waits for the store's answer before it goes on as
/// `unknown`, so a slow store, or a sharing sheet left open, never holds up
/// a purchase.
const Duration ageSignalsTimeout = Duration(seconds: 6);

/// The age status checked before Pro is bought. Asked at the first tap on
/// Buy in a session, never at launch: buying Pro is the only thing in
/// LedgerZero that depends on age, Texas §121.054 sets no timeline for the
/// check, and Play may show its age-sharing sheet, which belongs in front
/// of a user who asked to buy. The answer is kept in memory for the session
/// and never written, logged or sent anywhere (Texas §121.055(b): delete it
/// after the check). A timeout or an error counts as `unknown` and is not
/// kept, so the next tap asks again; an answer that arrives after the
/// timeout is kept.
final class AgeSignalsGate {
  AgeSignalsGate(this._signals, {this.timeout = ageSignalsTimeout});

  final AgeSignals _signals;
  final Duration timeout;

  AgeSignalsStatus? _known;

  /// The request in flight; a second tap waits for the same one.
  Future<AgeSignalsStatus>? _asking;

  Future<AgeSignalsStatus> status() async {
    if (_known case final known?) {
      return known;
    }
    try {
      final asking = _asking ??= _signals
          .status()
          .then((status) => _known = status)
          .whenComplete(() => _asking = null);
      return await asking.timeout(timeout);
    } on Object catch (e) {
      // Not the status itself: only that there was none.
      Logger.warning('Age signals unavailable: ${e.runtimeType}');
      return AgeSignalsStatus.unknown;
    }
  }
}

/// Play Age Signals on Android. On iOS, Apple's Declared Age Range, only
/// for users Apple says must share their age range (iOS 26.4+), so nobody
/// else gets the system sheet; without the Declared Age Range entitlement
/// (not set up: LedgerZero ships on Android only) the call throws, which
/// counts as `unknown`.
final class StoreAgeSignals implements AgeSignals {
  StoreAgeSignals();

  AgeRangeSignals get _signals => AgeRangeSignals.instance;

  @override
  Future<AgeSignalsStatus> status() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return AgeSignalsStatus.unknown;
    }
    // One gate: `verified` means 18 or older (the Texas age). Apple wants
    // gates at least 2 years apart; one is fine.
    await _signals.initialize(ageGates: const [18]);
    if (Platform.isIOS) {
      Set<AgeRegulatoryFeature> required;
      try {
        required = await _signals.getRequiredRegulatoryFeatures();
      } on UnsupportedPlatformException {
        required = const {}; // Below iOS 26.4 Apple cannot say: don't ask.
      }
      if (!required.contains(AgeRegulatoryFeature.declaredAgeRangeRequired)) {
        return AgeSignalsStatus.unknown;
      }
    }
    // May show Play's age-sharing sheet; on iOS, Apple asks inside the
    // check itself.
    final access = await _signals.requestAgeSignalsAccess();
    if (access != AgeSignalsAccessStatus.shared) {
      return AgeSignalsStatus.unknown;
    }
    return (await _signals.checkAgeSignals()).status;
  }
}
