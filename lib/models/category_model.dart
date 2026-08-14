import 'package:flutter/material.dart';
import 'package:expense_tracker/utils/icon_helper.dart';

class CategoryModel {
  final String id;
  final String uid;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final bool isIncome;
  final bool isDefault;
  final bool deductFromBudget;

  CategoryModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isIncome = false,
    this.isDefault = false,
    this.deductFromBudget = true,
  });

  IconData get iconData {
    if (iconCodePoint != 0 && iconCodePoint != Icons.category.codePoint) {
      final found = IconHelper.fromCodePoint(iconCodePoint, fallback: Icons.category);
      if (found != Icons.category) return found;
    }
    return IconHelper.getIconForCategoryName(name, isIncome: isIncome);
  }
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isIncome': isIncome,
      'isDefault': isDefault,
      'deductFromBudget': deductFromBudget,
    };
  }

  factory CategoryModel.fromMap(Map<dynamic, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? 'local_user',
      name: map['name'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? Icons.category.codePoint,
      colorValue: map['colorValue'] ?? Colors.blue.toARGB32(),
      isIncome: map['isIncome'] ?? false,
      isDefault: map['isDefault'] ?? false,
      deductFromBudget: map['deductFromBudget'] ?? true,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? uid,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? isIncome,
    bool? isDefault,
    bool? deductFromBudget,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isIncome: isIncome ?? this.isIncome,
      isDefault: isDefault ?? this.isDefault,
      deductFromBudget: deductFromBudget ?? this.deductFromBudget,
    );
  }
}
