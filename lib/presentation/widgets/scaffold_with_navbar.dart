import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.budget),
            label: AppLocalizations.of(context)!.budget,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.accounts),
            label: AppLocalizations.of(context)!.accounts,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.transactions),
            label: AppLocalizations.of(context)!.transactions,
          ),
        ],
      ),
    );
  }
}
