import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    ExpenseCategory(
      name: 'Transportation',
      icon: Icons.directions_car,
      color: Colors.blue,
    ),
    ExpenseCategory(
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
    ),
    ExpenseCategory(
      name: 'Entertainment',
      icon: Icons.movie,
      color: Colors.pink,
    ),
    ExpenseCategory(
      name: 'Bills & Utilities',
      icon: Icons.receipt_long,
      color: Colors.red,
    ),
    ExpenseCategory(
      name: 'Healthcare',
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    ExpenseCategory(
      name: 'Education',
      icon: Icons.school,
      color: Colors.indigo,
    ),
    ExpenseCategory(
      name: 'Travel',
      icon: Icons.flight,
      color: Colors.teal,
    ),
    ExpenseCategory(
      name: 'Other',
      icon: Icons.more_horiz,
      color: Colors.grey,
    ),
  ];

  static ExpenseCategory getCategory(String name) {
    return defaultCategories.firstWhere(
      (category) => category.name == name,
      orElse: () => defaultCategories.last,
    );
  }
}
