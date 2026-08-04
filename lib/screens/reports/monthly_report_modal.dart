import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/transaction_model.dart';
import '../../services/monthly_report_service.dart';
import '../../services/report_service.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────
class MonthlyReportModal extends StatefulWidget {
  final DateTime? initialMonth;
  const MonthlyReportModal({super.key, this.initialMonth});

  static void show(BuildContext context, {DateTime? month}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => MonthlyReportModal(initialMonth: month),
        transitionsBuilder: (c, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  State<MonthlyReportModal> createState() => _MonthlyReportModalState();
}

class _MonthlyReportModalState extends State<MonthlyReportModal>
    with TickerProviderStateMixin {
  late DateTime _selectedMonth;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  int _selectedTab = 0; // 0=Overview, 1=Categories, 2=Days, 3=Payments

  static const List<String> _tabs = ['Overview', 'Categories', 'Daily', 'Payments'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ??
        DateTime(now.year, now.month - 1, 1);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    _fadeCtrl.reset();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final report = MonthlyReportService.generateReport(
      transactions: txProvider.transactions,
      budgets: budgetProvider.budgets,
      targetMonth: _selectedMonth,
    );

    final monthTxs = txProvider.transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList();

    final monthTitle = Formatters.formatMonthYear(_selectedMonth);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F2FF),
      body: Column(
        children: [
          _buildHeader(context, monthTitle, isDark),
          _buildTabBar(isDark),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildTabContent(
                context, report, monthTxs, currency, isDark, categoryProvider,
              ),
            ),
          ),
          _buildExportBar(context, monthTxs, currency, monthTitle, report, isDark),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String monthTitle, bool isDark) {
    final now = DateTime.now();
    final isCurrentOrFuture = _selectedMonth.year > now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month >= now.month);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'Monthly Report',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navBtn(Icons.chevron_left_rounded, () => _changeMonth(-1)),
                  Column(
                    children: [
                      Text(
                        monthTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCurrentOrFuture ? 'Current period' : 'Past report',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  _navBtn(Icons.chevron_right_rounded, () => _changeMonth(1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      );

  // ─── TAB BAR ────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F2FF),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _selectedTab == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6C5CE7)
                      : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selected
                      ? [BoxShadow(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4), blurRadius: 8)]
                      : [],
                ),
                child: Text(
                  _tabs[i],
                  style: TextStyle(
                    color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── TAB CONTENT ROUTER ─────────────────────────────────────────────────
  Widget _buildTabContent(
    BuildContext context,
    MonthlyReportData report,
    List<TransactionModel> monthTxs,
    String currency,
    bool isDark,
    CategoryProvider categoryProvider,
  ) {
    switch (_selectedTab) {
      case 0:
        return _OverviewTab(report: report, monthTxs: monthTxs, currency: currency, isDark: isDark);
      case 1:
        return _CategoriesTab(report: report, monthTxs: monthTxs, currency: currency, isDark: isDark, categoryProvider: categoryProvider);
      case 2:
        return _DailyTab(monthTxs: monthTxs, selectedMonth: _selectedMonth, currency: currency, isDark: isDark);
      case 3:
        return _PaymentsTab(monthTxs: monthTxs, currency: currency, isDark: isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── EXPORT BAR ─────────────────────────────────────────────────────────
  Widget _buildExportBar(
    BuildContext context,
    List<TransactionModel> monthTxs,
    String currency,
    String monthTitle,
    MonthlyReportData report,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ExportBtn(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: const Color(0xFFE17055),
                onTap: () async {
                  await ReportService.printPDFReport(monthTxs, currency, monthTitle: monthTitle);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExportBtn(
                icon: Icons.table_chart_rounded,
                label: 'CSV',
                color: const Color(0xFF00B894),
                onTap: () async {
                  final csv = await ReportService.generateCSVReport(monthTxs, monthTitle: monthTitle);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('CSV saved: $csv')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExportBtn(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: const Color(0xFF6C5CE7),
                onTap: () {
                  final text = '''📊 Pocketify Report – $monthTitle
Income: ${Formatters.formatCurrency(report.totalIncome, symbol: currency)}
Expense: ${Formatters.formatCurrency(report.totalExpense, symbol: currency)}
Savings: ${Formatters.formatCurrency(report.netSavings, symbol: currency)} (${report.savingsRate.toStringAsFixed(1)}%)
Top: ${report.topCategory} • Grade: ${report.healthGrade}''';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Summary copied!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 – OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  const _OverviewTab({required this.report, required this.monthTxs, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final incomes = monthTxs.where((t) => t.type == TransactionType.income).toList();
    final expenses = monthTxs.where((t) => t.type == TransactionType.expense).toList();
    final recurring = monthTxs.where((t) => t.isRecurring).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Health Score Card ──────────────────────────────────────────────
        _HealthScoreCard(report: report),
        const SizedBox(height: 16),

        // ── 4 KPI Tiles ───────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _KpiTile(
              label: 'Total Income',
              value: Formatters.formatCompactCurrency(report.totalIncome, symbol: currency),
              icon: Icons.arrow_downward_rounded,
              color: const Color(0xFF00B894),
              isDark: isDark,
            ),
            _KpiTile(
              label: 'Total Expense',
              value: Formatters.formatCompactCurrency(report.totalExpense, symbol: currency),
              icon: Icons.arrow_upward_rounded,
              color: const Color(0xFFFF7675),
              isDark: isDark,
            ),
            _KpiTile(
              label: 'Net Savings',
              value: Formatters.formatCompactCurrency(report.netSavings, symbol: currency),
              icon: Icons.savings_rounded,
              color: report.netSavings >= 0 ? const Color(0xFF0984E3) : const Color(0xFFFF7675),
              isDark: isDark,
            ),
            _KpiTile(
              label: 'Savings Rate',
              value: '${report.savingsRate.toStringAsFixed(1)}%',
              icon: Icons.percent_rounded,
              color: const Color(0xFF6C5CE7),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Income vs Expense Comparison Bar ─────────────────────────────
        _SectionHeader(title: 'Income vs Expense', icon: Icons.compare_arrows_rounded),
        const SizedBox(height: 10),
        _IncomeExpenseBar(income: report.totalIncome, expense: report.totalExpense, currency: currency),
        const SizedBox(height: 16),

        // ── Budget Compliance ─────────────────────────────────────────────
        if (report.budgetLimit > 0) ...[
          _SectionHeader(title: 'Budget Compliance', icon: Icons.account_balance_wallet_rounded),
          const SizedBox(height: 10),
          _BudgetComplianceCard(report: report, currency: currency, isDark: isDark),
          const SizedBox(height: 16),
        ],

        // ── Quick Stats ───────────────────────────────────────────────────
        _SectionHeader(title: 'Quick Stats', icon: Icons.bar_chart_rounded),
        const SizedBox(height: 10),
        _QuickStatRow(
          stats: [
            _StatItem('Transactions', '${monthTxs.length}', Icons.receipt_long_rounded, const Color(0xFF6C5CE7)),
            _StatItem('Income Entries', '${incomes.length}', Icons.trending_up_rounded, const Color(0xFF00B894)),
            _StatItem('Expense Entries', '${expenses.length}', Icons.trending_down_rounded, const Color(0xFFFF7675)),
            _StatItem('Recurring', '$recurring', Icons.repeat_rounded, const Color(0xFF00CEC9)),
          ],
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ── Key Insights ──────────────────────────────────────────────────
        _SectionHeader(title: 'Key Insights', icon: Icons.lightbulb_rounded),
        const SizedBox(height: 10),
        _InsightRow(icon: Icons.today_rounded, color: const Color(0xFF00CEC9), title: 'Avg Daily Spend',
            value: Formatters.formatCurrency(report.avgDailyExpense, symbol: currency), isDark: isDark),
        const SizedBox(height: 8),
        if (report.highestExpense != null)
          _InsightRow(
            icon: Icons.shopping_bag_outlined,
            color: const Color(0xFFE17055),
            title: 'Largest Expense',
            value: '${report.highestExpense!.description.isNotEmpty ? report.highestExpense!.description : report.highestExpense!.category}: ${Formatters.formatCurrency(report.highestExpense!.amount, symbol: currency)}',
            isDark: isDark,
          ),
        const SizedBox(height: 8),
        if (report.topCategory != 'None')
          _InsightRow(icon: Icons.star_rounded, color: const Color(0xFFFDCB6E), title: 'Top Category',
              value: '${report.topCategory} (${report.topCategoryPercentage.toStringAsFixed(1)}%)', isDark: isDark),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 – CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════
class _CategoriesTab extends StatelessWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  final CategoryProvider categoryProvider;
  const _CategoriesTab({required this.report, required this.monthTxs, required this.currency, required this.isDark, required this.categoryProvider});

  static const List<Color> _palette = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055),
    Color(0xFFFDCB6E), Color(0xFF0984E3), Color(0xFFAD7BE9),
    Color(0xFF00CEC9), Color(0xFFFF7675), Color(0xFF55EFC4),
    Color(0xFFD63031),
  ];

  @override
  Widget build(BuildContext context) {
    if (report.categoryExpenses.isEmpty) {
      return const _EmptyState(message: 'No expense categories logged this month');
    }

    final entries = report.categoryExpenses.entries.toList();
    final allCats = categoryProvider.categories.isNotEmpty
        ? categoryProvider.categories
        : AppConstants.defaultCategories;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Donut Chart ───────────────────────────────────────────────────
        _SectionHeader(title: 'Spending Distribution', icon: Icons.donut_large_rounded),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _DonutChart(
            segments: entries.asMap().entries.map((e) {
              return _DonutSegment(
                value: e.value.value,
                color: _palette[e.key % _palette.length],
                label: e.value.key,
              );
            }).toList(),
            total: report.totalExpense,
            currency: currency,
          ),
        ),
        const SizedBox(height: 16),

        // ── Legend ────────────────────────────────────────────────────────
        _SectionHeader(title: 'Category Breakdown', icon: Icons.list_alt_rounded),
        const SizedBox(height: 10),
        ...entries.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value.key;
          final amount = entry.value.value;
          final pct = report.totalExpense > 0 ? (amount / report.totalExpense) : 0.0;
          final color = _palette[idx % _palette.length];
          final catMatch = allCats.firstWhere(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
            orElse: () => allCats.first,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CategoryBar(
              name: name,
              amount: amount,
              pct: pct,
              color: color,
              icon: catMatch.iconData,
              currency: currency,
              isDark: isDark,
            ),
          );
        }),
        const SizedBox(height: 16),

        // ── Top Earner/Spender ────────────────────────────────────────────
        _SectionHeader(title: 'Income Categories', icon: Icons.trending_up_rounded),
        const SizedBox(height: 10),
        ..._buildIncomeCategoryList(context),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildIncomeCategoryList(BuildContext context) {
    final Map<String, double> incomeMap = {};
    for (final t in monthTxs.where((t) => t.type == TransactionType.income)) {
      incomeMap[t.category] = (incomeMap[t.category] ?? 0) + t.amount;
    }
    if (incomeMap.isEmpty) {
      return [Text('No income logged.', style: TextStyle(color: Colors.grey[500], fontSize: 13))];
    }
    final total = incomeMap.values.fold(0.0, (a, b) => a + b);
    final sorted = incomeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) {
      final pct = total > 0 ? e.value / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _CategoryBar(
          name: e.key,
          amount: e.value,
          pct: pct,
          color: const Color(0xFF00B894),
          icon: Icons.arrow_downward_rounded,
          currency: currency,
          isDark: isDark,
        ),
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 – DAILY
// ═══════════════════════════════════════════════════════════════════════════
class _DailyTab extends StatelessWidget {
  final List<TransactionModel> monthTxs;
  final DateTime selectedMonth;
  final String currency;
  final bool isDark;
  const _DailyTab({required this.monthTxs, required this.selectedMonth, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    // build per-day spend map
    final Map<int, double> dailySpend = {};
    final Map<int, double> dailyIncome = {};
    for (final t in monthTxs) {
      final d = t.date.day;
      if (t.type == TransactionType.expense) {
        dailySpend[d] = (dailySpend[d] ?? 0) + t.amount;
      } else {
        dailyIncome[d] = (dailyIncome[d] ?? 0) + t.amount;
      }
    }
    final maxSpend = dailySpend.values.fold(0.0, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Bar Chart ─────────────────────────────────────────────────────
        _SectionHeader(title: 'Daily Expense Bars', icon: Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        _DailyBarChart(
          daysInMonth: daysInMonth,
          dailySpend: dailySpend,
          maxSpend: maxSpend,
          currency: currency,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // ── Heatmap ───────────────────────────────────────────────────────
        _SectionHeader(title: 'Spend Heatmap', icon: Icons.grid_view_rounded),
        const SizedBox(height: 12),
        _SpendHeatmap(
          daysInMonth: daysInMonth,
          dailySpend: dailySpend,
          maxSpend: maxSpend,
          selectedMonth: selectedMonth,
        ),
        const SizedBox(height: 20),

        // ── Day Detail List ───────────────────────────────────────────────
        _SectionHeader(title: 'Day-by-Day Summary', icon: Icons.list_rounded),
        const SizedBox(height: 10),
        ...List.generate(daysInMonth, (i) {
          final day = i + 1;
          final spend = dailySpend[day] ?? 0;
          final income = dailyIncome[day] ?? 0;
          if (spend == 0 && income == 0) return const SizedBox.shrink();
          final date = DateTime(selectedMonth.year, selectedMonth.month, day);
          return _DayRow(
            date: date,
            spend: spend,
            income: income,
            currency: currency,
            isDark: isDark,
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4 – PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════
class _PaymentsTab extends StatelessWidget {
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  const _PaymentsTab({required this.monthTxs, required this.currency, required this.isDark});

  static const List<Color> _pmColors = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFF0984E3),
    Color(0xFFE17055), Color(0xFFFDCB6E), Color(0xFF00CEC9),
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, double> pmExpense = {};
    final Map<String, double> pmIncome = {};
    for (final t in monthTxs) {
      if (t.type == TransactionType.expense) {
        pmExpense[t.paymentMethod] = (pmExpense[t.paymentMethod] ?? 0) + t.amount;
      } else {
        pmIncome[t.paymentMethod] = (pmIncome[t.paymentMethod] ?? 0) + t.amount;
      }
    }

    final pmExpenseList = pmExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final pmIncomeList = pmIncome.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = pmExpense.values.fold(0.0, (a, b) => a + b);
    final totalIncome = pmIncome.values.fold(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Expense by Payment Method ─────────────────────────────────────
        _SectionHeader(title: 'Expenses by Payment Method', icon: Icons.payment_rounded),
        const SizedBox(height: 10),
        if (pmExpenseList.isEmpty)
          const _EmptyState(message: 'No expense data')
        else
          ...pmExpenseList.asMap().entries.map((e) {
            final color = _pmColors[e.key % _pmColors.length];
            final pct = totalExpense > 0 ? e.value.value / totalExpense : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryBar(
                name: e.value.key,
                amount: e.value.value,
                pct: pct,
                color: color,
                icon: _pmIcon(e.value.key),
                currency: currency,
                isDark: isDark,
              ),
            );
          }),
        const SizedBox(height: 16),

        // ── Income by Payment Method ─────────────────────────────────────
        _SectionHeader(title: 'Income by Payment Method', icon: Icons.account_balance_rounded),
        const SizedBox(height: 10),
        if (pmIncomeList.isEmpty)
          const _EmptyState(message: 'No income data')
        else
          ...pmIncomeList.asMap().entries.map((e) {
            final color = const Color(0xFF00B894);
            final pct = totalIncome > 0 ? e.value.value / totalIncome : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryBar(
                name: e.value.key,
                amount: e.value.value,
                pct: pct,
                color: color,
                icon: _pmIcon(e.value.key),
                currency: currency,
                isDark: isDark,
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  IconData _pmIcon(String pm) {
    switch (pm.toLowerCase()) {
      case 'credit card': return Icons.credit_card_rounded;
      case 'debit card': return Icons.credit_score_rounded;
      case 'upi': return Icons.qr_code_scanner_rounded;
      case 'cash': return Icons.money_rounded;
      case 'bank transfer': return Icons.account_balance_rounded;
      case 'wallet': return Icons.account_balance_wallet_rounded;
      default: return Icons.payment_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _HealthScoreCard extends StatelessWidget {
  final MonthlyReportData report;
  const _HealthScoreCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final grade = report.healthGrade;
    Color gradeColor;
    if (grade == 'A+' || grade == 'A') {
      gradeColor = const Color(0xFF00B894);
    } else if (grade == 'B') {
      gradeColor = const Color(0xFF0984E3);
    } else if (grade == 'C') {
      gradeColor = const Color(0xFFE17055);
    } else {
      gradeColor = const Color(0xFFFF7675);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradeColor.withValues(alpha: 0.12), gradeColor.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradeColor, gradeColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: gradeColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Text(
                grade == 'N/A' ? '?' : grade,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Health: Grade $grade',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: gradeColor),
                ),
                const SizedBox(height: 4),
                Text(
                  report.healthSummary,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6C5CE7)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

class _IncomeExpenseBar extends StatelessWidget {
  final double income, expense;
  final String currency;
  const _IncomeExpenseBar({required this.income, required this.expense, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = income + expense;
    final incomeFrac = total > 0 ? income / total : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: (incomeFrac * 100).round(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(Formatters.formatCompactCurrency(income, symbol: currency),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00B894))),
                  ],
                ),
              ),
              Expanded(
                flex: max(1, ((1 - incomeFrac) * 100).round()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Expense', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(Formatters.formatCompactCurrency(expense, symbol: currency),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFFF7675))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: (incomeFrac * 100).round(),
                  child: Container(height: 10, color: const Color(0xFF00B894)),
                ),
                Expanded(
                  flex: max(1, ((1 - incomeFrac) * 100).round()),
                  child: Container(height: 10, color: const Color(0xFFFF7675)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetComplianceCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _BudgetComplianceCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isExceeded = report.totalExpense > report.budgetLimit;
    final pct = (report.budgetUtilization / 100.0).clamp(0.0, 1.0);
    final barColor = isExceeded ? const Color(0xFFFF7675) : const Color(0xFF00B894);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget: ${Formatters.formatCompactCurrency(report.budgetLimit, symbol: currency)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: barColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isExceeded ? 'EXCEEDED' : 'ON TRACK',
                  style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spent: ${Formatters.formatCompactCurrency(report.totalExpense, symbol: currency)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text('${report.budgetUtilization.toStringAsFixed(1)}% used',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  final List<_StatItem> stats;
  final bool isDark;
  const _QuickStatRow({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Column(
              children: [
                Icon(s.icon, color: s.color, size: 18),
                const SizedBox(height: 4),
                Text(s.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: s.color)),
                const SizedBox(height: 2),
                Text(s.label, style: TextStyle(fontSize: 9, color: Colors.grey[500]), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value;
  final bool isDark;
  const _InsightRow({required this.icon, required this.color, required this.title, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Flexible(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String name;
  final double amount, pct;
  final Color color;
  final IconData icon;
  final String currency;
  final bool isDark;
  const _CategoryBar({required this.name, required this.amount, required this.pct, required this.color, required this.icon, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text(
                '${Formatters.formatCompactCurrency(amount, symbol: currency)}  ${(pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Donut Chart ─────────────────────────────────────────────────────────────
class _DonutSegment {
  final double value;
  final Color color;
  final String label;
  const _DonutSegment({required this.value, required this.color, required this.label});
}

class _DonutChart extends StatelessWidget {
  final List<_DonutSegment> segments;
  final double total;
  final String currency;
  const _DonutChart({required this.segments, required this.total, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Chart
        Expanded(
          child: CustomPaint(
            painter: _DonutPainter(segments: segments, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text(
                    Formatters.formatCompactCurrency(total, symbol: currency),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: segments.take(6).map((s) {
              final pct = total > 0 ? (s.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.85;
    const holeRatio = 0.58;
    double startAngle = -pi / 2;

    for (final seg in segments) {
      final sweep = total > 0 ? (seg.value / total) * 2 * pi : 0.0;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * (1 - holeRatio)
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - radius * (1 - holeRatio) / 2),
        startAngle,
        sweep - 0.02,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─── Daily Bar Chart ──────────────────────────────────────────────────────────
class _DailyBarChart extends StatelessWidget {
  final int daysInMonth;
  final Map<int, double> dailySpend;
  final double maxSpend;
  final String currency;
  final bool isDark;
  const _DailyBarChart({required this.daysInMonth, required this.dailySpend, required this.maxSpend, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(daysInMonth, (i) {
          final day = i + 1;
          final spend = dailySpend[day] ?? 0;
          final fraction = maxSpend > 0 ? spend / maxSpend : 0.0;
          final isToday = DateTime.now().day == day;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: 'Day $day: ${Formatters.formatCurrency(spend, symbol: currency)}',
                child: Container(
                  height: max(3.0, fraction * 100),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF6C5CE7)
                        : spend > 0
                            ? const Color(0xFFFF7675).withValues(alpha: 0.7)
                            : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Spend Heatmap ────────────────────────────────────────────────────────────
class _SpendHeatmap extends StatelessWidget {
  final int daysInMonth;
  final Map<int, double> dailySpend;
  final double maxSpend;
  final DateTime selectedMonth;
  const _SpendHeatmap({required this.daysInMonth, required this.dailySpend, required this.maxSpend, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final startWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday % 7; // 0=Sun
    final cells = startWeekday + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekday labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
            return Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 10, color: Colors.grey[500]))));
          }).toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (col) {
                final cellIdx = row * 7 + col;
                final day = cellIdx - startWeekday + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 32));
                }
                final spend = dailySpend[day] ?? 0;
                final intensity = maxSpend > 0 ? spend / maxSpend : 0.0;
                final baseColor = const Color(0xFF6C5CE7);
                return Expanded(
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: spend > 0
                          ? baseColor.withValues(alpha: (0.15 + intensity * 0.8).clamp(0.0, 1.0))
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: intensity > 0.5 ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Day Row ─────────────────────────────────────────────────────────────────
class _DayRow extends StatelessWidget {
  final DateTime date;
  final double spend, income;
  final String currency;
  final bool isDark;
  const _DayRow({required this.date, required this.spend, required this.income, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6C5CE7)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              Formatters.formatDate(date),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (income > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '+${Formatters.formatCompactCurrency(income, symbol: currency)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00B894)),
              ),
            ),
          if (spend > 0)
            Text(
              '-${Formatters.formatCompactCurrency(spend, symbol: currency)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF7675)),
            ),
        ],
      ),
    );
  }
}

// ─── Export Button ────────────────────────────────────────────────────────────
class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ExportBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
