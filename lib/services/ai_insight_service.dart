import '../models/transaction_model.dart';
import '../utils/formatters.dart';

class AIInsight {
  final String title;
  final String description;
  final String type; // 'warning', 'tip', 'positive', 'critical'
  final String? category;
  final double? impactAmount;

  AIInsight({
    required this.title,
    required this.description,
    required this.type,
    this.category,
    this.impactAmount,
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
  }) {
    final List<AIInsight> insights = [];

    if (transactions.isEmpty) {
      insights.add(AIInsight(
        title: '👋 Welcome to Pocketify!',
        description:
            'Start logging your daily income and expenses to unlock intelligent financial insights and budget tracking.',
        type: 'tip',
      ));
      return insights;
    }

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final daysRemaining = daysInMonth - daysPassed;

    // Current & previous month expenses
    final currentMonthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();

    final prevMonthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            (now.month == 1
                ? (t.date.year == now.year - 1 && t.date.month == 12)
                : (t.date.year == now.year &&
                    t.date.month == now.month - 1)))
        .toList();

    final totalCurrent =
        currentMonthExpenses.fold(0.0, (s, t) => s + t.amount);
    final totalPrev = prevMonthExpenses.fold(0.0, (s, t) => s + t.amount);

    // Category totals this month
    final Map<String, double> catTotals = {};
    for (final t in currentMonthExpenses) {
      catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
    }

