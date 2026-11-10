import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where "Fill new months automatically" takes the amounts from.
enum AutoFillSource { off, previousMonth, template }

/// A month the automatic fill wrote, shown on the budget screen until the
/// user dismisses or undoes it.
class AutoFillNote {
  /// First day of the month (UTC).
  final DateTime month;

  /// Category id -> amount written (minor units).
  final Map<String, int> filled;

  /// The template used; null for the month before.
  final String? templateName;

  const AutoFillNote({
    required this.month,
    required this.filled,
    this.templateName,
  });

  int get total => filled.values.fold(0, (sum, v) => sum + v);

  Map<String, Object?> toJson() => {
    'm': CalendarDate.monthKey(month),
    'f': filled,
    't': templateName,
  };

  static AutoFillNote? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return AutoFillNote(
        month: CalendarDate.parseMonthKey(json['m'] as String),
        filled: {
          for (final MapEntry(:key, :value)
              in (json['f'] as Map<String, Object?>).entries)
            key: value as int,
        },
        templateName: json['t'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A month the automatic fill is holding back because To Be Budgeted does
/// not cover the amounts yet (payday still to come). Not persisted: it is
/// recomputed at every start and resume.
class AutoFillWaiting {
  /// First day of the month (UTC).
  final DateTime month;

  /// What would be filled (minor units).
  final int total;

  /// How much To Be Budgeted is short of [total].
  final int missing;

  const AutoFillWaiting({
    required this.month,
    required this.total,
    required this.missing,
  });
}

class NewMonthFillState {
  final AutoFillSource source;

  /// For [AutoFillSource.template].
  final String? templateId;

  final AutoFillNote? note;

  /// Set while the current month waits for its income (see
  /// [NewMonthFillController.runIfDue]).
  final AutoFillWaiting? waiting;

  const NewMonthFillState({
    this.source = AutoFillSource.off,
    this.templateId,
    this.note,
    this.waiting,
  });

  NewMonthFillState copyWith({
    AutoFillSource? source,
    String? templateId,
    AutoFillNote? note,
    bool clearNote = false,
    AutoFillWaiting? waiting,
    bool clearWaiting = false,
  }) => NewMonthFillState(
    source: source ?? this.source,
    templateId: templateId ?? this.templateId,
    note: clearNote ? null : (note ?? this.note),
    waiting: clearWaiting ? null : (waiting ?? this.waiting),
  );
}

/// "Fill new months automatically": on the first run in a new month
/// ([runIfDue], at start-up and on resume), the categories of that month
/// that are still empty get the amounts of the month before or of a
/// template ([BudgetingService.fillEmptyCategories], stamped with
/// [BudgetingService.automaticFillStamp] so a hand edit on any phone wins).
/// Runs at most once per month and phone; a month that already has
/// budgets (e.g. filled on the paired phone) is left as it is.
///
/// The fill waits for the money: while To Be Budgeted of the month does
/// not cover the amounts (payday still to come), nothing is written and
/// [NewMonthFillState.waiting] says what is missing. The next run (start,
/// resume, or the budget screen once To Be Budgeted has grown) fills the
/// month as soon as it is covered, so a month never starts in the red.
/// [fillAnyway] and [skipMonth] end the wait by hand.
class NewMonthFillController extends StateNotifier<NewMonthFillState> {
  NewMonthFillController(
    this._prefs,
    this._budgeting, {
    DateTime Function()? clock,
    bool Function()? allowed,
  }) : _clock = clock ?? DateTime.now,
       _allowed = allowed ?? _always,
       super(
         NewMonthFillState(
           source: AutoFillSource.values.firstWhere(
             (s) => s.name == _prefs.getString(sourceKey),
             orElse: () => AutoFillSource.off,
           ),
           templateId: _prefs.getString(templateKey),
           note: AutoFillNote.tryParse(_prefs.getString(noteKey)),
         ),
       );

  final SharedPreferences _prefs;

  /// Read when needed: the database is not open while the app is locked.
  final BudgetingService Function() _budgeting;
  final DateTime Function() _clock;

  /// Whether the automatic fill may run (a LedgerZero Pro feature).
  final bool Function() _allowed;
  static bool _always() => true;

  static const String sourceKey = 'auto_fill_source';
  static const String templateKey = 'auto_fill_template_id';

  /// `yyyy-MM` of the last month handled on this phone.
  static const String lastMonthKey = 'auto_fill_last_month';
  static const String noteKey = 'auto_fill_note';

  DateTime get _currentMonth =>
      CalendarDate.startOfMonthUtc(CalendarDate.today(now: _clock()));

  /// Changes the setting. It starts with the next month: the current one
  /// is offered on the budget screen instead.
  Future<void> setSource(AutoFillSource source, {String? templateId}) async {
    await _storeSource(source, templateId);
    await _prefs.setString(lastMonthKey, CalendarDate.monthKey(_currentMonth));
    state = NewMonthFillState(
      source: source,
      templateId: templateId,
      note: state.note,
    );
  }

  /// Stores where the amounts come from and nothing else: unlike
  /// [setSource] (the user's choice, which starts with the next month) the
  /// current month is not marked handled and a wait stays as it is.
  Future<void> _storeSource(AutoFillSource source, String? templateId) async {
    await _prefs.setString(sourceKey, source.name);
    if (templateId != null) {
      await _prefs.setString(templateKey, templateId);
    } else {
      await _prefs.remove(templateKey);
    }
    state = NewMonthFillState(
      source: source,
      templateId: templateId,
      note: state.note,
      waiting: state.waiting,
    );
  }

  /// Whether the automatic fill takes its amounts from template
  /// [templateId].
  bool usesTemplate(String templateId) =>
      state.source == AutoFillSource.template && state.templateId == templateId;

  /// Call after template [templateId] was deleted. If the automatic fill
  /// used it, new months are filled like the month before from now on (the
  /// same fallback as when the template disappears through sync). The
  /// setting stays on and the current month stays due; a wait that was
  /// computed from the template's amounts is worked out again.
  Future<void> templateDeleted(String templateId) async {
    if (!usesTemplate(templateId)) {
      return;
    }
    await _storeSource(AutoFillSource.previousMonth, null);
    if (state.waiting != null) {
      state = state.copyWith(clearWaiting: true);
      await runIfDue();
    }
  }

  /// Fills the current month if the setting is on, this phone has not
  /// handled it yet and To Be Budgeted covers the amounts; otherwise
  /// records what is missing in [NewMonthFillState.waiting] and tries
  /// again at the next call. Never throws.
  Future<void> runIfDue() => _run(waitForMoney: true);

  /// Fills the waiting month now, whatever To Be Budgeted says.
  Future<void> fillAnyway() => _run(waitForMoney: false);

  /// Leaves the waiting month empty (the card offers it by hand as usual).
  Future<void> skipMonth() async {
    await _prefs.setString(lastMonthKey, CalendarDate.monthKey(_currentMonth));
    state = state.copyWith(clearWaiting: true);
  }

  Future<void> _run({required bool waitForMoney}) async {
    // Off, or LedgerZero Pro (which includes the automatic fill) is locked.
    if (state.source == AutoFillSource.off || !_allowed()) {
      return;
    }
    final month = _currentMonth;
    final key = CalendarDate.monthKey(month);
    if (state.waiting != null && state.waiting!.month != month) {
      state = state.copyWith(clearWaiting: true);
    }
    if (_prefs.getString(lastMonthKey) == key) {
      return;
    }
    try {
      final budgeting = _budgeting();
      if (await budgeting.isMonthEmpty(month)) {
        var amounts = await budgeting.budgetsOfPreviousMonth(month);
        String? templateName;
        if (state.source == AutoFillSource.template) {
          final template = (await budgeting.getAllTemplates())
              .where((t) => t.id == state.templateId)
              .firstOrNull;
          if (template != null) {
            amounts = Map.of(template.data);
            templateName = template.name;
          } else {
            // Deleted meanwhile: the month before, from now on. Only the
            // source changes; this month is still to be filled (setSource
            // would mark it handled, and a month waiting for its income
            // would then never be filled, not even by "Fill anyway").
            Logger.warning('Auto-fill template missing; using last month.');
            await _storeSource(AutoFillSource.previousMonth, null);
          }
        }
        final stamp = BudgetingService.automaticFillStamp(month);
        if (waitForMoney) {
          final planned = await budgeting.planFill(
            month,
            amounts,
            stampedAt: stamp,
          );
          final total = planned.values.fold(0, (sum, v) => sum + v);
          if (total > 0) {
            final tbb = await budgeting.calculateTBB(month);
            if (tbb < total) {
              state = state.copyWith(
                waiting: AutoFillWaiting(
                  month: month,
                  total: total,
                  missing: total - tbb,
                ),
              );
              return;
            }
          }
        }
        final filled = await budgeting.fillEmptyCategories(
          month,
          amounts,
          stampedAt: stamp,
        );
        if (filled.isNotEmpty) {
          final note = AutoFillNote(
            month: month,
            filled: filled,
            templateName: templateName,
          );
          await _prefs.setString(noteKey, jsonEncode(note.toJson()));
          state = state.copyWith(note: note, clearWaiting: true);
        }
      }
      await _prefs.setString(lastMonthKey, key);
      state = state.copyWith(clearWaiting: true);
    } catch (e, stack) {
      // Tried again on the next start or resume.
      Logger.error('Filling the new month failed', e, stack);
    }
  }

  /// Takes the automatic fill back (categories changed since are kept).
  Future<void> undoNote() async {
    final note = state.note;
    if (note == null) {
      return;
    }
    await _budgeting().undoFill(note.month, note.filled);
    await dismissNote();
  }

  Future<void> dismissNote() async {
    await _prefs.remove(noteKey);
    state = state.copyWith(clearNote: true);
  }
}

final newMonthFillProvider =
    StateNotifierProvider<NewMonthFillController, NewMonthFillState>((ref) {
      ref.watch(settingsGenerationProvider); // reload after a factory reset
      return NewMonthFillController(
        ref.watch(sharedPreferencesProvider),
        () => ref.read(budgetingServiceProvider),
        allowed: () =>
            ref.read(proFeatureAvailableProvider(ProFeature.budgetTemplates)),
      );
    });
