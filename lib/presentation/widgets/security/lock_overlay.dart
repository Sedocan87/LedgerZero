import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';

/// Shows the app lock over the app when it locks again after the first
/// unlock ([AuthState.isRelocked]). The app below keeps its state (tab,
/// open screens, unsaved input) but is not painted, cannot be touched or
/// focused, is hidden from accessibility services and runs no animations
/// until the lock is passed.
class LockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const LockOverlay({super.key, required this.child});

  @override
  ConsumerState<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends ConsumerState<LockOverlay>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _lockNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Registered during builder mount — before the child Router registers its
    // RootBackButtonDispatcher — so when relocked we intercept Android system
    // back before GoRouter ever sees it.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted || !ref.read(authProvider).isRelocked) {
      return false;
    }
    final nav = _lockNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
    // Always consume Android system/predictive back while locked so the
    // offstage app router underneath never receives back events.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(authProvider.select((s) => s.isRelocked));
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        ExcludeFocus(
          excluding: locked,
          child: TickerMode(
            enabled: !locked,
            child: Offstage(offstage: locked, child: widget.child),
          ),
        ),
        if (locked)
          // Its own navigator for the lock screen's dialogs; the app's
          // navigator is offstage.
          HeroControllerScope.none(
            child: Navigator(
              key: _lockNavigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const LockScreen()),
            ),
          ),
      ],
    );
  }
}
