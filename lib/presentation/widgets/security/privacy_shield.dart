import 'package:flutter/material.dart';

/// Covers the app with a plain screen whenever it is not in the foreground
/// (`inactive`, `hidden`, `paused`), so the app switcher snapshot shows no
/// financial data. Complements the native protections: FLAG_SECURE on
/// Android (MainActivity.kt) and the overlay added on scene deactivation on
/// iOS (AppDelegate.swift), which apply even before Flutter draws a frame.
class PrivacyShield extends StatefulWidget {
  final Widget child;

  const PrivacyShield({super.key, required this.child});

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscured = state != AppLifecycleState.resumed;
    if (obscured != _obscured) {
      setState(() => _obscured = obscured);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_obscured)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
