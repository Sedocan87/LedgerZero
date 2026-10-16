import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The platform's activity indicator (Cupertino on iOS), centred.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isCupertino = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Center(
      child: isCupertino
          ? const CupertinoActivityIndicator()
          : const CircularProgressIndicator(),
    );
  }
}
