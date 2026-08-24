import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
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

class UnbudgetedCategoryStatus {
  final String category;
  final double spent;
  final int transactionCount;

  UnbudgetedCategoryStatus({
    required this.category,
    required this.spent,
    required this.transactionCount,
  });
}

class BudgetProvider extends ChangeNotifier {
  List<BudgetModel> _budgets = [];

  String? _activeUid;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<BudgetModel> get budgets => _budgets;
  DateTime get selectedMonth => _selectedMonth;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  bool get isPastMonth {
    final now = DateTime.now();
    final currentFirst = DateTime(now.year, now.month, 1);
    return _selectedMonth.isBefore(currentFirst);
  }

  bool get isFutureMonth {
    final now = DateTime.now();
    final currentFirst = DateTime(now.year, now.month, 1);
    return _selectedMonth.isAfter(currentFirst);
  }

  BudgetProvider() {
    loadBudgets();
  }

  void setSelectedMonth(DateTime date) {
    _selectedMonth = DateTime(date.year, date.month, 1);
    notifyListeners();
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    notifyListeners();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    notifyListeners();
  }

  void resetToCurrentMonth() {
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    notifyListeners();
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

  /// Checks whether a given category is configured to deduct from monthly budget.
  bool shouldCategoryDeductFromBudget(String categoryName, [List<CategoryModel>? categories]) {
    final catList = categories ?? LocalStorageService.getCategories();
    final match = catList.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => CategoryModel(
        id: '',
        uid: '',
        name: categoryName,
        iconCodePoint: 0,
        colorValue: 0,
        deductFromBudget: categoryName.toLowerCase() != 'debt / repayment' &&
            categoryName.toLowerCase() != 'money given / lent',
      ),
    );
    return match.deductFromBudget;
  }

  // Get overall monthly budget status for a given month (defaults to _selectedMonth)
  BudgetStatus getOverallBudgetStatus(
    List<TransactionModel> transactions, {
    DateTime? month,
    List<CategoryModel>? categories,
  }) {
    final targetMonth = month ?? _selectedMonth;
    final catList = categories ?? LocalStorageService.getCategories();

    final targetExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        shouldCategoryDeductFromBudget(t.category, catList) &&
        t.date.year == targetMonth.year &&
        t.date.month == targetMonth.month).toList();

    final totalSpent = targetExpenses.fold(0.0, (sum, t) => sum + t.amount);

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

  // Get category-wise budget statuses for a given month (defaults to _selectedMonth)
  List<BudgetStatus> getCategoryBudgetStatuses(
    List<TransactionModel> transactions, {
    DateTime? month,
    List<CategoryModel>? categories,
  }) {
    final targetMonth = month ?? _selectedMonth;
    final catList = categories ?? LocalStorageService.getCategories();

    final targetExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        shouldCategoryDeductFromBudget(t.category, catList) &&
        t.date.year == targetMonth.year &&
        t.date.month == targetMonth.month).toList();

    final categoryBudgets = _budgets.where((b) => b.category.toLowerCase() != 'overall').toList();

    return categoryBudgets.map((budget) {
      final spent = targetExpenses
          .where((t) => t.category.toLowerCase() == budget.category.toLowerCase())
          .fold(0.0, (sum, t) => sum + t.amount);

      return BudgetStatus(budget: budget, spent: spent);
    }).toList();
  }

  // Get categories that have expenses in the target month but NO budget limit assigned
  List<UnbudgetedCategoryStatus> getUnbudgetedCategories(
    List<TransactionModel> transactions, {
    DateTime? month,
    List<CategoryModel>? categories,
  }) {
    final targetMonth = month ?? _selectedMonth;
    final catList = categories ?? LocalStorageService.getCategories();

    final targetExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        shouldCategoryDeductFromBudget(t.category, catList) &&
        t.date.year == targetMonth.year &&
        t.date.month == targetMonth.month).toList();

    final budgetedCategoryNames = _budgets
        .map((b) => b.category.trim().toLowerCase())
        .toSet();

    final Map<String, List<TransactionModel>> unbudgetedGroup = {};
    for (final tx in targetExpenses) {
      final catKey = tx.category.trim();
      if (!budgetedCategoryNames.contains(catKey.toLowerCase()) &&
          catKey.toLowerCase() != 'overall') {
        unbudgetedGroup.putIfAbsent(catKey, () => []).add(tx);
      }
    }

    return unbudgetedGroup.entries.map((entry) {
      final total = entry.value.fold(0.0, (sum, t) => sum + t.amount);
      return UnbudgetedCategoryStatus(
        category: entry.key,
        spent: total,
        transactionCount: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));
  }

  // Get previous month actual spending per category (for auto-allocator presets)
  Map<String, double> getPreviousMonthCategorySpending(
    List<TransactionModel> transactions, {
    List<CategoryModel>? categories,
  }) {
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    final catList = categories ?? LocalStorageService.getCategories();

    final prevExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        shouldCategoryDeductFromBudget(t.category, catList) &&
        t.date.year == prevMonth.year &&
        t.date.month == prevMonth.month).toList();

    final Map<String, double> spending = {};
    for (final tx in prevExpenses) {
      final key = tx.category.trim();
      spending[key] = (spending[key] ?? 0.0) + tx.amount;
    }
    return spending;
  }

  // Transfer budget amount from one category to another
  Future<bool> transferBudget({
    required String fromCategory,
    required String toCategory,
    required double amount,
  }) async {
    if (amount <= 0 || fromCategory.toLowerCase() == toCategory.toLowerCase()) {
      return false;
    }

    final fromIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == fromCategory.toLowerCase());
    final toIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == toCategory.toLowerCase());

    if (fromIndex == -1) return false;

    final fromBudget = _budgets[fromIndex];
    if (fromBudget.monthlyLimit < amount) return false;

    final newFromLimit = fromBudget.monthlyLimit - amount;
    await setBudget(BudgetModel(
      id: fromBudget.id,
      uid: fromBudget.uid,
      category: fromBudget.category,
      monthlyLimit: newFromLimit,
    ));

    if (toIndex != -1) {
      final toBudget = _budgets[toIndex];
      final newToLimit = toBudget.monthlyLimit + amount;
      await setBudget(BudgetModel(
        id: toBudget.id,
        uid: toBudget.uid,
        category: toBudget.category,
        monthlyLimit: newToLimit,
      ));
    } else {
      final userUid = _activeUid ?? 'local_user';
      await setBudget(BudgetModel(
        id: 'b_${toCategory.toLowerCase()}_$userUid',
        uid: userUid,
        category: toCategory,
        monthlyLimit: amount,
      ));
    }

    loadBudgets();
    return true;
  }

  // Save or update a budget limit
  Future<void> setBudget(BudgetModel budget) async {
    final existingIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == budget.category.toLowerCase());
    BudgetModel toSave;
    if (existingIndex != -1) {
      final oldId = _budgets[existingIndex].id;
      toSave = BudgetModel(
        id: oldId,
        uid: budget.uid,
        category: budget.category,
        monthlyLimit: budget.monthlyLimit,
      );
      await LocalStorageService.saveBudget(toSave);
    } else {
      toSave = budget;
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

  // Clear all category budget allocations to start completely fresh
  Future<void> clearAllBudgets() async {
    for (final b in List<BudgetModel>.from(_budgets)) {
      await LocalStorageService.deleteBudget(b.id);
    }
    loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await LocalStorageService.deleteBudget(id);
    loadBudgets();
  }
}
