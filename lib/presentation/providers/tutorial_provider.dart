import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tutorialProvider = StateNotifierProvider<TutorialNotifier, Set<String>>((ref) {
  return TutorialNotifier();
});

class TutorialNotifier extends StateNotifier<Set<String>> {
  TutorialNotifier() : super({});

  static const String _prefix = 'tutorial_completed_';

  Future<void> loadCompletedTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    state = keys.map((key) => key.substring(_prefix.length)).toSet();
  }

  Future<void> completeTutorial(String tutorialId) async {
    if (state.contains(tutorialId)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$tutorialId', true);
    state = {...state, tutorialId};
  }

  Future<void> resetTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$tutorialId');
    state = state.where((id) => id != tutorialId).toSet();
  }

  bool isTutorialCompleted(String tutorialId) {
    return state.contains(tutorialId);
  }
}
