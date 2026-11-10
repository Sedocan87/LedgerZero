import 'package:flutter/services.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The store's rating dialog and listing.
abstract interface class ReviewClient {
  /// Whether the in-app rating dialog can be shown (Google Play installed).
  Future<bool> isAvailable();

  /// Asks Google Play to show its rating dialog. Play decides whether it
  /// appears (it has its own quota) and never tells the app.
  Future<void> requestReview();

  /// Opens the app's page in the Play Store.
  Future<void> openStoreListing();
}

/// Google Play's In-App Review API, through the app's own channel
/// (android/app/src/main/kotlin/com/ledgerzero/app/ReviewChannel.kt; the
/// in_app_review plugin does not build with AGP 9).
class PlayReviewClient implements ReviewClient {
  const PlayReviewClient();

  static const MethodChannel _channel = MethodChannel(
    'com.ledgerzero.app/review',
  );

  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<void> requestReview() => _channel.invokeMethod<void>('requestReview');

  @override
  Future<void> openStoreListing() async {
    if (await _channel.invokeMethod<bool>('openStoreListing') != true) {
      throw StateError('No app could open the Play Store page');
    }
  }
}

/// When to ask for a rating: never at the start, only after real use and
/// right after a good moment (the user has just given every euro a place),
/// and rarely.
///
/// * at least [minDaysInstalled] days since the first start and
///   [minActiveDays] days on which the app was opened;
/// * at most [maxAsks] times, at least [minDaysBetween] days apart.
class ReviewPrompter {
  ReviewPrompter({
    required this._prefs,
    required this._client,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int minDaysInstalled = 7;
  static const int minActiveDays = 5;
  static const int maxAsks = 3;
  static const int minDaysBetween = 120;

  static const String firstSeenKey = 'review_first_seen';
  static const String activeDaysKey = 'review_active_days';
  static const String lastActiveDayKey = 'review_last_active_day';
  static const String lastAskedKey = 'review_last_asked';
  static const String askCountKey = 'review_ask_count';

  final SharedPreferences _prefs;
  final ReviewClient _client;
  final DateTime Function() _clock;

  /// Counts today as a day the app was used (call at start and resume).
  Future<void> recordActiveDay() async {
    final now = _clock();
    if (_prefs.getInt(firstSeenKey) == null) {
      await _prefs.setInt(firstSeenKey, now.millisecondsSinceEpoch);
    }
    final today = '${now.year}-${now.month}-${now.day}';
    if (_prefs.getString(lastActiveDayKey) == today) {
      return;
    }
    await _prefs.setString(lastActiveDayKey, today);
    await _prefs.setInt(activeDaysKey, (_prefs.getInt(activeDaysKey) ?? 0) + 1);
  }

  /// Whether a good moment now would lead to the rating dialog.
  bool get isDue {
    final firstSeen = _prefs.getInt(firstSeenKey);
    if (firstSeen == null) {
      return false;
    }
    final now = _clock();
    final installed = now.difference(
      DateTime.fromMillisecondsSinceEpoch(firstSeen),
    );
    if (installed.inDays < minDaysInstalled ||
        (_prefs.getInt(activeDaysKey) ?? 0) < minActiveDays ||
        (_prefs.getInt(askCountKey) ?? 0) >= maxAsks) {
      return false;
    }
    final lastAsked = _prefs.getInt(lastAskedKey);
    return lastAsked == null ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastAsked)).inDays >=
            minDaysBetween;
  }

  /// A good moment: shows Google Play's rating dialog if it is due. Returns
  /// whether it was asked for. Never throws.
  Future<bool> goodMoment() async {
    if (!isDue) {
      return false;
    }
    try {
      if (!await _client.isAvailable()) {
        return false;
      }
      await _prefs.setInt(lastAskedKey, _clock().millisecondsSinceEpoch);
      await _prefs.setInt(askCountKey, (_prefs.getInt(askCountKey) ?? 0) + 1);
      await _client.requestReview();
      return true;
    } catch (e) {
      Logger.warning('In-app review failed: $e');
      return false;
    }
  }

  /// "Rate LedgerZero" in Settings: the Play Store page. Never throws;
  /// false when it could not be opened.
  Future<bool> openStoreListing() async {
    try {
      await _client.openStoreListing();
      return true;
    } catch (e) {
      Logger.warning('Opening the Play Store listing failed: $e');
      return false;
    }
  }
}

/// No store to rate in (tests, platforms without Google Play).
class NoReviewClient implements ReviewClient {
  const NoReviewClient();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing() async =>
      throw UnsupportedError('No store on this platform');
}
