import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class ThemeState {
  final ThemeMode mode;
  final bool isHighContrast;
  final bool reducedMotion;

  const ThemeState({
    required this.mode,
    required this.isHighContrast,
    required this.reducedMotion,
  });

  ThemeState copyWith({
    ThemeMode? mode,
    bool? isHighContrast,
    bool? reducedMotion,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      isHighContrast: isHighContrast ?? this.isHighContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast_mode';
  static const String _reducedMotionKey = 'reduced_motion_mode';

  @override
  ThemeState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    final isHighContrast = prefs.getBool(_highContrastKey) ?? false;
    final reducedMotion = prefs.getBool(_reducedMotionKey) ?? false;

    return ThemeState(
      mode: _getThemeModeFromString(savedTheme),
      isHighContrast: isHighContrast,
      reducedMotion: reducedMotion,
    );
  }

  void setTheme(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_themeKey, mode.toString());
  }

  void toggleHighContrast(bool value) {
    state = state.copyWith(isHighContrast: value);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_highContrastKey, value);
  }

  void toggleReducedMotion(bool value) {
    state = state.copyWith(reducedMotion: value);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_reducedMotionKey, value);
  }

  /// One-off check (e.g. in a post-frame callback) whether animations may
  /// run. Widgets should call [animationsEnabled] in `build` instead so they
  /// rebuild when the setting changes.
  static bool shouldAnimate(BuildContext context, WidgetRef ref) {
    final reducedMotion = ref.read(themeProvider).reducedMotion;
    return !reducedMotion && !MediaQuery.disableAnimationsOf(context);
  }

  ThemeMode _getThemeModeFromString(String? themeString) {
    switch (themeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

/// Whether animations may run: `false` when the user turned on Reduced
/// Motion in Settings or the platform asks to disable animations
/// ([MediaQueryData.disableAnimations]).
///
/// Call it from `build`; it watches both, so the widget rebuilds when either
/// changes.
bool animationsEnabled(BuildContext context, WidgetRef ref) {
  final reducedMotion = ref.watch(
    themeProvider.select((state) => state.reducedMotion),
  );
  return !reducedMotion && !MediaQuery.disableAnimationsOf(context);
}

/// [animationsEnabled] for places without a [WidgetRef], such as page
/// `transitionsBuilder`s. Reads the setting from the enclosing
/// [ProviderScope] without subscribing; outside a [ProviderScope] only the
/// platform setting is used.
bool animationsEnabledOf(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return false;
  }
  final scope = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  if (scope == null) {
    return true;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  return !container.read(themeProvider).reducedMotion;
}
