import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/common/app_app_bar.dart';

class WidgetTutorialScreen extends StatelessWidget {
  const WidgetTutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Widget Setup Guide'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStep(
                context,
                step: 1,
                title: 'Go to Home Screen',
                description: 'Exit LedgerZero and go to your device\'s home screen.',
                icon: Icons.home,
              ),
              _buildStep(
                context,
                step: 2,
                title: 'Enter Jiggle Mode',
                description: 'Long press on any empty space on your home screen until the apps start shaking.',
                icon: Icons.touch_app,
              ),
              _buildStep(
                context,
                step: 3,
                title: 'Add Widget',
                description: 'Tap the "+" button in the top left corner.',
                icon: Icons.add,
              ),
              _buildStep(
                context,
                step: 4,
                title: 'Find LedgerZero',
                description: 'Scroll down or search for "LedgerZero" in the widget gallery.',
                icon: Icons.search,
              ),
              _buildStep(
                context,
                step: 5,
                title: 'Choose Size',
                description: 'Swipe to choose between Small, Medium, or Large widgets, then tap "Add Widget".',
                icon: Icons.widgets,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Lock Screen Widgets',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can also add LedgerZero widgets to your Lock Screen on iOS 16+ for quick access to your "To Be Budgeted" amount.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, {required int step, required String title, required String description, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