    // ══════════════════════════════════════════════
    // BUDGET-INTEGRATED INSIGHTS
    // ══════════════════════════════════════════════
    if (budget != null && budget.overallLimit > 0) {
      final usedPct = budget.usagePercent;
      final expectedPacePct = daysPassed / daysInMonth;

      // 1. Overall budget status
      if (usedPct > 1.0) {
        final overspend = budget.totalSpent - budget.overallLimit;
        insights.add(AIInsight(
          title: '🚨 Monthly Budget Exceeded!',
          description:
              'You\'ve spent ${Formatters.formatCurrency(budget.totalSpent, symbol: currencySymbol)} '
              'against a limit of ${Formatters.formatCurrency(budget.overallLimit, symbol: currencySymbol)}. '
              'Overspent by ${Formatters.formatCurrency(overspend, symbol: currencySymbol)}. '
              'Pause all non-essential spending immediately.',
          type: 'critical',
          impactAmount: overspend,
        ));
      } else if (usedPct > 0.9) {
        insights.add(AIInsight(
          title: '⚠️ Budget Almost Exhausted',
          description:
              'You\'ve consumed ${(usedPct * 100).toStringAsFixed(0)}% of your budget with $daysRemaining days to go. '
              'Only ${Formatters.formatCurrency(budget.remaining, symbol: currencySymbol)} left — '
              'avoid discretionary spending.',
          type: 'warning',
          impactAmount: budget.remaining,
        ));
      } else if (usedPct > expectedPacePct + 0.1) {
        // Burning faster than expected
        final projectedTotal = daysPassed > 0
            ? (budget.totalSpent / daysPassed * daysInMonth)
            : budget.totalSpent;
        final projectedOverrun = projectedTotal - budget.overallLimit;
        if (projectedOverrun > 0) {
          insights.add(AIInsight(
            title: '📈 Spending Pace Too Fast',
            description:
                'At your current rate, you\'ll spend ${Formatters.formatCurrency(projectedTotal, symbol: currencySymbol)} '
                'this month — ${Formatters.formatCurrency(projectedOverrun, symbol: currencySymbol)} over your limit. '
                'Slow down now to avoid a budget breach.',
            type: 'warning',
            impactAmount: projectedOverrun,
          ));
        }
      } else if (usedPct < expectedPacePct - 0.15 && daysPassed > 5) {
        insights.add(AIInsight(
          title: '✅ Excellent Budget Control',
          description:
              'Only ${(usedPct * 100).toStringAsFixed(0)}% of budget used by day $daysPassed. '
              '${Formatters.formatCurrency(budget.remaining, symbol: currencySymbol)} remaining. '
              'You\'re well ahead of pace — consider routing surplus to savings!',
          type: 'positive',
          impactAmount: budget.remaining,
        ));
      }

      // 2. Per-category budget alerts
      int exceededCount = 0;
      String? worstCategory;
      double worstOverspend = 0;

      for (final entry in budget.categoryLimits.entries) {
        final catName = entry.key;
        if (catName.toLowerCase() == 'overall') continue;
        final limit = entry.value;
        final spent = budget.categorySpend[catName] ?? 0.0;
        if (limit <= 0 || spent <= 0) continue;
        final pct = spent / limit;

        if (pct > 1.0) {
          exceededCount++;
          final overspend = spent - limit;
          if (overspend > worstOverspend) {
            worstOverspend = overspend;
            worstCategory = catName;
          }
          insights.add(AIInsight(
            title: '🔴 $catName Budget Exceeded',
            description:
                'Spent ${Formatters.formatCurrency(spent, symbol: currencySymbol)} of '
                '${Formatters.formatCurrency(limit, symbol: currencySymbol)} limit '
                '(${(pct * 100).toStringAsFixed(0)}%). Overspent by '
                '${Formatters.formatCurrency(overspend, symbol: currencySymbol)} — reduce $catName expenses.',
            type: 'critical',
            category: catName,
            impactAmount: overspend,
          ));
        } else if (pct >= 0.85) {
          insights.add(AIInsight(
            title: '🟡 $catName Nearing Limit',
            description:
                'Used ${(pct * 100).toStringAsFixed(0)}% of $catName budget '
                '(${Formatters.formatCurrency(spent, symbol: currencySymbol)} / '
                '${Formatters.formatCurrency(limit, symbol: currencySymbol)}). '
                'Only ${Formatters.formatCurrency(limit - spent, symbol: currencySymbol)} left.',
            type: 'warning',
            category: catName,
            impactAmount: limit - spent,
          ));
        } else if (pct < 0.3 && daysPassed > 15) {
          insights.add(AIInsight(
            title: '💚 $catName Under Budget',
            description:
                'Only ${(pct * 100).toStringAsFixed(0)}% of $catName budget used by mid-month. '
                '${Formatters.formatCurrency(limit - spent, symbol: currencySymbol)} still available. '
                'Great restraint!',
            type: 'positive',
            category: catName,
            impactAmount: limit - spent,
          ));
        }
      }

      // 3. Multi-category reallocation tip
      if (exceededCount >= 2 && worstCategory != null) {
        insights.add(AIInsight(
          title: '💡 Reallocation Recommended',
          description:
              '$exceededCount categories exceeded their budgets. '
              '$worstCategory is the biggest offender (${Formatters.formatCurrency(worstOverspend, symbol: currencySymbol)} over). '
              'Use the Budget screen\'s Smart Auto-Allocate to rebalance.',
          type: 'tip',
          category: worstCategory,
          impactAmount: worstOverspend,
        ));
      }

      // 4. Daily safe-to-spend
      if (daysRemaining > 0 && budget.remaining > 0) {
        final dailySafe = budget.remaining / daysRemaining;
        insights.add(AIInsight(
          title: '📅 Daily Safe-to-Spend',
          description:
              'You can spend up to ${Formatters.formatCurrency(dailySafe, symbol: currencySymbol)} per day '
              'for the remaining $daysRemaining days to stay within your '
              '${Formatters.formatCurrency(budget.overallLimit, symbol: currencySymbol)} monthly budget.',
          type: 'tip',
          impactAmount: dailySafe,
        ));
      }

      // 5. Month-end savings projection
      if (budget.remaining > 0 && usedPct < 1.0 && daysRemaining > 0) {
        final projectedDailySpend = daysPassed > 0 ? totalCurrent / daysPassed : 0.0;
        final projectedMonthTotal = projectedDailySpend * daysInMonth;
        final projectedSavings = budget.overallLimit - projectedMonthTotal;
        if (projectedSavings > 0) {
          insights.add(AIInsight(
            title: '💰 Projected Budget Savings',
            description:
                'At your current pace, you\'ll save ${Formatters.formatCurrency(projectedSavings, symbol: currencySymbol)} '
                'from your monthly budget. Consider moving this to your savings goals!',
            type: 'positive',
            impactAmount: projectedSavings,
          ));
        }
      }
    } else {
      // No budget configured nudge
      insights.add(AIInsight(
        title: '💡 Set Up Your Monthly Budget',
        description:
            'You haven\'t configured a monthly budget yet. Head to the Budget tab and use Smart Auto-Allocate '
            'to unlock personalized AI budget insights.',
        type: 'tip',
      ));
    }

