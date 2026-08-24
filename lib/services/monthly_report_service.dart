import 'dart:math';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';
import 'local_storage_service.dart';

class MonthlyReportData {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // Percentage (0-100)
  final double budgetLimit;
  final double budgetUtilization; // Percentage (0-100+)
  final double budgetRemaining;

  // Category breakdown
  final Map<String, double> categoryExpenses;
  final Map<String, int> categoryTxCounts;
  final Map<String, double> categoryAvgExpense;
  final String topCategory;
  final double topCategoryAmount;
  final double topCategoryPercentage;

  // Highs & Lows
  final TransactionModel? highestExpense;
  final List<TransactionModel> topExpenses;
  final List<TransactionModel> topIncomes;

  // Counts & Averages
  final int transactionCount;
  final int incomeCount;
  final int expenseCount;
  final double avgDailyExpense;
  final double avgExpensePerTx;
  final double avgIncomePerTx;
  final int activeSpendingDaysCount;
  final int zeroSpendDaysCount;

  // Health Score & Assessment
  final int healthScore; // 0 - 100
  final String healthGrade; // 'A+', 'A', 'B+', 'B', 'C', 'D', 'N/A'
  final String healthSummary;
  final Map<String, int> healthScoreBreakdown;
  final List<String> actionableInsights;

  // MoM Comparison (vs previous month)
  final double prevMonthIncome;
  final double prevMonthExpense;
  final double prevMonthNetSavings;
  final double incomeMoMChangePct;
  final double expenseMoMChangePct;
  final double netSavingsMoMChangePct;
  final String fastestGrowingCategory;
  final double fastestGrowingCategoryPct;

  // 50/30/20 Rule Metrics
  final double needsAmount;
  final double needsPct;
  final double wantsAmount;
  final double wantsPct;
  final double savingsInvestmentsAmount;
  final double savingsInvestmentsPct;
  final String rule503020Status;

  // Daily Spending Analytics
  final Map<int, double> dailyExpenses;
  final Map<int, double> dailyIncomes;
  final int highestSpendDay;
  final double highestSpendDayAmount;
  final int lowestSpendDay;
  final double lowestSpendDayAmount;
  final double weekendExpense;
  final double weekendExpensePct;
  final double weekdayExpense;
  final double weekdayExpensePct;

  // Burn Rate & Projections
  final bool isCurrentMonth;
  final double projectedMonthEndExpense;
  final double safeDailySpendRemaining;

  // Payment Methods
  final Map<String, double> paymentMethodExpenses;
  final Map<String, int> paymentMethodCounts;
  final Map<String, double> paymentMethodIncomes;
  final double digitalSpendPct;
  final double cashSpendPct;

  // Recurring costs
  final double recurringExpenseTotal;
  final int recurringExpenseCount;

  MonthlyReportData({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.budgetLimit,
    required this.budgetUtilization,
    required this.budgetRemaining,
    required this.categoryExpenses,
    required this.categoryTxCounts,
    required this.categoryAvgExpense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.topCategoryPercentage,
    this.highestExpense,
    required this.topExpenses,
    required this.topIncomes,
    required this.transactionCount,
    required this.incomeCount,
    required this.expenseCount,
    required this.avgDailyExpense,
    required this.avgExpensePerTx,
    required this.avgIncomePerTx,
    required this.activeSpendingDaysCount,
    required this.zeroSpendDaysCount,
    required this.healthScore,
    required this.healthGrade,
    required this.healthSummary,
    required this.healthScoreBreakdown,
    required this.actionableInsights,
    required this.prevMonthIncome,
    required this.prevMonthExpense,
    required this.prevMonthNetSavings,
    required this.incomeMoMChangePct,
    required this.expenseMoMChangePct,
    required this.netSavingsMoMChangePct,
    required this.fastestGrowingCategory,
    required this.fastestGrowingCategoryPct,
    required this.needsAmount,
    required this.needsPct,
    required this.wantsAmount,
    required this.wantsPct,
    required this.savingsInvestmentsAmount,
    required this.savingsInvestmentsPct,
    required this.rule503020Status,
    required this.dailyExpenses,
    required this.dailyIncomes,
    required this.highestSpendDay,
    required this.highestSpendDayAmount,
    required this.lowestSpendDay,
    required this.lowestSpendDayAmount,
    required this.weekendExpense,
    required this.weekendExpensePct,
    required this.weekdayExpense,
    required this.weekdayExpensePct,
    required this.isCurrentMonth,
    required this.projectedMonthEndExpense,
    required this.safeDailySpendRemaining,
    required this.paymentMethodExpenses,
    required this.paymentMethodCounts,
    required this.paymentMethodIncomes,
    required this.digitalSpendPct,
    required this.cashSpendPct,
    required this.recurringExpenseTotal,
    required this.recurringExpenseCount,
  });
}

