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

    final overallStatus = budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final limit = overallStatus.budget.monthlyLimit;
    final spent = overallStatus.spent;
    final remaining = overallStatus.remaining;
    final percentage = overallStatus.percentage;

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: progressColor.withValues(alpha: 0.3)),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, color: progressColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Monthly Budget Allowance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining Budget',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  Text(
                    limit > 0
                        ? Formatters.formatCurrency(remaining, symbol: currency)
                        : 'No Budget Set',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: remaining < 0 ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Spent: ${Formatters.formatCurrency(spent, symbol: currency)}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  Text(
                    limit > 0 ? 'Limit: ${Formatters.formatCurrency(limit, symbol: currency)}' : 'Set limit in Budget tab',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: limit > 0 ? percentage.clamp(0.0, 1.0) : 0.0,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
