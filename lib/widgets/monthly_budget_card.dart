import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../utils/formatters.dart';

class MonthlyBudgetCard extends StatelessWidget {
  const MonthlyBudgetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final overallStatus = budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final limit = overallStatus.budget.monthlyLimit;
    final spent = overallStatus.spent;
    final remaining = overallStatus.remaining;
    final percentage = overallStatus.percentage;

    final now = DateTime.now();
    final daysInMonth = DateTime(budgetProvider.selectedMonth.year, budgetProvider.selectedMonth.month + 1, 0).day;
    final currentDay = budgetProvider.isCurrentMonth ? now.day : daysInMonth;
    final remainingDays = (daysInMonth - currentDay) > 0 ? (daysInMonth - currentDay) : 1;
    final safeRemaining = math.max(0.0, remaining);
    final dailyPace = remainingDays > 0 ? (safeRemaining / remainingDays) : 0.0;

    Color progressColor = const Color(0xFF00B894);
    String badgeText = 'On Track';
    if (overallStatus.isExceeded) {
      progressColor = const Color(0xFFFF7675);
      badgeText = 'EXCEEDED';
    } else if (percentage >= 0.9) {
      progressColor = const Color(0xFFFF7675);
      badgeText = '90% Used';
    } else if (percentage >= 0.8) {
      progressColor = const Color(0xFFFDCB6E);
      badgeText = '80% Used';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: progressColor.withValues(alpha: isDark ? 0.3 : 0.2), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6C5CE7), size: 15),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Monthly Budget Allowance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining Budget',
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  Text(
                    limit > 0
                        ? Formatters.formatCurrency(remaining, symbol: currency)
                        : 'No Budget Set',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: remaining < 0 ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Spent: ${Formatters.formatCurrency(spent, symbol: currency)}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  Text(
                    limit > 0 ? 'Limit: ${Formatters.formatCurrency(limit, symbol: currency)}' : 'Set in Budget tab',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: limit > 0 ? percentage.clamp(0.0, 1.0) : 0.0,
              minHeight: 5,
              backgroundColor: progressColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (limit > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 11, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 4),
                    Text(
                      'Safe pace: ${Formatters.formatCurrency(dailyPace, symbol: currency)}/day',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
                Text(
                  '$remainingDays days left',
                  style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