class MonthlyReportService {
  static MonthlyReportData generateReport({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required DateTime targetMonth,
    List<CategoryModel>? categories,
  }) {
    final year = targetMonth.year;
    final month = targetMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = (now.year == year && now.month == month);

    // Filter transactions for target month & previous month
    final monthTxs = transactions.where((t) =>
        t.date.year == year && t.date.month == month).toList();

    final prevMonthDate = DateTime(year, month - 1, 1);
    final prevMonthTxs = transactions.where((t) =>
        t.date.year == prevMonthDate.year && t.date.month == prevMonthDate.month).toList();

    double income = 0.0;
    double expense = 0.0;
    int incCount = 0;
    int expCount = 0;

    final Map<String, double> categoryMap = {};
    final Map<String, int> categoryTxCounts = {};
    final Map<int, double> dailyExpenses = {};
    final Map<int, double> dailyIncomes = {};
    final Map<String, double> pmExpenses = {};
    final Map<String, int> pmCounts = {};
    final Map<String, double> pmIncomes = {};

    double recurringExpenseTotal = 0.0;
    int recurringExpenseCount = 0;

    List<CategoryModel> categoryList;
    if (categories != null && categories.isNotEmpty) {
      categoryList = categories;
    } else {
      try {
        categoryList = LocalStorageService.getCategories();
      } catch (_) {
        categoryList = AppConstants.defaultCategories;
      }
    }
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

    final List<TransactionModel> expenseTxs = [];
    final List<TransactionModel> incomeTxs = [];

    for (final t in monthTxs) {
      final day = t.date.day;
      final pm = t.paymentMethod.trim().isEmpty ? 'Cash' : t.paymentMethod.trim();

      if (t.type == TransactionType.income) {
        income += t.amount;
        incCount++;
        incomeTxs.add(t);
        dailyIncomes[day] = (dailyIncomes[day] ?? 0.0) + t.amount;
        pmIncomes[pm] = (pmIncomes[pm] ?? 0.0) + t.amount;
      } else if (t.type == TransactionType.expense) {
        if (!shouldDeduct(t.category)) continue;
        expense += t.amount;
        expCount++;
        expenseTxs.add(t);
        dailyExpenses[day] = (dailyExpenses[day] ?? 0.0) + t.amount;
        categoryMap[t.category] = (categoryMap[t.category] ?? 0.0) + t.amount;
        categoryTxCounts[t.category] = (categoryTxCounts[t.category] ?? 0) + 1;
        pmExpenses[pm] = (pmExpenses[pm] ?? 0.0) + t.amount;
        pmCounts[pm] = (pmCounts[pm] ?? 0) + 1;

        if (t.isRecurring) {
          recurringExpenseTotal += t.amount;
          recurringExpenseCount++;
        }
      }
    }

    final netSavings = income - expense;
    final savingsRate = income > 0 ? (netSavings / income) * 100.0 : (netSavings > 0 ? 100.0 : 0.0);

    // Sort category expenses descending
    final sortedCategories = Map<String, double>.fromEntries(
      categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    final Map<String, double> categoryAvgExpense = {};
    for (final entry in sortedCategories.entries) {
      final cnt = categoryTxCounts[entry.key] ?? 1;
      categoryAvgExpense[entry.key] = entry.value / (cnt > 0 ? cnt : 1);
    }

    final topCat = sortedCategories.isNotEmpty ? sortedCategories.keys.first : 'None';
    final topCatAmount = sortedCategories.isNotEmpty ? sortedCategories.values.first : 0.0;
    final topCatPct = expense > 0 ? (topCatAmount / expense) * 100.0 : 0.0;

    // Top transactions
    expenseTxs.sort((a, b) => b.amount.compareTo(a.amount));
    incomeTxs.sort((a, b) => b.amount.compareTo(a.amount));
    final maxExpenseTx = expenseTxs.isNotEmpty ? expenseTxs.first : null;
    final top5Expenses = expenseTxs.take(5).toList();
    final top5Incomes = incomeTxs.take(5).toList();

    // Daily & Burn Rate
    final activeDays = dailyExpenses.keys.where((d) => (dailyExpenses[d] ?? 0) > 0).length;
    final zeroSpendDays = daysInMonth - activeDays;
    final avgDaily = expense / (daysInMonth > 0 ? daysInMonth : 1);
    final avgExpPerTx = expCount > 0 ? (expense / expCount) : 0.0;
    final avgIncPerTx = incCount > 0 ? (income / incCount) : 0.0;

    int highestSpendDay = 1;
    double highestSpendDayAmount = 0.0;
    int lowestSpendDay = 1;
    double lowestSpendDayAmount = double.infinity;

    for (int d = 1; d <= daysInMonth; d++) {
      final sp = dailyExpenses[d] ?? 0.0;
      if (sp > highestSpendDayAmount) {
        highestSpendDayAmount = sp;
        highestSpendDay = d;
      }
      if (sp > 0 && sp < lowestSpendDayAmount) {
        lowestSpendDayAmount = sp;
        lowestSpendDay = d;
      }
    }
    if (lowestSpendDayAmount == double.infinity) lowestSpendDayAmount = 0.0;

    // Weekend vs Weekday analysis
    double weekendExpense = 0.0;
    double weekdayExpense = 0.0;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final sp = dailyExpenses[d] ?? 0.0;
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        weekendExpense += sp;
      } else {
        weekdayExpense += sp;
      }
    }
    final weekendExpensePct = expense > 0 ? (weekendExpense / expense) * 100.0 : 0.0;
    final weekdayExpensePct = expense > 0 ? (weekdayExpense / expense) * 100.0 : 0.0;

