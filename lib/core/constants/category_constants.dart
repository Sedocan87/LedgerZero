import 'package:flutter/material.dart';

/// The icons a category (or payee) can have, by the key stored in its
/// `icon` column. Keys are stored, so a key is never renamed or removed;
/// new ones are added. The order is the order of the icon picker.
const Map<String, IconData> categoryIcons = {
  // Home and bills
  'home': Icons.home,
  'home_repair': Icons.handyman,
  'furniture': Icons.chair,
  'household': Icons.cleaning_services,
  'garden': Icons.yard,
  'electric': Icons.bolt,
  'water': Icons.water_drop,
  'heating': Icons.local_fire_department,
  'internet': Icons.wifi,
  'phone': Icons.smartphone,
  'tv': Icons.tv,
  'utilities': Icons.lightbulb,
  'insurance': Icons.shield,
  'subscriptions': Icons.subscriptions,
  // Food
  'groceries': Icons.local_grocery_store,
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe,
  'drinks': Icons.local_bar,
  // Getting around
  'transport': Icons.directions_car,
  'car_repair': Icons.car_repair,
  'car_payment': Icons.car_rental,
  'fuel': Icons.local_gas_station,
  'parking': Icons.local_parking,
  'public_transport': Icons.train,
  'travel': Icons.flight,
  'vacation': Icons.beach_access,
  // Health and care
  'health': Icons.medical_services,
  'pharmacy': Icons.local_pharmacy,
  'fitness': Icons.fitness_center,
  'personal_care': Icons.spa,
  'clothing': Icons.checkroom,
  // People
  'kids': Icons.child_care,
  'pets': Icons.pets,
  'gifts': Icons.card_giftcard,
  'charity': Icons.volunteer_activism,
  // Leisure
  'entertainment': Icons.movie,
  'gaming': Icons.sports_esports,
  'music': Icons.music_note,
  'books': Icons.menu_book,
  'education': Icons.school,
  'fun': Icons.celebration,
  'shopping': Icons.shopping_cart,
  // Money
  'savings': Icons.savings,
  'stocks': Icons.show_chart,
  'crypto': Icons.currency_bitcoin,
  'bonds': Icons.account_balance,
  'retirement': Icons.elderly,
  'credit_card': Icons.credit_card,
  'student_loan': Icons.history_edu,
  'debt': Icons.money_off,
  'taxes': Icons.receipt_long,
  'finance': Icons.attach_money,
  'work': Icons.work,
  'other': Icons.category,
};

/// The icon of a category without one of its own.
const IconData defaultCategoryIcon = Icons.label_outline_rounded;

const List<int> categoryColors = [
  0xFFF44336,
  0xFFE91E63,
  0xFF9C27B0,
  0xFF673AB7,
  0xFF3F51B5,
  0xFF2196F3,
  0xFF03A9F4,
  0xFF00BCD4,
  0xFF009688,
  0xFF4CAF50,
  0xFF8BC34A,
  0xFFCDDC39,
  0xFFFFEB3B,
  0xFFFFC107,
  0xFFFF9800,
  0xFFFF5722,
  0xFF795548,
  0xFF9E9E9E,
  0xFF607D8B,
];
