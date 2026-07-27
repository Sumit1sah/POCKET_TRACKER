import 'package:flutter/material.dart';

class SavingsGoalModel {
  final String id;
  final String uid;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime deadline;
  final int iconCodePoint;
  final int colorValue;

  SavingsGoalModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    required this.deadline,
    this.iconCodePoint = 0xe59c, // Icons.savings
    this.colorValue = 0xFF4CAF50, // Colors.green
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    final ratio = savedAmount / targetAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'deadline': deadline.toIso8601String(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory SavingsGoalModel.fromMap(Map<dynamic, dynamic> map) {
    return SavingsGoalModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? 'local_user',
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] as num).toDouble(),
      savedAmount: (map['savedAmount'] as num? ?? 0.0).toDouble(),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : DateTime.now().add(const Duration(days: 30)),
      iconCodePoint: map['iconCodePoint'] ?? Icons.savings.codePoint,
      colorValue: map['colorValue'] ?? Colors.green.toARGB32(),
    );
  }
}
