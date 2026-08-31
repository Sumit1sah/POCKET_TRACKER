import '../models/transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../utils/formatters.dart';

class AIInsight {
  final String title;
  final String description;
  final String type; // 'health_score', 'critical', 'warning', 'positive', 'tip', 'prediction'
  final String? category;
  final double? impactAmount;
  final int? healthScore;
  final String? actionLabel;
  final String? actionRoute;

  AIInsight({
    required this.title,
    required this.description,
    required this.type,
    this.category,
    this.impactAmount,
    this.healthScore,
    this.actionLabel,
    this.actionRoute,
  });
}

class BudgetInsightData {
  final double overallLimit;
  final double totalSpent;
  final Map<String, double> categoryLimits;
  final Map<String, double> categorySpend;

  const BudgetInsightData({
    required this.overallLimit,
    required this.totalSpent,
    required this.categoryLimits,
    required this.categorySpend,
  });

  double get remaining => overallLimit - totalSpent;
  double get usagePercent => overallLimit > 0 ? totalSpent / overallLimit : 0;
}

class AIInsightService {
  static List<AIInsight> generateInsights(
    List<TransactionModel> transactions,
    String currencySymbol, {
    BudgetInsightData? budget,
    List<SavingsGoalModel>? savingsGoals,
    double? totalCreditLimit,
    double? liquidBalance,
  }) {
    final List<AIInsight> insights = [];

    if (transactions.isEmpty) {
      insights.add(AIInsight(
        title: '👋 Welcome to Pocketify AI Insights!',
        description:
            'Start logging your daily income and expenses to unlock intelligent financial health scores, subscription tracking, and predictive budget forecasting.',
        type: 'tip',
        actionLabel: 'Add First Transaction',
        actionRoute: '/add_transaction',
      ));
      return insights;
    }

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final daysRemaining = daysInMonth - daysPassed;

    // Current & previous month income and expenses
    final currentMonthTxs = transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();

    final currentMonthExpenses = currentMonthTxs
        .where((t) => t.type == TransactionType.expense)
        .toList();

    final currentMonthIncome = currentMonthTxs
        .where((t) => t.type == TransactionType.income)
        .toList();

    final prevMonthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            (now.month == 1
                ? (t.date.year == now.year - 1 && t.date.month == 12)
                : (t.date.year == now.year &&
                    t.date.month == now.month - 1)))
        .toList();

    final totalCurrentExpense = currentMonthExpenses.fold(0.0, (s, t) => s + t.amount);
    final totalCurrentIncome = currentMonthIncome.fold(0.0, (s, t) => s + t.amount);
    final totalPrevExpense = prevMonthExpenses.fold(0.0, (s, t) => s + t.amount);

    // All-time income & expense
    final allTimeIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final allTimeExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    final netSavingsMonth = totalCurrentIncome - totalCurrentExpense;

    // ══════════════════════════════════════════════
    // 1. FINANCIAL HEALTH SCORE (0 - 100 Index)
    // ══════════════════════════════════════════════
    int savingsScore = 0;
    if (totalCurrentIncome > 0) {
      final savingsRatio = netSavingsMonth / totalCurrentIncome;
      if (savingsRatio >= 0.30) {
        savingsScore = 40;
      } else if (savingsRatio >= 0.20) {
        savingsScore = 32;
      } else if (savingsRatio >= 0.10) {
        savingsScore = 22;
      } else if (savingsRatio > 0) {
        savingsScore = 12;
      } else {
        savingsScore = 0;
      }
    } else if (allTimeIncome > 0 && (allTimeIncome - allTimeExpense) > 0) {
      savingsScore = 25;
    } else {
      savingsScore = 15;
    }

    int budgetScore = 30;
    if (budget != null && budget.overallLimit > 0) {
      if (budget.usagePercent > 1.0) {
        budgetScore = 5;
      } else if (budget.usagePercent > 0.9) {
        budgetScore = 15;
      } else if (budget.usagePercent > 0.75) {
        budgetScore = 22;
      } else {
        budgetScore = 30;
      }
    }

