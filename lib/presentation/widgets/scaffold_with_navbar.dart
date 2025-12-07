import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/offline_indicator.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  final FocusNode _contentFocusNode = FocusNode();
  bool _showSkipLink = false;

  @override
  void dispose() {
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Skip to Content Link
          // Visible only when focused
          Semantics(
            container: true,
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  _showSkipLink = hasFocus;
                });
              },
              child: _showSkipLink
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _contentFocusNode.requestFocus();
                        },
                        child: const Text('Skip to content'),
                      ),
                    )
                  : const SizedBox(width: 1, height: 1), // Minimal size when hidden
            ),
          ),
          const OfflineIndicator(),
          Expanded(
            child: Focus(
              focusNode: _contentFocusNode,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
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
          NavigationDestination(
            icon: const Icon(AppIcons.reports),
            label: AppLocalizations.of(context)!.reports,
          ),
        ],
      ),
    );
  }
}
