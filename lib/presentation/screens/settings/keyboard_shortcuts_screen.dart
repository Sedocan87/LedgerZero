import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';

class KeyboardShortcutsScreen extends StatelessWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard Shortcuts')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _ShortcutSection(
            title: 'General',
            shortcuts: [
              _ShortcutItem(
                keys: ['Ctrl', 'S'],
                description: 'Save current form',
              ),
              _ShortcutItem(
                keys: ['Esc'],
                description: 'Close dialog or cancel',
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          _ShortcutSection(
            title: 'Transactions',
            shortcuts: [
              _ShortcutItem(
                keys: ['Ctrl', 'N'],
                description: 'Create new transaction',
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          _ShortcutSection(
            title: 'Budget',
            shortcuts: [
              _ShortcutItem(
                keys: ['Arrow Up/Down'],
                description: 'Navigate categories',
              ),
              _ShortcutItem(
                keys: ['Enter'],
                description: 'Edit selected budget amount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  final String title;
  final List<_ShortcutItem> shortcuts;

  const _ShortcutSection({required this.title, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: shortcuts
                .map(
                  (s) => Column(
                    children: [s, if (s != shortcuts.last) const Divider()],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final List<String> keys;
  final String description;

  const _ShortcutItem({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Expanded(child: Text(description)),
          Row(
            children: keys
                .map(
                  (key) => Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
