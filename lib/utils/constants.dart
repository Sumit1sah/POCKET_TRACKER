import 'package:flutter/material.dart';
import '../models/category_model.dart';

class AppConstants {
  static const List<String> defaultCurrencies = ['₹', '\$', '€', '£', '¥', 'A\$', 'C\$', 'AED'];

  static const List<String> paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Credit Card',
    'Debit Card',
    'PayPal',
    'Wallet',
  ];

  static List<CategoryModel> defaultCategories = [
    CategoryModel(
      id: 'cat_food',
      uid: 'system',
      name: 'Food',
      iconCodePoint: Icons.restaurant.codePoint,
      colorValue: const Color(0xFFFF5722).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_shopping',
      uid: 'system',
      name: 'Shopping',
      iconCodePoint: Icons.shopping_bag.codePoint,
      colorValue: const Color(0xFFE91E63).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_travel',
      uid: 'system',
      name: 'Travel',
      iconCodePoint: Icons.directions_car.codePoint,
      colorValue: const Color(0xFF2196F3).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_education',
      uid: 'system',
      name: 'Education',
      iconCodePoint: Icons.school.codePoint,
      colorValue: const Color(0xFF9C27B0).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_entertainment',
      uid: 'system',
      name: 'Entertainment',
      iconCodePoint: Icons.movie.codePoint,
      colorValue: const Color(0xFF673AB7).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_bills',
      uid: 'system',
      name: 'Bills',
      iconCodePoint: Icons.receipt_long.codePoint,
      colorValue: const Color(0xFFFF9800).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_medical',
      uid: 'system',
      name: 'Medical',
      iconCodePoint: Icons.medical_services.codePoint,
      colorValue: const Color(0xFFF44336).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_grocery',
      uid: 'system',
      name: 'Grocery',
      iconCodePoint: Icons.local_grocery_store.codePoint,
      colorValue: const Color(0xFF4CAF50).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_fuel',
      uid: 'system',
      name: 'Fuel',
      iconCodePoint: Icons.local_gas_station.codePoint,
      colorValue: const Color(0xFF795548).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_investment',
      uid: 'system',
      name: 'Investment',
      iconCodePoint: Icons.trending_up.codePoint,
      colorValue: const Color(0xFF009688).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_rent',
      uid: 'system',
      name: 'Rent',
      iconCodePoint: Icons.home.codePoint,
      colorValue: const Color(0xFF607D8B).toARGB32(),
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_salary',
      uid: 'system',
      name: 'Salary',
      iconCodePoint: Icons.account_balance_wallet.codePoint,
      colorValue: const Color(0xFF4CAF50).toARGB32(),
      isIncome: true,
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_freelance',
      uid: 'system',
      name: 'Freelance',
      iconCodePoint: Icons.work.codePoint,
      colorValue: const Color(0xFF00BCD4).toARGB32(),
      isIncome: true,
      isDefault: true,
    ),
  ];
}