    // Budget Calculations
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
    final budgetRemaining = max(0.0, budgetLimit - expense);

    // Current Month Projection & Safe Daily Allowance
    double projectedExpense = expense;
    double safeDailyRemaining = 0.0;
    if (isCurrentMonth) {
      final passedDays = max(1, now.day);
      final remainingDays = max(1, daysInMonth - passedDays);
      final currentBurnRate = expense / passedDays;
      projectedExpense = expense + (currentBurnRate * (daysInMonth - passedDays));
      if (budgetLimit > 0) {
        safeDailyRemaining = max(0.0, (budgetLimit - expense) / remainingDays);
      } else {
        safeDailyRemaining = max(0.0, (income - expense) / remainingDays);
      }
    } else {
      projectedExpense = expense;
      safeDailyRemaining = 0.0;
    }

    // MoM (Month-over-Month) Computations
    double prevIncome = 0.0;
    double prevExpense = 0.0;
    final Map<String, double> prevCategoryMap = {};

    for (final t in prevMonthTxs) {
      if (t.type == TransactionType.income) {
        prevIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        if (!shouldDeduct(t.category)) continue;
        prevExpense += t.amount;
        prevCategoryMap[t.category] = (prevCategoryMap[t.category] ?? 0.0) + t.amount;
      }
    }
    final prevNetSavings = prevIncome - prevExpense;

