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
      name: 'Housing',
      icon: Icons.home,
      color: Colors.brown,
    ),
    ExpenseCategory(
      name: 'Utilities',
      icon: Icons.electrical_services,
      color: Colors.amber,
    ),
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
      name: 'Insurance',
      icon: Icons.shield,
      color: Colors.cyan,
    ),
    ExpenseCategory(
      name: 'Healthcare',
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    ExpenseCategory(
      name: 'Financial',
      icon: Icons.account_balance,
      color: Colors.teal,
    ),
    ExpenseCategory(
      name: 'Debt Payments',
      icon: Icons.credit_card,
      color: Colors.red,
    ),
    ExpenseCategory(
      name: 'Savings',
      icon: Icons.savings,
      color: Colors.lightGreen,
    ),
    ExpenseCategory(
      name: 'Investments',
      icon: Icons.trending_up,
      color: Colors.deepPurple,
    ),
    ExpenseCategory(
      name: 'Taxes',
      icon: Icons.receipt,
      color: Colors.blueGrey,
    ),
    ExpenseCategory(
      name: 'Lifestyle',
      icon: Icons.spa,
      color: Colors.pink,
    ),
    ExpenseCategory(
      name: 'Shopping / Personal',
      icon: Icons.shopping_bag,
      color: Colors.purple,
    ),
    ExpenseCategory(
      name: 'Entertainment',
      icon: Icons.movie,
      color: Colors.pinkAccent,
    ),
    ExpenseCategory(
      name: 'Travel',
      icon: Icons.flight,
      color: Colors.indigo,
    ),
    ExpenseCategory(
      name: 'Education',
      icon: Icons.school,
      color: Colors.deepOrange,
    ),
    ExpenseCategory(
      name: 'Gifts & Donations',
      icon: Icons.card_giftcard,
      color: Colors.redAccent,
    ),
    ExpenseCategory(
      name: 'Grocery',
      icon: Icons.shopping_cart,
      color: Colors.greenAccent,
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
