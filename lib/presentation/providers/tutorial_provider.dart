import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tutorialProvider = StateNotifierProvider<TutorialNotifier, Set<String>>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TutorialNotifier(prefs);
});

class TutorialNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;
  static const String _prefix = 'tutorial_completed_';

  TutorialNotifier(this._prefs)
    : super(
        _prefs
            .getKeys()
            .where((key) => key.startsWith(_prefix))
            .map((key) => key.substring(_prefix.length))
            .toSet(),
      );

  Future<void> completeTutorial(String tutorialId) async {
    if (state.contains(tutorialId)) {
      return;
    }

    await _prefs.setBool('$_prefix$tutorialId', true);
    state = {...state, tutorialId};
  }

  Future<void> resetTutorial(String tutorialId) async {
    await _prefs.remove('$_prefix$tutorialId');
    state = state.where((id) => id != tutorialId).toSet();
  }

  bool isTutorialCompleted(String tutorialId) {
    return state.contains(tutorialId);
  }
}