    final incomeMoM = prevIncome > 0 ? ((income - prevIncome) / prevIncome) * 100.0 : (income > 0 ? 100.0 : 0.0);
    final expenseMoM = prevExpense > 0 ? ((expense - prevExpense) / prevExpense) * 100.0 : (expense > 0 ? 100.0 : 0.0);
    final netSavingsMoM = prevNetSavings.abs() > 0 ? ((netSavings - prevNetSavings) / prevNetSavings.abs()) * 100.0 : (netSavings > 0 ? 100.0 : 0.0);

    // Fastest growing category MoM
    String fastestGrowingCat = 'None';
    double fastestGrowingPct = 0.0;
    for (final entry in sortedCategories.entries) {
      final prevCatAmt = prevCategoryMap[entry.key] ?? 0.0;
      if (prevCatAmt > 0) {
        final pct = ((entry.value - prevCatAmt) / prevCatAmt) * 100.0;
        if (pct > fastestGrowingPct) {
          fastestGrowingPct = pct;
          fastestGrowingCat = entry.key;
        }
      } else if (entry.value > 0 && fastestGrowingCat == 'None') {
        fastestGrowingCat = entry.key;
        fastestGrowingPct = 100.0;
      }
    }

    // 50/30/20 Rule Classification
    double needs = 0.0;
    double wants = 0.0;
    double savingsInvest = 0.0;

    const needsKeywords = {'rent', 'grocery', 'bills', 'medical', 'fuel', 'education', 'utilities', 'health', 'maintenance', 'housing', 'emi', 'insurance'};
    const wantsKeywords = {'shopping', 'food', 'dining', 'entertainment', 'travel', 'movie', 'cafe', 'hobbies', 'lifestyle', 'gadgets', 'vacation', 'subscription'};
    const investKeywords = {'investment', 'savings', 'mutual fund', 'stocks', 'emergency', 'gold', 'crypto', 'fd', 'rd'};

    for (final entry in sortedCategories.entries) {
      final catLower = entry.key.toLowerCase();
      if (investKeywords.any((k) => catLower.contains(k))) {
        savingsInvest += entry.value;
      } else if (needsKeywords.any((k) => catLower.contains(k))) {
        needs += entry.value;
      } else if (wantsKeywords.any((k) => catLower.contains(k))) {
        wants += entry.value;
      } else {
        // General default split
        wants += entry.value;
      }
    }

    // Add remaining net savings into savings/investments for 50/30/20 computation
    if (netSavings > 0) {
      savingsInvest += netSavings;
    }

    final total503020 = needs + wants + savingsInvest;
    final needsPct = total503020 > 0 ? (needs / total503020) * 100.0 : 0.0;
    final wantsPct = total503020 > 0 ? (wants / total503020) * 100.0 : 0.0;
    final savingsInvestPct = total503020 > 0 ? (savingsInvest / total503020) * 100.0 : 0.0;

    String rule503020Status = 'Balanced';
    if (savingsInvestPct >= 20.0 && needsPct <= 55.0 && wantsPct <= 35.0) {
      rule503020Status = 'Optimal (50/30/20 Met)';
    } else if (wantsPct > 35.0) {
      rule503020Status = 'Wants Heavy (${wantsPct.toStringAsFixed(0)}%)';
    } else if (needsPct > 60.0) {
      rule503020Status = 'Needs Heavy (${needsPct.toStringAsFixed(0)}%)';
    } else if (savingsRate < 10.0) {
      rule503020Status = 'Low Savings Capacity';
    }