    // ══════════════════════════════════════════════
    // TRANSACTION-PATTERN INSIGHTS
    // ══════════════════════════════════════════════

    // 6. Month-over-Month spending comparison
    if (totalPrev > 0) {
      final diffPct = ((totalCurrent - totalPrev) / totalPrev * 100).round();
      if (diffPct > 15) {
        insights.add(AIInsight(
          title: '📊 Spending Up $diffPct% vs Last Month',
          description:
              'You\'ve spent ${Formatters.formatCurrency(totalCurrent, symbol: currencySymbol)} this month vs '
              '${Formatters.formatCurrency(totalPrev, symbol: currencySymbol)} last month. '
              'Review recent food, shopping, and entertainment entries.',
          type: 'warning',
          impactAmount: totalCurrent - totalPrev,
        ));
      } else if (diffPct < -10) {
        insights.add(AIInsight(
          title: '🎉 Spending Down ${diffPct.abs()}% vs Last Month',
          description:
              'You\'re spending ${diffPct.abs()}% less than last month, '
              'saving ${Formatters.formatCurrency(totalPrev - totalCurrent, symbol: currencySymbol)} more. Keep it up!',
          type: 'positive',
          impactAmount: totalPrev - totalCurrent,
        ));
      }
    }

    // 7. Top category concentration
    if (catTotals.isNotEmpty && totalCurrent > 0) {
      final topEntry =
          catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final topPct = ((topEntry.value / totalCurrent) * 100).round();
      if (topPct >= 35) {
        insights.add(AIInsight(
          title: '🏷️ High ${topEntry.key} Concentration',
          description:
              '${topEntry.key} is $topPct% of all expenses '
              '(${Formatters.formatCurrency(topEntry.value, symbol: currencySymbol)}). '
              'Reducing by 20% would free up ${Formatters.formatCurrency(topEntry.value * 0.2, symbol: currencySymbol)}.',
          type: 'warning',
          category: topEntry.key,
          impactAmount: topEntry.value * 0.2,
        ));
      }
    }

    // 8. Weekend spending spike
    final weekendSpend = currentMonthExpenses
        .where((t) =>
            t.date.weekday == DateTime.saturday ||
            t.date.weekday == DateTime.sunday)
        .fold(0.0, (s, t) => s + t.amount);

    if (totalCurrent > 0 && weekendSpend / totalCurrent > 0.5) {
      insights.add(AIInsight(
        title: '📅 Weekend Spending Spike',
        description:
            'Over 50% of expenses (${Formatters.formatCurrency(weekendSpend, symbol: currencySymbol)}) '
            'happen on weekends. A weekend spending cap could improve savings by 30%.',
        type: 'warning',
        impactAmount: weekendSpend * 0.3,
      ));
    }

    // 9. High-frequency spending today
    final todayExpenses = currentMonthExpenses
        .where((t) =>
            t.date.day == now.day &&
            t.date.month == now.month &&
            t.date.year == now.year)
        .toList();
    if (todayExpenses.length >= 4) {
      final todayTotal = todayExpenses.fold(0.0, (s, t) => s + t.amount);
      insights.add(AIInsight(
        title: '⚡ ${todayExpenses.length} Transactions Today',
        description:
            'You\'ve made ${todayExpenses.length} expense entries today '
            '(${Formatters.formatCurrency(todayTotal, symbol: currencySymbol)} total). '
            'Consider grouping small purchases to simplify tracking.',
        type: 'tip',
        impactAmount: todayTotal,
      ));
    }

    // 10. Positive catch-all
    if (insights.isEmpty) {
      insights.add(AIInsight(
        title: '✅ Financial Health Balanced',
        description:
            'No budget overruns or concerning patterns detected. Your spending is well-balanced. '
            'Keep logging daily to unlock more trend insights.',
        type: 'positive',
      ));
    }

    return insights;
  }
}
