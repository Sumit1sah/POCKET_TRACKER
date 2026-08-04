import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import 'local_storage_service.dart';

class MonthlyReportData {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // Percentage (0-100)
  final double budgetLimit;
  final double budgetUtilization; // Percentage (0-100+)
  final Map<String, double> categoryExpenses;
  final String topCategory;
  final double topCategoryAmount;
  final double topCategoryPercentage;
  final TransactionModel? highestExpense;
  final int transactionCount;
  final double avgDailyExpense;
  final String healthGrade; // 'A+', 'A', 'B', 'C', 'D'
  final String healthSummary;

  MonthlyReportData({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.budgetLimit,
    required this.budgetUtilization,
    required this.categoryExpenses,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.topCategoryPercentage,
    this.highestExpense,
    required this.transactionCount,
    required this.avgDailyExpense,
    required this.healthGrade,
    required this.healthSummary,
  });
}

class MonthlyReportService {
  static MonthlyReportData generateReport({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required DateTime targetMonth,
  }) {
    final year = targetMonth.year;
    final month = targetMonth.month;

    // Filter transactions for target month
    final monthTxs = transactions.where((t) =>
        t.date.year == year && t.date.month == month).toList();

    double income = 0.0;
    double expense = 0.0;
    final Map<String, double> categoryMap = {};
    TransactionModel? maxExpenseTx;

    final categoryList = LocalStorageService.getCategories();
    bool shouldDeduct(String catName) {
      final match = categoryList.firstWhere(
        (c) => c.name.toLowerCase() == catName.toLowerCase(),
        orElse: () => CategoryModel(
          id: '',
          uid: '',
          name: catName,
          iconCodePoint: 0,
          colorValue: 0,
          deductFromBudget: catName.toLowerCase() != 'debt / repayment' &&
              catName.toLowerCase() != 'money given / lent',
        ),
      );
      return match.deductFromBudget;
    }

    for (final t in monthTxs) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else if (t.type == TransactionType.expense) {
        if (!shouldDeduct(t.category)) continue;
        expense += t.amount;
        categoryMap[t.category] = (categoryMap[t.category] ?? 0.0) + t.amount;

        if (maxExpenseTx == null || t.amount > maxExpenseTx.amount) {
          maxExpenseTx = t;
        }
      }
    }

    final netSavings = income - expense;
    final savingsRate = income > 0 ? (netSavings / income) * 100.0 : (netSavings > 0 ? 100.0 : 0.0);

    // Get overall budget limit
    final overallBudget = budgets.firstWhere(
      (b) => b.category.toLowerCase() == 'overall',
      orElse: () {
        final catTotal = budgets
            .where((b) => b.category.toLowerCase() != 'overall')
            .fold(0.0, (sum, b) => sum + b.monthlyLimit);
        return BudgetModel(id: '', uid: '', category: 'Overall', monthlyLimit: catTotal);
      },
    );

    final budgetLimit = overallBudget.monthlyLimit;
    final budgetUtilization = budgetLimit > 0 ? (expense / budgetLimit) * 100.0 : 0.0;

    // Sort category expenses descending
    final sortedCategories = Map<String, double>.fromEntries(
      categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    final topCat = sortedCategories.isNotEmpty ? sortedCategories.keys.first : 'None';
    final topCatAmount = sortedCategories.isNotEmpty ? sortedCategories.values.first : 0.0;
    final topCatPct = expense > 0 ? (topCatAmount / expense) * 100.0 : 0.0;

    // Days in month
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final avgDaily = expense / daysInMonth;

    // Financial Health Grade Calculation
    String grade = 'B';
    String summary = 'Balanced monthly financial performance.';

    if (expense == 0 && income == 0) {
      grade = 'N/A';
      summary = 'No financial transactions logged for this month.';
    } else if (netSavings < 0) {
      grade = 'D';
      summary = 'Expenses exceeded total income this month. Review high-spending categories.';
    } else if (budgetLimit > 0 && expense > budgetLimit) {
      grade = 'C';
      summary = 'Budget limit exceeded despite positive cash flow. Re-align category limits.';
    } else if (savingsRate >= 40.0) {
      grade = 'A+';
      summary = 'Outstanding! You saved ${savingsRate.toStringAsFixed(0)}% of your income this month.';
    } else if (savingsRate >= 20.0) {
      grade = 'A';
      summary = 'Great job! Strong savings rate of ${savingsRate.toStringAsFixed(0)}% achieved.';
    } else {
      grade = 'B';
      summary = 'Solid month. Stay mindful of category allocations to increase savings.';
    }

    return MonthlyReportData(
      month: DateTime(year, month, 1),
      totalIncome: income,
      totalExpense: expense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      budgetLimit: budgetLimit,
      budgetUtilization: budgetUtilization,
      categoryExpenses: sortedCategories,
      topCategory: topCat,
      topCategoryAmount: topCatAmount,
      topCategoryPercentage: topCatPct,
      highestExpense: maxExpenseTx,
      transactionCount: monthTxs.length,
      avgDailyExpense: avgDaily,
      healthGrade: grade,
      healthSummary: summary,
    );
  }
}
