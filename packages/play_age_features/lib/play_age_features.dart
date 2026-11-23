/// Asks Google Play which age features apply to the current user.
///
/// Wraps `AgeSignalsManager.getApplicableAgeFeatures()` from
/// `com.google.android.play:age-signals` 0.0.6, which `age_range_signals`
/// (pinned to 0.0.4) doesn't expose yet. Android only: on every other
/// platform the answer is "no features".
///
/// When `age_range_signals` adds this, switch to it and delete this package
/// (see AGE_SIGNALS_CALIFORNIA.md in the Coding folder).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Features Google Play reports for the current user.
enum ApplicableAgeFeature {
  /// The user is in a region whose law makes the store share age information
  /// (for example California and Brazil from January 2027). Reading the
  /// signal won't show Play's "share your age?" sheet to these users in US
  /// states; they verify in the Play Store app instead.
  mandatorySharing,
}

/// A Play library failure. [code] is Play's `AgeSignalsErrorCode` value
/// (for example -9 `APP_NOT_OWNED` for a build not installed from Play,
/// -11 `DEVICE_NOT_SUPPORTED`), or null when the failure isn't from Play.
class PlayAgeFeaturesException implements Exception {
  const PlayAgeFeaturesException(this.code, this.message);

  final int? code;
  final String? message;

  @override
  String toString() => 'PlayAgeFeaturesException($code, $message)';
}

class PlayAgeFeatures {
  PlayAgeFeatures._();

  @visibleForTesting
  static const channel = MethodChannel('com.reinlogic/play_age_features');

  /// Play's `ApplicableAgeFeature.MANDATORY_SHARING`.
  static const _mandatorySharing = 1;

  /// The features Play reports for the current user; empty when none apply
  /// or off Android. Throws [PlayAgeFeaturesException] when Play fails.
  /// Unknown feature values from a newer library are ignored.
  static Future<Set<ApplicableAgeFeature>> getApplicableAgeFeatures() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const {};
    }
    final List<Object?>? values;
    try {
      values = await channel.invokeListMethod<Object?>(
        'getApplicableAgeFeatures',
      );
    } on PlatformException catch (e) {
      throw PlayAgeFeaturesException(int.tryParse(e.code), e.message);
    }
    return {
      for (final value in values ?? const [])
        if (value == _mandatorySharing) ApplicableAgeFeature.mandatorySharing,
    };
  }

  /// Whether a law makes Play share this user's age (California, Brazil, …).
  /// Throws [PlayAgeFeaturesException] when Play fails.
  static Future<bool> isMandatorySharing() async =>
      (await getApplicableAgeFeatures()).contains(
        ApplicableAgeFeature.mandatorySharing,
      );
}
