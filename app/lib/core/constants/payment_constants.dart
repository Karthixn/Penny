import 'package:flutter/material.dart';

class PaymentMethodMeta {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const PaymentMethodMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class PaymentConstants {
  static const List<PaymentMethodMeta> all = [
    PaymentMethodMeta(
      id: 'upi',
      label: 'UPI (GPay / PhonePe)',
      icon: Icons.bolt,
      color: Color(0xFF00D68F), // Emerald Green
    ),
    PaymentMethodMeta(
      id: 'credit_card',
      label: 'Credit Card',
      icon: Icons.credit_card,
      color: Color(0xFF7C6FF7), // Purple
    ),
    PaymentMethodMeta(
      id: 'debit_card',
      label: 'Debit Card',
      icon: Icons.credit_card_outlined,
      color: Color(0xFF3B82F6), // Blue
    ),
    PaymentMethodMeta(
      id: 'cash',
      label: 'Cash',
      icon: Icons.payments_outlined,
      color: Color(0xFFF59E0B), // Amber
    ),
    PaymentMethodMeta(
      id: 'fastag',
      label: 'Fastag',
      icon: Icons.directions_car,
      color: Color(0xFFFF8C42), // Orange
    ),
    PaymentMethodMeta(
      id: 'net_banking',
      label: 'Net Banking',
      icon: Icons.account_balance,
      color: Color(0xFF06B6D4), // Cyan
    ),
    PaymentMethodMeta(
      id: 'other',
      label: 'Other',
      icon: Icons.more_horiz,
      color: Color(0xFF94A3B8), // Gray
    ),
  ];

  static final Map<String, PaymentMethodMeta> _byId = {
    for (final m in all) m.id.toLowerCase(): m,
  };

  static const PaymentMethodMeta defaultMethod = PaymentMethodMeta(
    id: 'upi',
    label: 'UPI',
    icon: Icons.bolt,
    color: Color(0xFF00D68F),
  );

  static PaymentMethodMeta get(String? methodId) {
    if (methodId == null || methodId.isEmpty) return defaultMethod;
    return _byId[methodId.toLowerCase()] ?? defaultMethod;
  }

  static Color getColor(String? methodId) => get(methodId).color;
  static IconData getIcon(String? methodId) => get(methodId).icon;
  static String getLabel(String? methodId) => get(methodId).label;
}
