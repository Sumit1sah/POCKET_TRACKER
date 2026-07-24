import 'package:flutter/material.dart';
import '../models/savings_goal_model.dart';
import '../services/local_storage_service.dart';

class SavingsProvider extends ChangeNotifier {
  List<SavingsGoalModel> _goals = [];

  List<SavingsGoalModel> get goals => _goals;

  SavingsProvider() {
    loadGoals();
  }

  void loadGoals() {
    _goals = LocalStorageService.getSavingsGoals();
    notifyListeners();
  }

  double get totalSaved => _goals.fold(0.0, (sum, g) => sum + g.savedAmount);
  double get totalTarget => _goals.fold(0.0, (sum, g) => sum + g.targetAmount);

  Future<void> addGoal(SavingsGoalModel goal) async {
    await LocalStorageService.saveSavingsGoal(goal);
    loadGoals();
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    await LocalStorageService.saveSavingsGoal(goal);
    loadGoals();
  }

  Future<void> depositToGoal(String id, double amount) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      final old = _goals[index];
      final updated = SavingsGoalModel(
        id: old.id,
        uid: old.uid,
        title: old.title,
        targetAmount: old.targetAmount,
        savedAmount: old.savedAmount + amount,
        deadline: old.deadline,
        iconCodePoint: old.iconCodePoint,
        colorValue: old.colorValue,
      );
      await LocalStorageService.saveSavingsGoal(updated);
      loadGoals();
    }
  }

  Future<void> deleteGoal(String id) async {
    await LocalStorageService.deleteSavingsGoal(id);
    loadGoals();
  }
}
