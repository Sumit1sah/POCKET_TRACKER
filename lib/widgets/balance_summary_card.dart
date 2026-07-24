import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../utils/formatters.dart';
import '../utils/app_theme.dart';

class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    final overallStatus = budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final limit = overallStatus.budget.monthlyLimit;
    final spent = overallStatus.spent;
    final remaining = overallStatus.remaining;
    final percentage = overallStatus.percentage;

    Color badgeColor = const Color(0xFF00B894);
    String badgeText = 'On Track';
    if (overallStatus.isExceeded) {
      badgeColor = const Color(0xFFFF7675);
      badgeText = 'EXCEEDED';
    } else if (percentage >= 0.9) {
      badgeColor = const Color(0xFFFF7675);
      badgeText = '90% Used';
    } else if (percentage >= 0.8) {
      badgeColor = const Color(0xFFFDCB6E);
      badgeText = '80% Used';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Net Balance Title & Secured Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Net Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Secured',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Large Net Balance Display
          Text(
            Formatters.formatCurrency(txProvider.netBalance, symbol: currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Income & Expense Tiles Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  title: 'Income',
                  amount: txProvider.totalIncome,
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF00B894),
                  currencySymbol: currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryTile(
                  title: 'Expense',
                  amount: txProvider.totalExpense,
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFFF7675),
                  currencySymbol: currency,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 16),

          // --- Embedded Monthly Budget Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Monthly Budget',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                  ),
                  Text(
                    limit > 0
                        ? Formatters.formatCurrency(remaining, symbol: currency)
                        : 'No Budget Set',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Spent / Limit',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                  ),
                  Text(
                    limit > 0
                        ? '${Formatters.formatCurrency(spent, symbol: currency)} / ${Formatters.formatCurrency(limit, symbol: currency)}'
                        : 'Set in Budget Tab',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Budget Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: limit > 0 ? percentage.clamp(0.0, 1.0) : 0.0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String currencySymbol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                ),
                Text(
                  Formatters.formatCurrency(amount, symbol: currencySymbol),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
