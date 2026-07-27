import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../services/monthly_report_service.dart';
import '../../services/report_service.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

class MonthlyReportModal extends StatefulWidget {
  final DateTime? initialMonth;
  const MonthlyReportModal({super.key, this.initialMonth});

  static void show(BuildContext context, {DateTime? month}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonthlyReportModal(initialMonth: month),
    );
  }

  @override
  State<MonthlyReportModal> createState() => _MonthlyReportModalState();
}

class _MonthlyReportModalState extends State<MonthlyReportModal> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to last month if not specified or if current month is brand new
    _selectedMonth = widget.initialMonth ??
        (now.day == 1
            ? DateTime(now.year, now.month - 1, 1)
            : DateTime(now.year, now.month, 1));
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    final report = MonthlyReportService.generateReport(
      transactions: txProvider.transactions,
      budgets: budgetProvider.budgets,
      targetMonth: _selectedMonth,
    );

    final monthTitle = Formatters.formatMonthYear(_selectedMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter transactions specifically for PDF/CSV export
    final monthTransactions = txProvider.transactions
        .where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month)
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Header with Month Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: _previousMonth,
                  tooltip: 'Previous Month',
                ),
                Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: Color(0xFF6C5CE7), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$monthTitle Report',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: _nextMonth,
                  tooltip: 'Next Month',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Financial Health Score Banner ---
                  _buildHealthBanner(context, report),
                  const SizedBox(height: 20),

                  // --- 4 KPI Metrics Grid ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          title: 'Total Income',
                          value: Formatters.formatCurrency(report.totalIncome, symbol: currency),
                          icon: Icons.arrow_downward_rounded,
                          iconColor: const Color(0xFF00B894),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          title: 'Total Expense',
                          value: Formatters.formatCurrency(report.totalExpense, symbol: currency),
                          icon: Icons.arrow_upward_rounded,
                          iconColor: const Color(0xFFFF7675),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          title: 'Net Savings',
                          value: Formatters.formatCurrency(report.netSavings, symbol: currency),
                          icon: Icons.savings_rounded,
                          iconColor: report.netSavings >= 0 ? const Color(0xFF0984E3) : const Color(0xFFFF7675),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          title: 'Savings Rate',
                          value: '${report.savingsRate.toStringAsFixed(1)}%',
                          icon: Icons.pie_chart_rounded,
                          iconColor: const Color(0xFF6C5CE7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Budget Compliance Card ---
                  if (report.budgetLimit > 0) ...[
                    _buildBudgetComplianceCard(context, report, currency),
                    const SizedBox(height: 24),
                  ],

                  // --- Top Category Highlight ---
                  if (report.topCategory != 'None') ...[
                    const Text(
                      'Highest Spending Category',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildTopCategoryCard(context, report, categoryProvider.categories, currency),
                    const SizedBox(height: 24),
                  ],

                  // --- Category Breakdown Progress List ---
                  if (report.categoryExpenses.isNotEmpty) ...[
                    const Text(
                      'Category Spending Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...report.categoryExpenses.entries.map((e) {
                      final pct = report.totalExpense > 0 ? (e.value / report.totalExpense) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(
                                  '${Formatters.formatCurrency(e.value, symbol: currency)} (${(pct * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // --- Key Monthly Insights ---
                  const Text(
                    'Key Monthly Insights',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildInsightTile(
                    context,
                    icon: Icons.event_repeat_rounded,
                    color: const Color(0xFF00CEC9),
                    title: 'Average Daily Spend',
                    value: Formatters.formatCurrency(report.avgDailyExpense, symbol: currency),
                  ),
                  if (report.highestExpense != null)
                    _buildInsightTile(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      color: const Color(0xFFE17055),
                      title: 'Largest Single Expense',
                      value: '${report.highestExpense!.description.isNotEmpty ? report.highestExpense!.description : report.highestExpense!.category}: ${Formatters.formatCurrency(report.highestExpense!.amount, symbol: currency)}',
                    ),
                  _buildInsightTile(
                    context,
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF6C5CE7),
                    title: 'Total Transactions Logged',
                    value: '${report.transactionCount} transactions',
                  ),
                  const SizedBox(height: 24),

                  // --- Export & Share Options ---
                  const Text(
                    'Export & Share Monthly Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            await ReportService.printPDFReport(monthTransactions, currency, monthTitle: monthTitle);
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('PDF Statement'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final csv = await ReportService.generateCSVReport(monthTransactions, monthTitle: monthTitle);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('CSV exported: $csv')),
                              );
                            }
                          },
                          icon: const Icon(Icons.table_chart_rounded, size: 18),
                          label: const Text('Export CSV'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        final summaryText = '''
📊 Pocketify Monthly Report - $monthTitle
---------------------------------------
💰 Total Income: ${Formatters.formatCurrency(report.totalIncome, symbol: currency)}
💸 Total Expense: ${Formatters.formatCurrency(report.totalExpense, symbol: currency)}
💵 Net Savings: ${Formatters.formatCurrency(report.netSavings, symbol: currency)}
📈 Savings Rate: ${report.savingsRate.toStringAsFixed(1)}%
🏆 Top Category: ${report.topCategory} (${Formatters.formatCurrency(report.topCategoryAmount, symbol: currency)})
⭐ Grade: ${report.healthGrade} (${report.healthSummary})
''';
                        Clipboard.setData(ClipboardData(text: summaryText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Monthly summary copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Text Summary'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBanner(BuildContext context, MonthlyReportData report) {
    Color gradeColor = const Color(0xFF00B894);
    if (report.healthGrade == 'D') gradeColor = const Color(0xFFFF7675);
    if (report.healthGrade == 'C') gradeColor = const Color(0xFFE67E22);
    if (report.healthGrade == 'B') gradeColor = const Color(0xFF0984E3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: gradeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                report.healthGrade,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Score: Grade ${report.healthGrade}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: gradeColor),
                ),
                const SizedBox(height: 4),
                Text(
                  report.healthSummary,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetComplianceCard(BuildContext context, MonthlyReportData report, String currency) {
    final isExceeded = report.totalExpense > report.budgetLimit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Compliance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? const Color(0xFFFF7675).withValues(alpha: 0.15)
                      : const Color(0xFF00B894).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExceeded ? 'EXCEEDED' : 'WITHIN BUDGET',
                  style: TextStyle(
                    color: isExceeded ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${Formatters.formatCurrency(report.totalExpense, symbol: currency)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Limit: ${Formatters.formatCurrency(report.budgetLimit, symbol: currency)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (report.budgetUtilization / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded ? const Color(0xFFFF7675) : const Color(0xFF00B894),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoryCard(BuildContext context, MonthlyReportData report, List categories, String currency) {
    final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
    final catMatch = allCats.firstWhere(
      (c) => c.name.toLowerCase() == report.topCategory.toLowerCase(),
      orElse: () => allCats.first,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: catMatch.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: catMatch.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catMatch.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(catMatch.iconData, color: catMatch.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.topCategory,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${report.topCategoryPercentage.toStringAsFixed(1)}% of total monthly spending',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
          Text(
            Formatters.formatCurrency(report.topCategoryAmount, symbol: currency),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: catMatch.color),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
