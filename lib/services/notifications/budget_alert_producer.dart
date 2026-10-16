import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Details an overspent alert may show; only passed to [BudgetAlertText]
/// when the user opted in to amounts in notifications.
typedef BudgetAlertDetails = ({String categoryName, int overspent});

/// Title and body of an overspent alert. [details] is null unless the user
/// opted in, so the default text names neither the category nor an amount.
typedef BudgetAlertText =
    ({String title, String body}) Function(BudgetAlertDetails? details);

/// Shows the notification (NotificationService.showBudgetAlert).
typedef BudgetAlertSink =
    Future<void> Function({
      required String categoryId,
      required String title,
      required String body,
    });

/// Produces the "budget alert" notification (Settings > Notifications).
///
/// After a saved outflow, every category it touched whose available amount
/// for the current month is negative is reported, at most once per category
/// and month (remembered in [SharedPreferences]). Never throws: a failure
/// here must not fail the save.
class BudgetAlertProducer {
  BudgetAlertProducer({
    required this.prefs,
    required this.categoryAvailable,
    required this.notify,
    required this.enabled,
    bool Function()? showAmounts,
    this._categoryName,
    BudgetAlertText? text,
    DateTime Function()? now,
  }) : _showAmounts = showAmounts ?? _never,
       _text = text ?? defaultText,
       _now = now ?? DateTime.now;

  final SharedPreferences prefs;

  /// Available amount of a category up to the end of a month (minor units),
  /// e.g. BudgetingService.calculateCategoryAvailable.
  final Future<int> Function(String categoryId, DateTime month)
  categoryAvailable;
  final BudgetAlertSink notify;

  /// Settings' budget alert toggle.
  final bool Function() enabled;
  final bool Function() _showAmounts;
  final Future<String?> Function(String categoryId)? _categoryName;
  final BudgetAlertText _text;
  final DateTime Function() _now;

  static const String keyPrefix = 'budget_alert_notified_';

  static bool _never() => false;

  /// English fallback (tests); the app passes localised text.
  static ({String title, String body}) defaultText(
    BudgetAlertDetails? details,
  ) => (
    title: 'Category overspent',
    body: details == null
        ? 'A budget category is overspent this month. Tap to review your '
              'budget.'
        : '${details.categoryName} is overspent by ${details.overspent} '
              'this month.',
  );

  /// Preference key marking [categoryId] as alerted in [monthKey]
  /// (`yyyy-MM`).
  static String keyFor(String categoryId, String monthKey) =>
      '$keyPrefix$monthKey:$categoryId';

  /// Checks the categories of the rows a save wrote ([after], keyed by id)
  /// against their previous state ([before]).
  Future<void> onSaved(
    Map<String, Transaction?> before,
    Map<String, Transaction?> after,
  ) async {
    try {
      if (!enabled()) {
        return;
      }
      final month = CalendarDate.today(now: _now());
      final monthKey = CalendarDate.monthKey(month);
      final endOfMonth = CalendarDate.endOfMonthUtc(month);
      final categories = <String>{};
      for (final entry in after.entries) {
        final row = entry.value;
        if (row == null || !_isNewOutflow(before[entry.key], row)) {
          continue;
        }
        // Rows dated after this month do not change this month's available.
        if (!CalendarDate.normalize(row.date).isBefore(endOfMonth)) {
          continue;
        }
        categories.add(row.categoryId!);
      }
      if (categories.isEmpty) {
        return;
      }
      await _forgetOtherMonths(monthKey);
      for (final categoryId in categories) {
        await _check(categoryId, month, monthKey);
      }
    } catch (e, stack) {
      Logger.error('Budget alert check failed', e, stack);
    }
  }

  /// An outflow that is new to its category or more negative than before.
  static bool _isNewOutflow(Transaction? old, Transaction row) {
    if (row.isDeleted || row.categoryId == null || row.amount >= 0) {
      return false;
    }
    if (old == null || old.isDeleted || old.categoryId != row.categoryId) {
      return true;
    }
    return row.amount < old.amount || old.date != row.date;
  }

  Future<void> _check(
    String categoryId,
    DateTime month,
    String monthKey,
  ) async {
    final key = keyFor(categoryId, monthKey);
    if (prefs.getBool(key) ?? false) {
      return;
    }
    final available = await categoryAvailable(categoryId, month);
    if (available >= 0) {
      return;
    }
    BudgetAlertDetails? details;
    if (_showAmounts()) {
      final name = await _categoryName?.call(categoryId);
      if (name != null && name.isNotEmpty) {
        details = (categoryName: name, overspent: -available);
      }
    }
    final text = _text(details);
    // Remember first: a second save racing this one must not alert again.
    await prefs.setBool(key, true);
    await notify(categoryId: categoryId, title: text.title, body: text.body);
  }

  Future<void> _forgetOtherMonths(String monthKey) async {
    final current = '$keyPrefix$monthKey:';
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(keyPrefix) && !key.startsWith(current)) {
        await prefs.remove(key);
      }
    }
  }
}
