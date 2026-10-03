import 'package:flutter/material.dart';

class CategoryMeta {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const CategoryMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class CategoryConstants {
  static const List<CategoryMeta> all = [
    CategoryMeta(
      id: 'food',
      label: 'Food & Dining',
      icon: Icons.restaurant,
      color: Color(0xFFFF8C42), // Warm Orange
    ),
    CategoryMeta(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      color: Color(0xFF3B82F6), // Electric Blue
    ),
    CategoryMeta(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFEC4899), // Vibrant Pink
    ),
    CategoryMeta(
      id: 'entertainment',
      label: 'Entertainment',
      icon: Icons.movie,
      color: Color(0xFF8B5CF6), // Purple
    ),
    CategoryMeta(
      id: 'bills',
      label: 'Bills & Utilities',
      icon: Icons.receipt_long,
      color: Color(0xFFF59E0B), // Amber Gold
    ),
    CategoryMeta(
      id: 'health',
      label: 'Health & Medical',
      icon: Icons.favorite,
      color: Color(0xFFEF4444), // Crimson Red
    ),
    CategoryMeta(
      id: 'education',
      label: 'Education',
      icon: Icons.school,
      color: Color(0xFF10B981), // Emerald Green
    ),
    CategoryMeta(
      id: 'groceries',
      label: 'Groceries',
      icon: Icons.local_grocery_store,
      color: Color(0xFF06B6D4), // Cyan
    ),
    CategoryMeta(
      id: 'travel',
      label: 'Travel',
      icon: Icons.flight,
      color: Color(0xFF6366F1), // Indigo
    ),
    CategoryMeta(
      id: 'other',
      label: 'Other',
      icon: Icons.more_horiz,
      color: Color(0xFF94A3B8), // Slate Gray
    ),
  ];

  static final Map<String, CategoryMeta> _byId = {
    for (final c in all) c.id.toLowerCase(): c,
  };

  static const CategoryMeta defaultCategory = CategoryMeta(
    id: 'other',
    label: 'Other',
    icon: Icons.more_horiz,
    color: Color(0xFF94A3B8),
  );

  static CategoryMeta get(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return defaultCategory;
    return _byId[categoryId.toLowerCase()] ?? defaultCategory;
  }

  static Color getColor(String? categoryId) => get(categoryId).color;
  static IconData getIcon(String? categoryId) => get(categoryId).icon;
  static String getLabel(String? categoryId) => get(categoryId).label;
}