    int creditScoreComponent = 15;
    if (totalCreditLimit != null && totalCreditLimit > 0) {
      final ccSpent = transactions
          .where((t) => t.paymentMethod == 'Credit Card')
          .fold(0.0, (s, t) => s + (t.type == TransactionType.expense ? t.amount : -t.amount))
          .clamp(0.0, double.infinity);
      final util = ccSpent / totalCreditLimit;
      if (util <= 0.30) {
        creditScoreComponent = 15;
      } else if (util <= 0.50) {
        creditScoreComponent = 10;
      } else if (util <= 0.75) {
        creditScoreComponent = 5;
      } else {
        creditScoreComponent = 0;
      }
    }

    int goalScoreComponent = 15;
    if (savingsGoals != null && savingsGoals.isNotEmpty) {
      final totalTarget = savingsGoals.fold(0.0, (s, g) => s + g.targetAmount);
      final totalSaved = savingsGoals.fold(0.0, (s, g) => s + g.savedAmount);
      if (totalTarget > 0) {
        final goalPct = totalSaved / totalTarget;
        goalScoreComponent = (goalPct * 15).clamp(5, 15).toInt();
      }
    }

    final totalHealthScore = (savingsScore + budgetScore + creditScoreComponent + goalScoreComponent).clamp(0, 100);

    String healthGrade = 'Excellent';
    String healthEmoji = '🌟';
    if (totalHealthScore < 50) {
      healthGrade = 'Needs Attention';
      healthEmoji = '⚠️';
    } else if (totalHealthScore < 70) {
      healthGrade = 'Fair';
      healthEmoji = '📈';
    } else if (totalHealthScore < 85) {
      healthGrade = 'Good';
      healthEmoji = '💪';
    }

    insights.add(AIInsight(
      title: '$healthEmoji Pocketify Financial Health: $totalHealthScore/100 ($healthGrade)',
      description:
          'Based on your monthly savings ratio, budget adherence, and credit utilization. '
          '${totalCurrentIncome > 0 ? "You saved ${((netSavingsMonth / totalCurrentIncome) * 100).toStringAsFixed(0)}% of income this month." : "Log income to track your net savings ratio."}',
      type: 'health_score',
      healthScore: totalHealthScore,
      actionLabel: 'View Monthly Report',
      actionRoute: '/monthly_report',
    ));

    // ══════════════════════════════════════════════
    // 2. PREDICTIVE SAVINGS GOAL COMPLETION ENGINE
    // ══════════════════════════════════════════════
    if (savingsGoals != null && savingsGoals.isNotEmpty && netSavingsMonth > 0) {
      final incompleteGoals = savingsGoals.where((g) => g.savedAmount < g.targetAmount).toList();
      if (incompleteGoals.isNotEmpty) {
        final topGoal = incompleteGoals.first;
        final remainingGoal = topGoal.targetAmount - topGoal.savedAmount;
        final monthsNeeded = remainingGoal / netSavingsMonth;

        if (monthsNeeded <= 1.0) {
          insights.add(AIInsight(
            title: '🎯 ${topGoal.title} Goal Reachable This Month!',
            description:
                'Only ${Formatters.formatCurrency(remainingGoal, symbol: currencySymbol)} remaining for "${topGoal.title}". '
                'At your current savings pace of ${Formatters.formatCurrency(netSavingsMonth, symbol: currencySymbol)}/mo, '
                'you can fully achieve this goal before month end!',
            type: 'prediction',
            impactAmount: remainingGoal,
            actionLabel: 'Deposit to Goal',
            actionRoute: '/savings',
          ));
        } else if (monthsNeeded <= 12.0) {
          final estimatedDays = (monthsNeeded * 30).round();
          insights.add(AIInsight(
            title: '🔮 Target Forecast: ${topGoal.title}',
            description:
                'At your current net saving velocity of ${Formatters.formatCurrency(netSavingsMonth, symbol: currencySymbol)}/mo, '
                'you will reach your ${Formatters.formatCurrency(topGoal.targetAmount, symbol: currencySymbol)} target in ~$estimatedDays days (${monthsNeeded.toStringAsFixed(1)} months).',
            type: 'prediction',
            impactAmount: remainingGoal,
            actionLabel: 'View Savings Goals',
            actionRoute: '/savings',
          ));
        }
      }
    }

