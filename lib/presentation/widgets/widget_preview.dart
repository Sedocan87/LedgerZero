import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/category.dart';

class WidgetPreview extends StatelessWidget {
  final double tbbAmount;
  final List<Category> categories;
  final Map<String, Map<String, double>> categoryPerformance;

  const WidgetPreview({
    super.key,
    required this.tbbAmount,
    required this.categories,
    required this.categoryPerformance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24), // iOS-like rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: TBB
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To Be Budgeted',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NumberFormat.simpleCurrency(locale: 'en_US').format(tbbAmount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: tbbAmount >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('MMM d').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Categories
          if (categories.isEmpty)
             Text(
               'No categories selected',
               style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
             )
          else
            ...categories.take(4).map((category) {
              final available = categoryPerformance[category.id]?['available'] ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: available >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      NumberFormat.simpleCurrency(locale: 'en_US').format(available),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: available >= 0 ? Theme.of(context).colorScheme.onSurface : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
