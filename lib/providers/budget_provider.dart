import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';

class BudgetStatus {
  final BudgetModel budget;
  final double spent;

  BudgetStatus({required this.budget, required this.spent});

  double get remaining => budget.monthlyLimit - spent;
  double get percentage => budget.monthlyLimit > 0 ? (spent / budget.monthlyLimit) : 0.0;
  bool get isExceeded => spent > budget.monthlyLimit;
  bool get isWarning => percentage >= 0.8 && percentage <= 1.0;
}

class BudgetProvider extends ChangeNotifier {
  List<BudgetModel> _budgets = [];

  String? _activeUid;

  List<BudgetModel> get budgets => _budgets;

  BudgetProvider() {
    loadBudgets();
  }

  void loadForUser(String? uid) {
    _activeUid = uid;
    loadBudgets();
  }

  void loadBudgets() {
    _budgets = LocalStorageService.getBudgets(uid: _activeUid);
    notifyListeners();
  }

  // Total allocated to individual categories (excluding 'Overall')
  double get totalAllocatedCategoryBudget {
    return _budgets
        .where((b) => b.category.toLowerCase() != 'overall')
        .fold(0.0, (sum, b) => sum + b.monthlyLimit);
  }

  // Get overall monthly budget status
  BudgetStatus getOverallBudgetStatus(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final currentMonthExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == now.year &&
        t.date.month == now.month).toList();

    final totalSpent = currentMonthExpenses.fold(0.0, (sum, t) => sum + t.amount);

    final overallMatch = _budgets.firstWhere(
      (b) => b.category.toLowerCase() == 'overall',
      orElse: () {
        return BudgetModel(
          id: 'b_overall_default',
          uid: 'local_user',
          category: 'Overall',
          monthlyLimit: totalAllocatedCategoryBudget,
        );
      },
    );

    return BudgetStatus(budget: overallMatch, spent: totalSpent);
  }

  // Unallocated Buffer: Overall Budget - Sum of Category Allocations
  double getUnallocatedBuffer(double overallLimit) {
    final diff = overallLimit - totalAllocatedCategoryBudget;
    return diff < 0 ? 0.0 : diff;
  }

  // Allocation Percentage: Ratio of Category Allocations vs Overall Limit
  double getAllocationRatio(double overallLimit) {
    if (overallLimit <= 0) return 0.0;
    final ratio = totalAllocatedCategoryBudget / overallLimit;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  // Get category-wise budget statuses
  List<BudgetStatus> getCategoryBudgetStatuses(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final currentMonthExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == now.year &&
        t.date.month == now.month).toList();

    final categoryBudgets = _budgets.where((b) => b.category.toLowerCase() != 'overall').toList();

    return categoryBudgets.map((budget) {
      final spent = currentMonthExpenses
          .where((t) => t.category.toLowerCase() == budget.category.toLowerCase())
          .fold(0.0, (sum, t) => sum + t.amount);

      return BudgetStatus(budget: budget, spent: spent);
    }).toList();
  }

  // Save or update a budget limit
  Future<void> setBudget(BudgetModel budget) async {
    final existingIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == budget.category.toLowerCase());
    if (existingIndex != -1) {
      final oldId = _budgets[existingIndex].id;
      await LocalStorageService.saveBudget(
        BudgetModel(
          id: oldId,
          uid: budget.uid,
          category: budget.category,
          monthlyLimit: budget.monthlyLimit,
        ),
      );
    } else {
      await LocalStorageService.saveBudget(budget);
    }
    loadBudgets();
  }

  // Smart Auto Budget Allocator with custom category percentages
  Future<void> autoAllocateBudgets(
    double overallLimit, {
    Map<String, double>? categoryPercentages,
  }) async {
    if (overallLimit <= 0) return;

    final userUid = _activeUid ?? 'local_user';

    // Save Overall Limit
    await setBudget(BudgetModel(
      id: 'b_overall_$userUid',
      uid: userUid,
      category: 'Overall',
      monthlyLimit: overallLimit,
    ));

    final percentages = categoryPercentages ?? {
      'Grocery': 20.0,
      'Bills': 15.0,
      'Travel': 15.0,
      'Food': 15.0,
      'Shopping': 10.0,
      'Entertainment': 5.0,
      'Investment': 20.0,
    };

    for (final entry in percentages.entries) {
      final allocatedAmount = (overallLimit * (entry.value / 100.0)).roundToDouble();
      await setBudget(BudgetModel(
        id: 'b_${entry.key.toLowerCase()}_$userUid',
        uid: userUid,
        category: entry.key,
        monthlyLimit: allocatedAmount,
      ));
    }
    loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await LocalStorageService.deleteBudget(id);
    loadBudgets();
  }
}
