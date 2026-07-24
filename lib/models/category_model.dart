import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String uid;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final bool isIncome;
  final bool isDefault;

  CategoryModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isIncome = false,
    this.isDefault = false,
  });

  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
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
    );
  }
}
