import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';

/// Shows the app lock over the app when it locks again after the first
/// unlock ([AuthState.isRelocked]). The app below keeps its state (tab,
/// open screens, unsaved input) but is not painted, cannot be touched or
/// focused, is hidden from accessibility services and runs no animations
/// until the lock is passed.
class LockOverlay extends ConsumerWidget {
  final Widget child;

  const LockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(authProvider.select((s) => s.isRelocked));
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        ExcludeFocus(
          excluding: locked,
          child: TickerMode(
            enabled: !locked,
            child: Offstage(offstage: locked, child: child),
          ),
        ),
        if (locked)
          // Its own navigator for the lock screen's dialogs; the app's
          // navigator is offstage.
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const LockScreen()),
            ),
          ),
      ],
    );
  }
}