    // Payment methods calculations
    final sortedPm = Map<String, double>.fromEntries(
      pmExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    double digitalSpend = 0.0;
    double cashSpend = 0.0;
    for (final entry in sortedPm.entries) {
      if (entry.key.toLowerCase().contains('cash')) {
        cashSpend += entry.value;
      } else {
        digitalSpend += entry.value;
      }
    }
    final digitalSpendPct = expense > 0 ? (digitalSpend / expense) * 100.0 : 0.0;
    final cashSpendPct = expense > 0 ? (cashSpend / expense) * 100.0 : 0.0;

    // Advanced Composite Health Score (0 - 100 pts)
    // 1. Savings Score (Max 35 pts)
    int savingsScore = 0;
    if (savingsRate >= 40) {
      savingsScore = 35;
    } else if (savingsRate >= 25) {
      savingsScore = 30;
    } else if (savingsRate >= 15) {
      savingsScore = 24;
    } else if (savingsRate >= 5) {
      savingsScore = 16;
    } else if (savingsRate >= 0) {
      savingsScore = 10;
    } else {
      savingsScore = 0;
    }

    // 2. Budget Discipline Score (Max 30 pts)
    int budgetScore = 0;
    if (budgetLimit <= 0) {
      budgetScore = 22; // Neutral default if no budget set
    } else if (budgetUtilization <= 80) {
      budgetScore = 30;
    } else if (budgetUtilization <= 100) {
      budgetScore = 24;
    } else if (budgetUtilization <= 115) {
      budgetScore = 12;
    } else {
      budgetScore = 4;
    }

    // 3. Consistency & Outlier Score (Max 20 pts)
    int consistencyScore = 15;
    if (expense > 0 && maxExpenseTx != null) {
      final outlierFraction = maxExpenseTx.amount / expense;
      if (outlierFraction < 0.3) {
        consistencyScore = 20;
      } else if (outlierFraction < 0.5) {
        consistencyScore = 14;
      } else {
        consistencyScore = 8;
      }
    }

    // 4. Needs / Wants Balance Score (Max 15 pts)
    int balanceScore = 10;
    if (wantsPct <= 30 && needsPct <= 55) {
      balanceScore = 15;
    } else if (wantsPct <= 45) {
      balanceScore = 11;
    } else {
      balanceScore = 6;
    }

    final int totalHealthScore = (savingsScore + budgetScore + consistencyScore + balanceScore).clamp(0, 100);

    String grade = 'B';
    if (expense == 0 && income == 0) {
      grade = 'N/A';
    } else if (totalHealthScore >= 90) {
      grade = 'A+';
    } else if (totalHealthScore >= 80) {
      grade = 'A';
    } else if (totalHealthScore >= 70) {
      grade = 'B+';
    } else if (totalHealthScore >= 60) {
      grade = 'B';
    } else if (totalHealthScore >= 50) {
      grade = 'C';
    } else {
      grade = 'D';
    }

    // Actionable AI Financial Insights
    final List<String> insights = [];

    if (expense == 0 && income == 0) {
      insights.add('No transactions recorded for this period.');
    } else {
      if (savingsRate >= 30) {
        insights.add('🌟 Stellar savings rate of ${savingsRate.toStringAsFixed(1)}% achieved this month.');
      } else if (savingsRate < 0) {
        insights.add('⚠️ Cash deficit alert: Monthly outflows exceeded total income by ${(-netSavings).toStringAsFixed(0)}.');
      } else {
        insights.add('💡 You saved ${savingsRate.toStringAsFixed(1)}% of your income. Aim for 20%+ for long-term growth.');
      }

      if (topCat != 'None') {
        insights.add('📊 Largest spending category was $topCat taking ${topCatPct.toStringAsFixed(1)}% of total outflows.');
      }

      if (weekendExpensePct > 45) {
        insights.add('🗓️ Weekend spending spiked to ${weekendExpensePct.toStringAsFixed(0)}% of monthly total.');
      }

      if (expenseMoM > 15) {
        insights.add('📈 Total expenses grew by +${expenseMoM.toStringAsFixed(0)}% compared to last month.');
      } else if (expenseMoM < -10) {
        insights.add('🎉 Great discipline! Expenses reduced by ${(-expenseMoM).toStringAsFixed(0)}% vs last month.');
      }

      if (fastestGrowingCat != 'None' && fastestGrowingPct > 20) {
        insights.add('⚡ $fastestGrowingCat surged by +${fastestGrowingPct.toStringAsFixed(0)}% vs previous month.');
      }

      if (budgetLimit > 0) {
        if (budgetUtilization > 100) {
          insights.add('🚨 Budget exceeded by ${(budgetUtilization - 100).toStringAsFixed(0)}%. Consider tightening non-essentials.');
        } else {
          insights.add('🎯 On track: ${budgetUtilization.toStringAsFixed(0)}% of your overall monthly budget used.');
        }
      }
    }

    String summaryText = 'Balanced monthly financial performance.';
    if (grade == 'A+' || grade == 'A') {
      summaryText = 'Outstanding financial discipline with strong savings and controlled category expenses.';
    } else if (grade == 'B+' || grade == 'B') {
      summaryText = 'Stable cash flow with positive savings. Minor optimization in discretionary spending recommended.';
    } else if (grade == 'C') {
      summaryText = 'Budget pressure detected. Review top category allocations to improve your savings rate.';
    } else if (grade == 'D') {
      summaryText = 'Expenses exceeded income this month. Prioritize essential spending and curtail outlier expenses.';
    } else {
      summaryText = 'No financial activity logged for this period.';
    }

    return MonthlyReportData(
      month: DateTime(year, month, 1),
      totalIncome: income,
      totalExpense: expense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      budgetLimit: budgetLimit,
      budgetUtilization: budgetUtilization,
      budgetRemaining: budgetRemaining,
      categoryExpenses: sortedCategories,
      categoryTxCounts: categoryTxCounts,
      categoryAvgExpense: categoryAvgExpense,
      topCategory: topCat,
      topCategoryAmount: topCatAmount,
      topCategoryPercentage: topCatPct,
      highestExpense: maxExpenseTx,
      topExpenses: top5Expenses,
      topIncomes: top5Incomes,
      transactionCount: monthTxs.length,
      incomeCount: incCount,
      expenseCount: expCount,
      avgDailyExpense: avgDaily,
      avgExpensePerTx: avgExpPerTx,
      avgIncomePerTx: avgIncPerTx,
      activeSpendingDaysCount: activeDays,
      zeroSpendDaysCount: zeroSpendDays,
      healthScore: totalHealthScore,
      healthGrade: grade,
      healthSummary: summaryText,
      healthScoreBreakdown: {
        'Savings (35)': savingsScore,
        'Budget Adherence (30)': budgetScore,
        'Consistency (20)': consistencyScore,
        'Needs/Wants Balance (15)': balanceScore,
      },
      actionableInsights: insights,
      prevMonthIncome: prevIncome,
      prevMonthExpense: prevExpense,
      prevMonthNetSavings: prevNetSavings,
      incomeMoMChangePct: incomeMoM,
      expenseMoMChangePct: expenseMoM,
      netSavingsMoMChangePct: netSavingsMoM,
      fastestGrowingCategory: fastestGrowingCat,
      fastestGrowingCategoryPct: fastestGrowingPct,
      needsAmount: needs,
      needsPct: needsPct,
      wantsAmount: wants,
      wantsPct: wantsPct,
      savingsInvestmentsAmount: savingsInvest,
      savingsInvestmentsPct: savingsInvestPct,
      rule503020Status: rule503020Status,
      dailyExpenses: dailyExpenses,
      dailyIncomes: dailyIncomes,
      highestSpendDay: highestSpendDay,
      highestSpendDayAmount: highestSpendDayAmount,
      lowestSpendDay: lowestSpendDay,
      lowestSpendDayAmount: lowestSpendDayAmount,
      weekendExpense: weekendExpense,
      weekendExpensePct: weekendExpensePct,
      weekdayExpense: weekdayExpense,
      weekdayExpensePct: weekdayExpensePct,
      isCurrentMonth: isCurrentMonth,
      projectedMonthEndExpense: projectedExpense,
      safeDailySpendRemaining: safeDailyRemaining,
      paymentMethodExpenses: sortedPm,
      paymentMethodCounts: pmCounts,
      paymentMethodIncomes: pmIncomes,
      digitalSpendPct: digitalSpendPct,
      cashSpendPct: cashSpendPct,
      recurringExpenseTotal: recurringExpenseTotal,
      recurringExpenseCount: recurringExpenseCount,
    );
  }
}