    // ══════════════════════════════════════════════
    // 3. RECURRING SUBSCRIPTION & OUTFLOW DETECTOR
    // ══════════════════════════════════════════════
    final Map<String, List<TransactionModel>> categoryGroup = {};
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      final key = '${t.category}_${t.description.toLowerCase().trim()}';
      categoryGroup.putIfAbsent(key, () => []).add(t);
    }

    final recurringItems = <String, double>{};
    for (final entry in categoryGroup.entries) {
      if (entry.value.length >= 2) {
        final amounts = entry.value.map((e) => e.amount).toList();
        final firstAmt = amounts.first;
        final isFixed = amounts.every((a) => (a - firstAmt).abs() < 10.0);
        if (isFixed && firstAmt > 0) {
          final name = entry.value.first.description.isNotEmpty
              ? entry.value.first.description
              : entry.value.first.category;
          recurringItems[name] = firstAmt;
        }
      }
    }

    if (recurringItems.isNotEmpty) {
      final totalMonthlyRec = recurringItems.values.fold(0.0, (s, a) => s + a);
      final yearlyCost = totalMonthlyRec * 12;
      final topRecName = recurringItems.keys.first;

      insights.add(AIInsight(
        title: '🔄 ${recurringItems.length} Active Recurring Subscriptions Detected',
        description:
            'You have ~${Formatters.formatCurrency(totalMonthlyRec, symbol: currencySymbol)}/mo in fixed recurring bills (e.g., $topRecName). '
            'That amounts to ${Formatters.formatCurrency(yearlyCost, symbol: currencySymbol)} annually.',
        type: 'tip',
        impactAmount: totalMonthlyRec,
        actionLabel: 'Review Bills',
        actionRoute: '/analytics',
      ));
    }

    // ══════════════════════════════════════════════
    // 4. IMPULSE SPENDING & ANOMALY DETECTOR
    // ══════════════════════════════════════════════
    if (currentMonthExpenses.length >= 3) {
      final avgSpend = totalCurrentExpense / currentMonthExpenses.length;
      final highSpikes = currentMonthExpenses.where((t) => t.amount > (avgSpend * 3.0) && t.amount > 500).toList();

      if (highSpikes.isNotEmpty) {
        final spike = highSpikes.first;
        insights.add(AIInsight(
          title: '⚡ High-Value Purchase Anomaly',
          description:
              'Detected a single transaction of ${Formatters.formatCurrency(spike.amount, symbol: currencySymbol)} '
              'at ${spike.description.isNotEmpty ? spike.description : spike.category} on ${Formatters.formatShortDate(spike.date)} '
              '(${(spike.amount / avgSpend).toStringAsFixed(1)}x your average purchase). '
              'High-value impulse buys accelerate monthly budget burn.',
          type: 'warning',
          category: spike.category,
          impactAmount: spike.amount,
          actionLabel: 'View Transaction',
          actionRoute: '/transactions',
        ));
      }
    }

    // ══════════════════════════════════════════════
    // 5. CREDIT CARD UTILIZATION & INTEREST RISK
    // ══════════════════════════════════════════════
    if (totalCreditLimit != null && totalCreditLimit > 0) {
      final ccExpenses = transactions
          .where((t) => t.paymentMethod == 'Credit Card')
          .fold(0.0, (s, t) => s + (t.type == TransactionType.expense ? t.amount : -t.amount))
          .clamp(0.0, double.infinity);
      final utilRatio = ccExpenses / totalCreditLimit;

      if (utilRatio > 0.70) {
        insights.add(AIInsight(
          title: '🚨 High Credit Card Utilization (${(utilRatio * 100).toStringAsFixed(0)}%)',
          description:
              'You\'ve spent ${Formatters.formatCurrency(ccExpenses, symbol: currencySymbol)} out of your '
              '${Formatters.formatCurrency(totalCreditLimit, symbol: currencySymbol)} credit limit. '
              'High card balance (>70%) can trigger high finance interest charges and lower credit score.',
          type: 'critical',
          impactAmount: ccExpenses,
          actionLabel: 'Manage Card Limits',
          actionRoute: '/home',
        ));
      } else if (utilRatio > 0.30) {
        insights.add(AIInsight(
          title: '💳 Credit Card Usage Alert',
          description:
              'Card utilization is at ${(utilRatio * 100).toStringAsFixed(0)}% '
              '(${Formatters.formatCurrency(ccExpenses, symbol: currencySymbol)} spent). '
              'Financial experts recommend keeping card usage below 30% for optimal credit health.',
          type: 'warning',
          impactAmount: ccExpenses,
        ));
      }
    }

    // ══════════════════════════════════════════════
    // 6. BUDGET-INTEGRATED INSIGHTS
    // ══════════════════════════════════════════════
    if (budget != null && budget.overallLimit > 0) {
      final usedPct = budget.usagePercent;
      final expectedPacePct = daysPassed / daysInMonth;

      if (usedPct > 1.0) {
        final overspend = budget.totalSpent - budget.overallLimit;
        insights.add(AIInsight(
          title: '🚨 Monthly Budget Exceeded!',
          description:
              'Spent ${Formatters.formatCurrency(budget.totalSpent, symbol: currencySymbol)} '
              'against limit of ${Formatters.formatCurrency(budget.overallLimit, symbol: currencySymbol)}. '
              'Overspent by ${Formatters.formatCurrency(overspend, symbol: currencySymbol)}. '
              'Pause non-essential expenses immediately.',
          type: 'critical',
          impactAmount: overspend,
          actionLabel: 'Rebalance Budget',
          actionRoute: '/budget',
        ));
      } else if (usedPct > 0.90) {
        insights.add(AIInsight(
          title: '⚠️ Budget Almost Exhausted',
          description:
              'You\'ve consumed ${(usedPct * 100).toStringAsFixed(0)}% of your budget with $daysRemaining days left. '
              'Only ${Formatters.formatCurrency(budget.remaining, symbol: currencySymbol)} remaining.',
          type: 'warning',
          impactAmount: budget.remaining,
          actionLabel: 'Manage Budget',
          actionRoute: '/budget',
        ));
      } else if (usedPct > expectedPacePct + 0.10) {
        final projectedTotal = daysPassed > 0
            ? (budget.totalSpent / daysPassed * daysInMonth)
            : budget.totalSpent;
        final projectedOverrun = projectedTotal - budget.overallLimit;
        if (projectedOverrun > 0) {
          insights.add(AIInsight(
            title: '📈 Fast Spending Velocity',
            description:
                'At your current rate, you\'ll reach ${Formatters.formatCurrency(projectedTotal, symbol: currencySymbol)} '
                'by month end (${Formatters.formatCurrency(projectedOverrun, symbol: currencySymbol)} over limit). '
                'Slow down daily pace to stay safe.',
            type: 'warning',
            impactAmount: projectedOverrun,
            actionLabel: 'Adjust Pace',
            actionRoute: '/budget',
          ));
        }
      } else if (usedPct < expectedPacePct - 0.15 && daysPassed > 5) {
        insights.add(AIInsight(
          title: '✅ Excellent Budget Control',
          description:
              'Only ${(usedPct * 100).toStringAsFixed(0)}% of budget used by day $daysPassed. '
              '${Formatters.formatCurrency(budget.remaining, symbol: currencySymbol)} remaining. '
              'You\'re well ahead of pace — consider routing surplus to savings goals!',
          type: 'positive',
          impactAmount: budget.remaining,
          actionLabel: 'Route to Savings',
          actionRoute: '/savings',
        ));
      }

      // Daily safe-to-spend calculation
      if (daysRemaining > 0 && budget.remaining > 0) {
        final dailySafe = budget.remaining / daysRemaining;
        insights.add(AIInsight(
          title: '📅 Daily Safe-to-Spend: ${Formatters.formatCurrency(dailySafe, symbol: currencySymbol)}/day',
          description:
              'To finish the remaining $daysRemaining days within your '
              '${Formatters.formatCurrency(budget.overallLimit, symbol: currencySymbol)} monthly limit, '
              'keep daily expenses under ${Formatters.formatCurrency(dailySafe, symbol: currencySymbol)}.',
          type: 'tip',
          impactAmount: dailySafe,
        ));
      }
    } else {
      insights.add(AIInsight(
        title: '💡 Unlock Smart Budget Tracking',
        description:
            'You haven\'t configured a monthly budget yet. Head to the Budget screen and tap Smart Auto-Allocate '
            'to enable dynamic pace forecasting.',
        type: 'tip',
        actionLabel: 'Setup Budget',
        actionRoute: '/budget',
      ));
    }

    // ══════════════════════════════════════════════
    // 7. MONTH-OVER-MONTH COMPARISON
    // ══════════════════════════════════════════════
    if (totalPrevExpense > 0) {
      final diffPct = ((totalCurrentExpense - totalPrevExpense) / totalPrevExpense * 100).round();
      if (diffPct > 15) {
        insights.add(AIInsight(
          title: '📊 Spending Up +$diffPct% vs Last Month',
          description:
              'You\'ve spent ${Formatters.formatCurrency(totalCurrentExpense, symbol: currencySymbol)} this month vs '
              '${Formatters.formatCurrency(totalPrevExpense, symbol: currencySymbol)} last month. '
              'Check recent category trends in Analytics.',
          type: 'warning',
          impactAmount: totalCurrentExpense - totalPrevExpense,
          actionLabel: 'View Analytics',
          actionRoute: '/analytics',
        ));
      } else if (diffPct < -10) {
        insights.add(AIInsight(
          title: '🎉 Spending Down ${diffPct.abs()}% vs Last Month',
          description:
              'Great job! You\'re spending ${diffPct.abs()}% less than last month, '
              'saving ${Formatters.formatCurrency(totalPrevExpense - totalCurrentExpense, symbol: currencySymbol)} extra.',
          type: 'positive',
          impactAmount: totalPrevExpense - totalCurrentExpense,
        ));
      }
    }

    // ══════════════════════════════════════════════
    // 8. DYNAMIC FINANCIAL WISDOM & MONEY TIPS
    // ══════════════════════════════════════════════

    // A. 50/30/20 Budgeting Rule Analysis
    final needsCategories = {'Bills', 'Groceries', 'Utilities', 'Rent', 'Health', 'Transport', 'Education', 'Insurance', 'Fuel', 'EMI', 'Debt / Repayment', 'Money Given / Lent'};
    final wantsCategories = {'Food', 'Dining', 'Shopping', 'Entertainment', 'Travel', 'Personal Care', 'Electronics', 'Gifts'};

    final needsSpend = currentMonthExpenses
        .where((t) => needsCategories.contains(t.category))
        .fold(0.0, (s, t) => s + t.amount);

    final wantsSpend = currentMonthExpenses
        .where((t) => wantsCategories.contains(t.category))
        .fold(0.0, (s, t) => s + t.amount);

    if (totalCurrentIncome > 0) {
      final needsPct = (needsSpend / totalCurrentIncome * 100).round();
      final wantsPct = (wantsSpend / totalCurrentIncome * 100).round();
      final savingsPct = (netSavingsMonth / totalCurrentIncome * 100).round();

      String tipAdvice = '';
      if (savingsPct >= 20) {
        tipAdvice = 'Awesome! Your savings ratio ($savingsPct%) hits the recommended 20% target.';
      } else if (wantsPct > 30) {
        tipAdvice = 'Your discretionary Wants spending is $wantsPct% (target: <=30%). Trim dining or shopping to save more.';
      } else if (needsPct > 50) {
        tipAdvice = 'Essential Needs take up $needsPct% of income (target: <=50%). Look for ways to lower recurring utility/bill costs.';
      } else {
        tipAdvice = 'Aim to push monthly savings up from $savingsPct% closer to 20%.';
      }

      insights.add(AIInsight(
        title: '💡 Money Tip: 50/30/20 Budget Rule Breakdown',
        description:
            'Monthly income allocation: $needsPct% Needs, $wantsPct% Wants, $savingsPct% Savings. '
            'The ideal benchmark is 50% Needs, 30% Wants, 20% Savings. $tipAdvice',
        type: 'tip',
        actionLabel: 'View Budgeting',
        actionRoute: '/budget',
      ));
    } else {
      insights.add(AIInsight(
        title: '💡 Money Tip: Master the 50/30/20 Rule',
        description:
            'Allocate 50% of your earnings to Needs (rent, groceries), 30% to Wants (dining, fun), and 20% directly to Savings or debt payoff.',
        type: 'tip',
        actionLabel: 'Setup Budget',
        actionRoute: '/budget',
      ));
    }

    // B. Emergency Safety Buffer Fund Tip
    final monthlyExpensePace = totalCurrentExpense > 0
        ? totalCurrentExpense
        : (allTimeExpense > 0 ? allTimeExpense : 10000.0);
    final minReserve = monthlyExpensePace * 3;
    final maxReserve = monthlyExpensePace * 6;

    insights.add(AIInsight(
      title: '🛡️ Money Tip: Build a 3-6 Month Safety Buffer',
      description:
          'Financial security starts with an emergency fund. Based on your current spend pace of ${Formatters.formatCurrency(monthlyExpensePace, symbol: currencySymbol)}/mo, '
          'aim to keep ${Formatters.formatCurrency(minReserve, symbol: currencySymbol)} to ${Formatters.formatCurrency(maxReserve, symbol: currencySymbol)} in a high-yield liquid account.',
      type: 'tip',
      impactAmount: minReserve,
      actionLabel: 'Add Savings Goal',
      actionRoute: '/savings',
    ));

    // C. "Pay Yourself First" Rule
    insights.add(AIInsight(
      title: '💸 Money Tip: Pay Yourself First Rule',
      description:
          'Set up automatic transfers of 10-20% of your income into your savings or investment account right on payday, before spending on discretionary desires.',
      type: 'tip',
      actionLabel: 'Create Goal',
      actionRoute: '/savings',
    ));

    // D. Category Savings Advice (Food & Dining or Shopping)
    final foodSpend = currentMonthExpenses
        .where((t) => t.category == 'Food' || t.category == 'Dining')
        .fold(0.0, (s, t) => s + t.amount);
    final shoppingSpend = currentMonthExpenses
        .where((t) => t.category == 'Shopping')
        .fold(0.0, (s, t) => s + t.amount);

    if (totalCurrentExpense > 0 && foodSpend / totalCurrentExpense > 0.25 && foodSpend > 300) {
      final potentialSavings = foodSpend * 0.25;
      insights.add(AIInsight(
        title: '🍳 Money Tip: Cut Food & Dining Costs',
        description:
            'Food & Dining makes up ${(foodSpend / totalCurrentExpense * 100).toStringAsFixed(0)}% '
            '(${Formatters.formatCurrency(foodSpend, symbol: currencySymbol)}) of your expenses. '
            'Preparing home meals just 2 extra days a week can save up to ${Formatters.formatCurrency(potentialSavings, symbol: currencySymbol)} monthly.',
        type: 'tip',
        category: 'Food',
        impactAmount: potentialSavings,
        actionLabel: 'View Food Expenses',
        actionRoute: '/transactions',
      ));
    }

    if (totalCurrentExpense > 0 && shoppingSpend / totalCurrentExpense > 0.20 && shoppingSpend > 300) {
      final potentialSavings = shoppingSpend * 0.20;
      insights.add(AIInsight(
        title: '🛍️ Money Tip: The 24-Hour Purchase Delay Rule',
        description:
            'Shopping accounts for ${(shoppingSpend / totalCurrentExpense * 100).toStringAsFixed(0)}% '
            '(${Formatters.formatCurrency(shoppingSpend, symbol: currencySymbol)}) of monthly spend. '
            'Before non-essential purchases, wait 24 hours — over 60% of impulse buys fade after reflection.',
        type: 'tip',
        category: 'Shopping',
        impactAmount: potentialSavings,
        actionLabel: 'View Shopping',
        actionRoute: '/transactions',
      ));
    }

    // E. Debt Avalanche & Credit Card Wisdom Tip (if credit card is used)
    final ccExpensesCount = currentMonthExpenses.where((t) => t.paymentMethod == 'Credit Card').length;
    if (ccExpensesCount > 0 || (totalCreditLimit != null && totalCreditLimit > 0)) {
      insights.add(AIInsight(
        title: '⚡ Money Tip: Debt Avalanche & Card Discipline',
        description:
            'Always clear your full credit card balance before the due date to avoid high annual interest charges. '
            'If paying debt, prioritize the highest interest balance first to save maximum money.',
        type: 'tip',
      ));
    }

    // ══════════════════════════════════════════════
    // 9. CONDITIONAL "NEEDED ONLY IF" FINANCIAL HEALTH ENGINES
    // ══════════════════════════════════════════════

    // 1. Deficit Spending Alert (Triggered ONLY IF Monthly Expense > Monthly Income)
    if (totalCurrentIncome > 0 && totalCurrentExpense > totalCurrentIncome) {
      final deficit = totalCurrentExpense - totalCurrentIncome;
      insights.add(AIInsight(
        title: '🚨 Health Alert: Monthly Deficit Spending',
        description:
            'You are currently spending ${Formatters.formatCurrency(deficit, symbol: currencySymbol)} more than your income this month '
            '(${((totalCurrentExpense / totalCurrentIncome - 1) * 100).toStringAsFixed(0)}% overrun). '
            'Deficit spending drains emergency reserves and forces debt. Pause non-essential purchases.',
        type: 'critical',
        impactAmount: deficit,
        actionLabel: 'Rebalance Budget',
        actionRoute: '/budget',
      ));
    }

    // 2. Emergency Safety Runway Alert (Triggered ONLY IF Liquid Reserves < 3 Months of Expenses)
    if (liquidBalance != null && liquidBalance >= 0 && monthlyExpensePace > 0) {
      final runwayMonths = liquidBalance / monthlyExpensePace;
      if (runwayMonths < 3.0) {
        final target3Mo = monthlyExpensePace * 3;
        final gap = target3Mo - liquidBalance;
        insights.add(AIInsight(
          title: '🛡️ Financial Health: Emergency Runway Alert (${runwayMonths.toStringAsFixed(1)} Mo)',
          description:
              'Your current liquid balance (${Formatters.formatCurrency(liquidBalance, symbol: currencySymbol)}) covers ~${runwayMonths.toStringAsFixed(1)} months of expenses. '
              'A minimum 3-month safety buffer (${Formatters.formatCurrency(target3Mo, symbol: currencySymbol)}) is recommended to protect against unexpected life events. '
              'Gap to fund: ${Formatters.formatCurrency(gap > 0 ? gap : 0, symbol: currencySymbol)}.',
          type: runwayMonths < 1.0 ? 'critical' : 'warning',
          impactAmount: gap > 0 ? gap : 0,
          actionLabel: 'Build Emergency Goal',
          actionRoute: '/savings',
        ));
      }
    }

    // 3. Credit Card Liquidity Risk (Triggered ONLY IF CC Dues > Liquid Bank Balance)
    if (liquidBalance != null && totalCreditLimit != null && totalCreditLimit > 0) {
      final ccSpent = transactions
          .where((t) => t.paymentMethod == 'Credit Card')
          .fold(0.0, (s, t) => s + (t.type == TransactionType.expense ? t.amount : -t.amount))
          .clamp(0.0, double.infinity);
      if (ccSpent > 0 && liquidBalance < ccSpent) {
        final shortfall = ccSpent - liquidBalance;
        insights.add(AIInsight(
          title: '⚠️ Credit Health: Outstanding Card Dues Exceed Liquid Funds',
          description:
              'Total unpaid credit card dues (${Formatters.formatCurrency(ccSpent, symbol: currencySymbol)}) exceed your available liquid bank & cash balance (${Formatters.formatCurrency(liquidBalance, symbol: currencySymbol)}) '
              'by ${Formatters.formatCurrency(shortfall, symbol: currencySymbol)}. Ensure card repayment funds are allocated before the due date.',
          type: 'critical',
          impactAmount: shortfall,
          actionLabel: 'Manage Cards',
          actionRoute: '/home',
        ));
      }
    }

    // 4. Micro-Transaction Silent Leakage (Triggered ONLY IF small expenses < ₹200 make up > 15% of spend)
    final microTransactions = currentMonthExpenses.where((t) => t.amount <= 200 && t.amount > 0).toList();
    if (microTransactions.length >= 4 && totalCurrentExpense > 0) {
      final microTotal = microTransactions.fold(0.0, (s, t) => s + t.amount);
      final microPct = (microTotal / totalCurrentExpense) * 100;
      if (microPct >= 15.0) {
        insights.add(AIInsight(
          title: '☕ Financial Health: Micro-Spending Leakage (${microPct.toStringAsFixed(0)}% of Outflow)',
          description:
              'You made ${microTransactions.length} small transactions (under 200) totaling ${Formatters.formatCurrency(microTotal, symbol: currencySymbol)}. '
              'Frequent micro-spends silently erode your savings. Setting a daily pocket cash limit can save ~${Formatters.formatCurrency(microTotal * 0.4, symbol: currencySymbol)}/mo.',
          type: 'warning',
          impactAmount: microTotal,
          actionLabel: 'View Transactions',
          actionRoute: '/transactions',
        ));
      }
    }

    // 5. Discretionary Wants Overload (Triggered ONLY IF Wants spend > 35% of income)
    if (totalCurrentIncome > 0 && wantsSpend > 0) {
      final wantsPct = (wantsSpend / totalCurrentIncome) * 100;
      if (wantsPct > 35.0) {
        final excessWants = wantsSpend - (totalCurrentIncome * 0.30);
        insights.add(AIInsight(
          title: '🛍️ Financial Health: Discretionary Spending Alert (${wantsPct.toStringAsFixed(0)}% of Income)',
          description:
              'Spending on Wants (dining, shopping, entertainment) reached ${Formatters.formatCurrency(wantsSpend, symbol: currencySymbol)} '
              '(${wantsPct.toStringAsFixed(0)}% of income vs 30% safe benchmark). Trimming ${Formatters.formatCurrency(excessWants, symbol: currencySymbol)} '
              'will restore optimal financial health.',
          type: 'warning',
          impactAmount: excessWants,
          actionLabel: 'Check Spending',
          actionRoute: '/analytics',
        ));
      }
    }

    return insights;
  }
}
