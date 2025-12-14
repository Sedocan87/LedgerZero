import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/common/app_bar.dart';

class WidgetTutorialScreen extends StatelessWidget {
  const WidgetTutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Widget Setup Guide'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          StepCard(
            number: 1,
            title: 'Go to Home Screen',
            description: 'Exit the app and go to your device home screen.',
          ),
          StepCard(
            number: 2,
            title: 'Enter Edit Mode',
            description:
                'Long press on an empty area until icons start jiggling.',
          ),
          StepCard(
            number: 3,
            title: 'Add Widget',
            description:
                'Tap the + button (usually top left) to open the widget gallery.',
          ),
          StepCard(
            number: 4,
            title: 'Find LedgerZero',
            description: 'Search for "LedgerZero" in the list.',
          ),
          StepCard(
            number: 5,
            title: 'Select Widget',
            description: 'Swipe to choose a widget size and tap "Add Widget".',
          ),
        ],
      ),
    );
  }
}

class StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }
}
