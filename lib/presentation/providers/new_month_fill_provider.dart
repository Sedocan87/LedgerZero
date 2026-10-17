import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
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

class NewMonthFillState {
  final AutoFillSource source;

  /// For [AutoFillSource.template].
  final String? templateId;

  final AutoFillNote? note;

  const NewMonthFillState({
    this.source = AutoFillSource.off,
    this.templateId,
    this.note,
  });

  NewMonthFillState copyWith({
    AutoFillSource? source,
    String? templateId,
    AutoFillNote? note,
    bool clearNote = false,
  }) => NewMonthFillState(
    source: source ?? this.source,
    templateId: templateId ?? this.templateId,
    note: clearNote ? null : (note ?? this.note),
  );
}

/// "Fill new months automatically": on the first run in a new month
/// ([runIfDue], at start-up and on resume), the categories of that month
/// that are still empty get the amounts of the month before or of a
/// template ([BudgetingService.fillEmptyCategories], stamped with
/// [BudgetingService.automaticFillStamp] so a hand edit on any phone wins).
/// Runs at most once per month and phone; a month that already has
/// budgets (e.g. filled on the paired phone) is left as it is.
class NewMonthFillController extends StateNotifier<NewMonthFillState> {
  NewMonthFillController(
    this._prefs,
    this._budgeting, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
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
    await _prefs.setString(sourceKey, source.name);
    if (templateId != null) {
      await _prefs.setString(templateKey, templateId);
    } else {
      await _prefs.remove(templateKey);
    }
    await _prefs.setString(lastMonthKey, CalendarDate.monthKey(_currentMonth));
    state = NewMonthFillState(
      source: source,
      templateId: templateId,
      note: state.note,
    );
  }

  /// Fills the current month if the setting is on and this phone has not
  /// handled it yet. Never throws.
  Future<void> runIfDue() async {
    if (state.source == AutoFillSource.off) {
      return;
    }
    final month = _currentMonth;
    final key = CalendarDate.monthKey(month);
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
            // Deleted meanwhile: the month before, from now on.
            Logger.warning('Auto-fill template missing; using last month.');
            await setSource(AutoFillSource.previousMonth);
          }
        }
        final filled = await budgeting.fillEmptyCategories(
          month,
          amounts,
          stampedAt: BudgetingService.automaticFillStamp(month),
        );
        if (filled.isNotEmpty) {
          final note = AutoFillNote(
            month: month,
            filled: filled,
            templateName: templateName,
          );
          await _prefs.setString(noteKey, jsonEncode(note.toJson()));
          state = state.copyWith(note: note);
        }
      }
      await _prefs.setString(lastMonthKey, key);
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
    StateNotifierProvider<NewMonthFillController, NewMonthFillState>(
      (ref) => NewMonthFillController(
        ref.watch(sharedPreferencesProvider),
        () => ref.read(budgetingServiceProvider),
      ),
    );
