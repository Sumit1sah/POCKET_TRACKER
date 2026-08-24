import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/budget_model.dart';
import '../../services/monthly_report_service.dart';
import '../../services/report_service.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

// ─── Entry Point Modal ────────────────────────────────────────────────────────
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
        transitionDuration: const Duration(milliseconds: 350),
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
  int _selectedTab = 0; // 0=Overview, 1=Categories, 2=Timeline & Heatmap, 3=Payments, 4=Budget & Forecast

  static const List<Map<String, dynamic>> _tabs = [
    {'title': 'Overview', 'icon': Icons.dashboard_rounded},
    {'title': 'Categories', 'icon': Icons.pie_chart_rounded},
    {'title': 'Timeline', 'icon': Icons.calendar_month_rounded},
    {'title': 'Payments', 'icon': Icons.account_balance_wallet_rounded},
    {'title': 'Budget & Forecast', 'icon': Icons.insights_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
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

  void _showMonthPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Reporting Period',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, idx) {
                    final target = DateTime(DateTime.now().year, DateTime.now().month - idx, 1);
                    final isSelected = target.year == _selectedMonth.year && target.month == _selectedMonth.month;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _fadeCtrl.reset();
                        setState(() => _selectedMonth = target);
                        _fadeCtrl.forward();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6C5CE7)
                              : (isDark ? const Color(0xFF28293D) : const Color(0xFFF3F4F8)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          Formatters.formatMonthYear(target),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
      categories: categoryProvider.categories,
    );

    final monthTxs = txProvider.transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList();

    final monthTitle = Formatters.formatMonthYear(_selectedMonth);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C18) : const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(context, monthTitle, isDark, report, monthTxs, currency),
          _buildTabBar(isDark),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildTabContent(
                context, report, monthTxs, currency, isDark, categoryProvider, budgetProvider,
              ),
            ),
          ),
          _buildExportBar(context, monthTxs, currency, monthTitle, report, isDark),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    String monthTitle,
    bool isDark,
    MonthlyReportData report,
    List<TransactionModel> monthTxs,
    String currency,
  ) {
    final now = DateTime.now();
    final isCurrent = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5352ED), Color(0xFF371B98), Color(0xFF1E1045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Financial Intelligence Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                    tooltip: 'Select Month',
                    onPressed: () => _showMonthPickerSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    tooltip: 'Quick Share',
                    onPressed: () => _shareQuickSummary(context, report, monthTitle, currency),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navBtn(Icons.chevron_left_rounded, () => _changeMonth(-1)),
                  GestureDetector(
                    onTap: () => _showMonthPickerSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF00D2D3).withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isCurrent ? '⚡ LIVE CURRENT MONTH' : '📁 ARCHIVED MONTH',
                              style: TextStyle(
                                color: isCurrent ? const Color(0xFF55EFC4) : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );

  // ─── TAB BAR ────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0C0C18) : const Color(0xFFF4F6FB),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _selectedTab == i;
            final item = _tabs[i];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF5352ED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected
                      ? null
                      : (isDark ? const Color(0xFF1B1B2A) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [BoxShadow(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 15,
                      color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item['title'] as String,
                      style: TextStyle(
                        color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[800]),
                        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
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
    BudgetProvider budgetProvider,
  ) {
    switch (_selectedTab) {
      case 0:
        return _OverviewTab(report: report, monthTxs: monthTxs, currency: currency, isDark: isDark);
      case 1:
        return _CategoriesTab(report: report, monthTxs: monthTxs, currency: currency, isDark: isDark, categoryProvider: categoryProvider);
      case 2:
        return _TimelineHeatmapTab(report: report, monthTxs: monthTxs, selectedMonth: _selectedMonth, currency: currency, isDark: isDark);
      case 3:
        return _PaymentsTab(report: report, monthTxs: monthTxs, currency: currency, isDark: isDark);
      case 4:
        return _BudgetForecastTab(report: report, budgetProvider: budgetProvider, currency: currency, isDark: isDark);
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ExportBtn(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF Statement',
                color: const Color(0xFFFF5252),
                onTap: () async {
                  await ReportService.printPDFReport(monthTxs, currency, monthTitle: monthTitle);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExportBtn(
                icon: Icons.table_chart_rounded,
                label: 'CSV Data',
                color: const Color(0xFF10AC84),
                onTap: () async {
                  final csv = await ReportService.generateCSVReport(monthTxs, monthTitle: monthTitle);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CSV exported: $csv'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExportBtn(
                icon: Icons.copy_all_rounded,
                label: 'Copy Digest',
                color: const Color(0xFF5352ED),
                onTap: () => _shareQuickSummary(context, report, monthTitle, currency),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareQuickSummary(BuildContext context, MonthlyReportData report, String monthTitle, String currency) {
    final text = '''📊 POCKETIFY FINANCIAL REPORT – $monthTitle
──────────────────────────────────────
💰 Income:   ${Formatters.formatCurrency(report.totalIncome, symbol: currency)}
💳 Expenses: ${Formatters.formatCurrency(report.totalExpense, symbol: currency)}
🌱 Net Save: ${Formatters.formatCurrency(report.netSavings, symbol: currency)} (${report.savingsRate.toStringAsFixed(1)}%)
⭐ Health:   Grade ${report.healthGrade} (${report.healthScore}/100)
🏆 Top Spend: ${report.topCategory} (${report.topCategoryPercentage.toStringAsFixed(1)}%)
──────────────────────────────────────
Generated via Pocketify''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Financial summary copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 – OVERVIEW & EXECUTIVE SUMMARY
// ═══════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  const _OverviewTab({required this.report, required this.monthTxs, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Financial Health Scorecard ────────────────────────────────
        _AdvancedHealthScoreCard(report: report, isDark: isDark),
        const SizedBox(height: 16),

        // ── 2. Primary 6-KPI Metrics Matrix ──────────────────────────────
        _KpiGridSection(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 16),

        // ── 3. Month-over-Month (MoM) Trend Card ─────────────────────────
        _MoMComparisonCard(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 16),

        // ── 4. 50 / 30 / 20 Financial Wellness Rule ──────────────────────
        _Rule503020Card(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 16),

        // ── 5. AI Actionable Financial Insights ──────────────────────────
        _ActionableInsightsCard(report: report, isDark: isDark),
        const SizedBox(height: 16),

        // ── 6. Outlier & Top Expense Transactions ────────────────────────
        if (report.topExpenses.isNotEmpty) ...[
          _SectionHeader(title: 'Top Expense Outliers', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          ...report.topExpenses.map((tx) {
            final pct = report.totalExpense > 0 ? (tx.amount / report.totalExpense) * 100 : 0.0;
            return _TopExpenseTile(tx: tx, currency: currency, pct: pct, isDark: isDark);
          }),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 20),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 – CATEGORIES DEEP DIVE
// ═══════════════════════════════════════════════════════════════════════════
class _CategoriesTab extends StatefulWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  final CategoryProvider categoryProvider;
  const _CategoriesTab({required this.report, required this.monthTxs, required this.currency, required this.isDark, required this.categoryProvider});

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  int _selectedCategoryIndex = -1;
  String _activeFilter = 'All'; // 'All', 'Needs', 'Wants', 'Investments'

  static const List<Color> _palette = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFFF7675),
    Color(0xFF0984E3), Color(0xFFFDCB6E), Color(0xFFE17055),
    Color(0xFF00CEC9), Color(0xFFA29BFE), Color(0xFF55EFC4),
    Color(0xFFD63031), Color(0xFFFD79A8), Color(0xFF636E72),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.report.categoryExpenses.isEmpty && widget.report.totalIncome == 0) {
      return const _EmptyState(message: 'No expense or income records logged for this month.');
    }

    final entries = widget.report.categoryExpenses.entries.toList();
    final allCats = widget.categoryProvider.categories.isNotEmpty
        ? widget.categoryProvider.categories
        : AppConstants.defaultCategories;

    // Filter entries if needed
    final filteredEntries = entries.where((e) {
      if (_activeFilter == 'All') return true;
      final nameLower = e.key.toLowerCase();
      const needs = {'rent', 'grocery', 'bills', 'medical', 'fuel', 'education', 'utilities', 'health', 'maintenance', 'housing', 'emi'};
      const wants = {'shopping', 'food', 'dining', 'entertainment', 'travel', 'movie', 'cafe', 'hobbies', 'lifestyle', 'gadgets'};
      const invest = {'investment', 'savings', 'mutual fund', 'stocks', 'gold', 'crypto', 'fd', 'rd'};

      if (_activeFilter == 'Needs') return needs.any((k) => nameLower.contains(k));
      if (_activeFilter == 'Wants') return wants.any((k) => nameLower.contains(k));
      if (_activeFilter == 'Investments') return invest.any((k) => nameLower.contains(k));
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Donut Chart ───────────────────────────────────────────────────
        _SectionHeader(title: 'Spending Breakdown & Share', icon: Icons.donut_large_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF161626) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: _InteractiveDonutChart(
                  segments: entries.asMap().entries.map((e) {
                    return _DonutSegment(
                      value: e.value.value,
                      color: _palette[e.key % _palette.length],
                      label: e.value.key,
                    );
                  }).toList(),
                  total: widget.report.totalExpense,
                  currency: widget.currency,
                  selectedIndex: _selectedCategoryIndex,
                  onSelectIndex: (idx) {
                    setState(() => _selectedCategoryIndex = idx);
                  },
                ),
              ),
              if (_selectedCategoryIndex >= 0 && _selectedCategoryIndex < entries.length) ...[
                const Divider(height: 24),
                _SelectedCategoryBadge(
                  name: entries[_selectedCategoryIndex].key,
                  amount: entries[_selectedCategoryIndex].value,
                  total: widget.report.totalExpense,
                  color: _palette[_selectedCategoryIndex % _palette.length],
                  currency: widget.currency,
                  txCount: widget.report.categoryTxCounts[entries[_selectedCategoryIndex].key] ?? 1,
                  avgAmt: widget.report.categoryAvgExpense[entries[_selectedCategoryIndex].key] ?? 0.0,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Category Filter Pills ─────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Needs', 'Wants', 'Investments'].map((f) {
              final active = _activeFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _activeFilter = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6C5CE7)
                        : (widget.isDark ? const Color(0xFF1E1E2E) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? Colors.transparent : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color: active ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // ── Category Ranked List ──────────────────────────────────────────
        _SectionHeader(title: 'Ranked Spending Categories (${filteredEntries.length})', icon: Icons.format_list_numbered_rounded),
        const SizedBox(height: 10),
        ...filteredEntries.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value.key;
          final amount = entry.value.value;
          final pct = widget.report.totalExpense > 0 ? (amount / widget.report.totalExpense) : 0.0;
          final color = _palette[idx % _palette.length];
          final catMatch = allCats.firstWhere(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
            orElse: () => allCats.first,
          );
          final txCount = widget.report.categoryTxCounts[name] ?? 1;
          final avgAmount = widget.report.categoryAvgExpense[name] ?? amount;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DetailedCategoryCard(
              rank: idx + 1,
              name: name,
              amount: amount,
              pct: pct,
              color: color,
              icon: catMatch.iconData,
              currency: widget.currency,
              txCount: txCount,
              avgAmount: avgAmount,
              isDark: widget.isDark,
            ),
          );
        }),
        const SizedBox(height: 20),

        // ── Income Distribution ───────────────────────────────────────────
        _SectionHeader(title: 'Income Sources', icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 10),
        ..._buildIncomeCategoryList(context),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildIncomeCategoryList(BuildContext context) {
    final Map<String, double> incomeMap = {};
    for (final t in widget.monthTxs.where((t) => t.type == TransactionType.income)) {
      incomeMap[t.category] = (incomeMap[t.category] ?? 0) + t.amount;
    }
    if (incomeMap.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF161626) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Text('No income logged this month.', style: TextStyle(color: Colors.grey, fontSize: 13))),
        )
      ];
    }
    final total = incomeMap.values.fold(0.0, (a, b) => a + b);
    final sorted = incomeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) {
      final pct = total > 0 ? e.value / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _DetailedCategoryCard(
          rank: 0,
          name: e.key,
          amount: e.value,
          pct: pct,
          color: const Color(0xFF00B894),
          icon: Icons.arrow_downward_rounded,
          currency: widget.currency,
          txCount: widget.monthTxs.where((t) => t.category == e.key && t.type == TransactionType.income).length,
          avgAmount: e.value,
          isDark: widget.isDark,
        ),
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 – TIMELINE & SPEND HEATMAP
// ═══════════════════════════════════════════════════════════════════════════
class _TimelineHeatmapTab extends StatefulWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final DateTime selectedMonth;
  final String currency;
  final bool isDark;
  const _TimelineHeatmapTab({required this.report, required this.monthTxs, required this.selectedMonth, required this.currency, required this.isDark});

  @override
  State<_TimelineHeatmapTab> createState() => _TimelineHeatmapTabState();
}

class _TimelineHeatmapTabState extends State<_TimelineHeatmapTab> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final maxDaily = widget.report.highestSpendDayAmount;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Daily Bar Chart with Selection ────────────────────────────
        _SectionHeader(title: 'Daily Spend Velocity', icon: Icons.bar_chart_rounded),
        const SizedBox(height: 10),
        _InteractiveDailyBarChart(
          daysInMonth: daysInMonth,
          dailySpend: widget.report.dailyExpenses,
          maxSpend: maxDaily,
          currency: widget.currency,
          isDark: widget.isDark,
          selectedDay: _selectedDay,
          onSelectDay: (day) => setState(() => _selectedDay = _selectedDay == day ? null : day),
        ),
        const SizedBox(height: 16),

        // ── 2. Spend Heatmap Grid ────────────────────────────────────────
        _SectionHeader(title: 'Calendar Spending Heatmap', icon: Icons.grid_view_rounded),
        const SizedBox(height: 10),
        _SpendHeatmapCard(
          daysInMonth: daysInMonth,
          dailySpend: widget.report.dailyExpenses,
          maxSpend: maxDaily,
          selectedMonth: widget.selectedMonth,
          selectedDay: _selectedDay,
          onSelectDay: (day) => setState(() => _selectedDay = _selectedDay == day ? null : day),
          isDark: widget.isDark,
          currency: widget.currency,
        ),
        const SizedBox(height: 16),

        // ── 3. Weekend vs Weekday Card ───────────────────────────────────
        _WeekendWeekdayCard(report: widget.report, currency: widget.currency, isDark: widget.isDark),
        const SizedBox(height: 16),

        // ── 4. Day-by-Day Timeline List ──────────────────────────────────
        _SectionHeader(
          title: _selectedDay != null ? 'Day $_selectedDay Activity' : 'Chronological Timeline',
          icon: Icons.timeline_rounded,
        ),
        const SizedBox(height: 10),
        ..._buildDailyTimeline(daysInMonth),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildDailyTimeline(int daysInMonth) {
    final List<Widget> list = [];
    final targetDays = _selectedDay != null ? [_selectedDay!] : List.generate(daysInMonth, (i) => i + 1);

    for (final day in targetDays) {
      final spend = widget.report.dailyExpenses[day] ?? 0;
      final income = widget.report.dailyIncomes[day] ?? 0;
      if (spend == 0 && income == 0 && _selectedDay == null) continue;

      final date = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, day);
      final dayTxs = widget.monthTxs.where((t) => t.date.day == day).toList();

      list.add(
        _TimelineDayCard(
          date: date,
          spend: spend,
          income: income,
          txs: dayTxs,
          currency: widget.currency,
          isDark: widget.isDark,
        ),
      );
    }

    if (list.isEmpty) {
      list.add(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No transactions recorded on this day.', style: TextStyle(color: Colors.grey))),
        ),
      );
    }
    return list;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4 – PAYMENT CHANNELS
// ═══════════════════════════════════════════════════════════════════════════
class _PaymentsTab extends StatelessWidget {
  final MonthlyReportData report;
  final List<TransactionModel> monthTxs;
  final String currency;
  final bool isDark;
  const _PaymentsTab({required this.report, required this.monthTxs, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Digital vs Cash Gauge ─────────────────────────────────────
        _DigitalVsCashCard(report: report, isDark: isDark),
        const SizedBox(height: 16),

        // ── 2. Payment Method Outflows ───────────────────────────────────
        _SectionHeader(title: 'Expenses by Payment Channel', icon: Icons.payment_rounded),
        const SizedBox(height: 10),
        if (report.paymentMethodExpenses.isEmpty)
          const _EmptyState(message: 'No payment method data recorded.')
        else
          ...report.paymentMethodExpenses.entries.map((e) {
            final pct = report.totalExpense > 0 ? (e.value / report.totalExpense) * 100 : 0.0;
            final count = report.paymentMethodCounts[e.key] ?? 1;
            final avg = count > 0 ? (e.value / count) : e.value;
            return _PaymentMethodCard(
              name: e.key,
              amount: e.value,
              pct: pct,
              txCount: count,
              avgAmount: avg,
              currency: currency,
              isDark: isDark,
            );
          }),
        const SizedBox(height: 16),

        // ── 3. Recurring / Fixed Costs ───────────────────────────────────
        _SectionHeader(title: 'Fixed Subscriptions & Recurring', icon: Icons.repeat_rounded),
        const SizedBox(height: 10),
        _RecurringCostCard(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 5 – BUDGET & FORECAST
// ═══════════════════════════════════════════════════════════════════════════
class _BudgetForecastTab extends StatelessWidget {
  final MonthlyReportData report;
  final BudgetProvider budgetProvider;
  final String currency;
  final bool isDark;
  const _BudgetForecastTab({required this.report, required this.budgetProvider, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Overall Budget Card ───────────────────────────────────────
        _OverallBudgetHealthCard(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 16),

        // ── 2. Run Rate & End of Month Projection ────────────────────────
        _MonthEndForecastCard(report: report, currency: currency, isDark: isDark),
        const SizedBox(height: 16),

        // ── 3. Category Budgets Adherence ────────────────────────────────
        _SectionHeader(title: 'Category Budget Allocations', icon: Icons.account_balance_wallet_rounded),
        const SizedBox(height: 10),
        if (budgetProvider.budgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161626) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No category budgets configured.\nSet them in the Budget tab for granular tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...budgetProvider.budgets.where((b) => b.category.toLowerCase() != 'overall').map((b) {
            final spent = report.categoryExpenses[b.category] ?? 0.0;
            final util = b.monthlyLimit > 0 ? (spent / b.monthlyLimit) * 100 : 0.0;
            return _CategoryBudgetCard(
              budget: b,
              spent: spent,
              utilization: util,
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
// DETAILED COMPONENT WIDGETS & CHARTS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF6C5CE7)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
        ),
      ],
    );
  }
}

// ─── Financial Health Scorecard ──────────────────────────────────────────────
class _AdvancedHealthScoreCard extends StatelessWidget {
  final MonthlyReportData report;
  final bool isDark;
  const _AdvancedHealthScoreCard({required this.report, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final grade = report.healthGrade;
    final score = report.healthScore;

    Color gradeColor;
    if (grade == 'A+' || grade == 'A') {
      gradeColor = const Color(0xFF00B894);
    } else if (grade == 'B+' || grade == 'B') {
      gradeColor = const Color(0xFF0984E3);
    } else if (grade == 'C') {
      gradeColor = const Color(0xFFE17055);
    } else {
      gradeColor = const Color(0xFFFF7675);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gradeColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Radial Gauge / Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        grade == 'N/A' ? '?' : grade,
                        style: TextStyle(
                          color: gradeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        '$score/100',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Financial Health Score',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gradeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'GRADE $grade',
                            style: TextStyle(
                              color: gradeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.healthSummary,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Sub-scores
          Row(
            children: report.healthScoreBreakdown.entries.map((e) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.key.split('(').first.trim(),
                      style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── 6-KPI Metrics Matrix ────────────────────────────────────────────────────
class _KpiGridSection extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _KpiGridSection({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _KpiTile(
          label: 'Total Inflow',
          value: Formatters.formatCompactCurrency(report.totalIncome, symbol: currency),
          subtext: '${report.incomeCount} credits',
          icon: Icons.arrow_downward_rounded,
          color: const Color(0xFF00B894),
          isDark: isDark,
        ),
        _KpiTile(
          label: 'Total Outflow',
          value: Formatters.formatCompactCurrency(report.totalExpense, symbol: currency),
          subtext: '${report.expenseCount} debits',
          icon: Icons.arrow_upward_rounded,
          color: const Color(0xFFFF7675),
          isDark: isDark,
        ),
        _KpiTile(
          label: 'Net Savings',
          value: Formatters.formatCompactCurrency(report.netSavings, symbol: currency),
          subtext: '${report.savingsRate.toStringAsFixed(1)}% savings rate',
          icon: Icons.savings_rounded,
          color: report.netSavings >= 0 ? const Color(0xFF0984E3) : const Color(0xFFFF7675),
          isDark: isDark,
        ),
        _KpiTile(
          label: 'Avg Daily Spend',
          value: Formatters.formatCompactCurrency(report.avgDailyExpense, symbol: currency),
          subtext: '${report.activeSpendingDaysCount} active days',
          icon: Icons.speed_rounded,
          color: const Color(0xFF6C5CE7),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value, subtext;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _KpiTile({required this.label, required this.value, required this.subtext, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500], fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Month-over-Month (MoM) Card ─────────────────────────────────────────────
class _MoMComparisonCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _MoMComparisonCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Month-over-Month (MoM) Comparison',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'vs Prev Month',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MoMItem(
                  title: 'Expense Delta',
                  pct: report.expenseMoMChangePct,
                  isInverse: true, // Lower expense is good
                ),
              ),
              Expanded(
                child: _MoMItem(
                  title: 'Income Delta',
                  pct: report.incomeMoMChangePct,
                  isInverse: false,
                ),
              ),
              Expanded(
                child: _MoMItem(
                  title: 'Savings Delta',
                  pct: report.netSavingsMoMChangePct,
                  isInverse: false,
                ),
              ),
            ],
          ),
          if (report.fastestGrowingCategory != 'None') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Color(0xFF6C5CE7), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fastest Surge: ${report.fastestGrowingCategory} (+${report.fastestGrowingCategoryPct.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoMItem extends StatelessWidget {
  final String title;
  final double pct;
  final bool isInverse;
  const _MoMItem({required this.title, required this.pct, required this.isInverse});

  @override
  Widget build(BuildContext context) {
    final isPositive = pct >= 0;
    final isGood = isInverse ? !isPositive : isPositive;
    final color = isGood ? const Color(0xFF00B894) : const Color(0xFFFF7675);
    final sign = isPositive ? '+' : '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                color: color,
                size: 16,
              ),
              Text(
                '$sign${pct.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── 50/30/20 Rule Card ──────────────────────────────────────────────────────
class _Rule503020Card extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _Rule503020Card({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '50 / 30 / 20 Budget Rule Balance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.rule503020Status,
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Multi-segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, report.needsPct.round()),
                    child: Container(color: const Color(0xFF0984E3)),
                  ),
                  Expanded(
                    flex: max(1, report.wantsPct.round()),
                    child: Container(color: const Color(0xFFFD79A8)),
                  ),
                  Expanded(
                    flex: max(1, report.savingsInvestmentsPct.round()),
                    child: Container(color: const Color(0xFF00B894)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RulePill(
                label: 'Needs (50%)',
                pct: report.needsPct,
                amount: report.needsAmount,
                color: const Color(0xFF0984E3),
                currency: currency,
              ),
              _RulePill(
                label: 'Wants (30%)',
                pct: report.wantsPct,
                amount: report.wantsAmount,
                color: const Color(0xFFFD79A8),
                currency: currency,
              ),
              _RulePill(
                label: 'Savings (20%)',
                pct: report.savingsInvestmentsPct,
                amount: report.savingsInvestmentsAmount,
                color: const Color(0xFF00B894),
                currency: currency,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  final String label;
  final double pct;
  final double amount;
  final Color color;
  final String currency;
  const _RulePill({required this.label, required this.pct, required this.amount, required this.color, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${pct.toStringAsFixed(0)}% (${Formatters.formatCompactCurrency(amount, symbol: currency)})',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Actionable Insights ─────────────────────────────────────────────────────
class _ActionableInsightsCard extends StatelessWidget {
  final MonthlyReportData report;
  final bool isDark;
  const _ActionableInsightsCard({required this.report, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDCB6E), size: 18),
              SizedBox(width: 8),
              Text(
                'Financial Intelligence Insights',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...report.actionableInsights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[800],
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Top Expense Tile ────────────────────────────────────────────────────────
class _TopExpenseTile extends StatelessWidget {
  final TransactionModel tx;
  final String currency;
  final double pct;
  final bool isDark;
  const _TopExpenseTile({required this.tx, required this.currency, required this.pct, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7675).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF7675), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : tx.category,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${tx.category} • ${Formatters.formatDate(tx.date)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.formatCurrency(tx.amount, symbol: currency),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF7675)),
              ),
              Text(
                '${pct.toStringAsFixed(1)}% of total',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Interactive Donut Chart ─────────────────────────────────────────────────
class _DonutSegment {
  final double value;
  final Color color;
  final String label;
  const _DonutSegment({required this.value, required this.color, required this.label});
}

class _InteractiveDonutChart extends StatelessWidget {
  final List<_DonutSegment> segments;
  final double total;
  final String currency;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;

  const _InteractiveDonutChart({
    required this.segments,
    required this.total,
    required this.currency,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = (selectedIndex >= 0 && selectedIndex < segments.length)
        ? segments[selectedIndex]
        : null;

    return Row(
      children: [
        // Ring
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTapUp: (details) {
              if (segments.isEmpty) return;
              final next = (selectedIndex + 1) % segments.length;
              onSelectIndex(next);
            },
            child: CustomPaint(
              painter: _InteractiveDonutPainter(
                segments: segments,
                total: total,
                selectedIndex: selectedIndex,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      highlighted != null ? highlighted.label : 'Total Spent',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      Formatters.formatCompactCurrency(
                        highlighted != null ? highlighted.value : total,
                        symbol: currency,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: highlighted != null ? highlighted.color : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Legend
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: segments.take(5).map((s) {
              final idx = segments.indexOf(s);
              final isSel = selectedIndex == idx;
              final pct = total > 0 ? (s.value / total * 100) : 0.0;
              return GestureDetector(
                onTap: () => onSelectIndex(isSel ? -1 : idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSel ? s.color.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _InteractiveDonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  final int selectedIndex;
  _InteractiveDonutPainter({required this.segments, required this.total, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.85;
    const holeRatio = 0.58;
    double startAngle = -pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = total > 0 ? (seg.value / total) * 2 * pi : 0.0;
      final isSel = selectedIndex == i;

      final strokeW = (radius * (1 - holeRatio)) + (isSel ? 4 : 0);
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - radius * (1 - holeRatio) / 2),
        startAngle,
        max(0.0, sweep - 0.03),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _SelectedCategoryBadge extends StatelessWidget {
  final String name;
  final double amount;
  final double total;
  final Color color;
  final String currency;
  final int txCount;
  final double avgAmt;

  const _SelectedCategoryBadge({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
    required this.currency,
    required this.txCount,
    required this.avgAmt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total) * 100 : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              Text('$txCount transactions (Avg: ${Formatters.formatCompactCurrency(avgAmt, symbol: currency)})',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
            ],
          ),
          Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

// ─── Detailed Category Card ──────────────────────────────────────────────────
class _DetailedCategoryCard extends StatelessWidget {
  final int rank;
  final String name;
  final double amount, pct;
  final Color color;
  final IconData icon;
  final String currency;
  final int txCount;
  final double avgAmount;
  final bool isDark;

  const _DetailedCategoryCard({
    required this.rank,
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
    required this.icon,
    required this.currency,
    required this.txCount,
    required this.avgAmount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (rank > 0)
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(
                      '$txCount txs • Avg ${Formatters.formatCompactCurrency(avgAmount, symbol: currency)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(amount, symbol: currency),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Bar Chart ──────────────────────────────────────────────────────────
class _InteractiveDailyBarChart extends StatelessWidget {
  final int daysInMonth;
  final Map<int, double> dailySpend;
  final double maxSpend;
  final String currency;
  final bool isDark;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  const _InteractiveDailyBarChart({
    required this.daysInMonth,
    required this.dailySpend,
    required this.maxSpend,
    required this.currency,
    required this.isDark,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(daysInMonth, (i) {
          final day = i + 1;
          final spend = dailySpend[day] ?? 0;
          final fraction = maxSpend > 0 ? spend / maxSpend : 0.0;
          final isSelected = selectedDay == day;
          final isToday = DateTime.now().day == day;

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelectDay(day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message: 'Day $day: ${Formatters.formatCurrency(spend, symbol: currency)}',
                  child: Container(
                    height: max(4.0, fraction * 110),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D2D3)
                          : isToday
                              ? const Color(0xFF6C5CE7)
                              : spend > 0
                                  ? const Color(0xFFFF7675).withValues(alpha: 0.75)
                                  : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
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

// ─── Spend Heatmap Card ──────────────────────────────────────────────────────
class _SpendHeatmapCard extends StatelessWidget {
  final int daysInMonth;
  final Map<int, double> dailySpend;
  final double maxSpend;
  final DateTime selectedMonth;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;
  final bool isDark;
  final String currency;

  const _SpendHeatmapCard({
    required this.daysInMonth,
    required this.dailySpend,
    required this.maxSpend,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onSelectDay,
    required this.isDark,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final startWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday % 7; // 0=Sun
    final cells = startWeekday + daysInMonth;
    final rows = (cells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
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
                  final isSelected = selectedDay == day;

                  Color cellColor;
                  if (isSelected) {
                    cellColor = const Color(0xFF00D2D3);
                  } else if (spend > 0) {
                    cellColor = const Color(0xFF6C5CE7).withValues(alpha: (0.2 + intensity * 0.8).clamp(0.0, 1.0));
                  } else {
                    cellColor = Colors.grey.withValues(alpha: 0.08);
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelectDay(day),
                      child: Container(
                        height: 32,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (intensity > 0.4 || isSelected)
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : Colors.grey[700]),
                            ),
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
      ),
    );
  }
}

// ─── Weekend vs Weekday Card ─────────────────────────────────────────────────
class _WeekendWeekdayCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _WeekendWeekdayCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekend vs Weekday Spending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, report.weekdayExpensePct.round()),
                    child: Container(color: const Color(0xFF0984E3)),
                  ),
                  Expanded(
                    flex: max(1, report.weekendExpensePct.round()),
                    child: Container(color: const Color(0xFFFD79A8)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekdays (Mon-Fri)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(
                      '${Formatters.formatCompactCurrency(report.weekdayExpense, symbol: currency)} (${report.weekdayExpensePct.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0984E3)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Weekends (Sat-Sun)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(
                      '${Formatters.formatCompactCurrency(report.weekendExpense, symbol: currency)} (${report.weekendExpensePct.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFFD79A8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Day Card ───────────────────────────────────────────────────────
class _TimelineDayCard extends StatelessWidget {
  final DateTime date;
  final double spend, income;
  final List<TransactionModel> txs;
  final String currency;
  final bool isDark;

  const _TimelineDayCard({
    required this.date,
    required this.spend,
    required this.income,
    required this.txs,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6C5CE7)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Formatters.formatDate(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    Text('${txs.length} activities', style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (income > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '+${Formatters.formatCompactCurrency(income, symbol: currency)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00B894)),
                  ),
                ),
              if (spend > 0)
                Text(
                  '-${Formatters.formatCompactCurrency(spend, symbol: currency)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFF7675)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Digital vs Cash Gauge ───────────────────────────────────────────────────
class _DigitalVsCashCard extends StatelessWidget {
  final MonthlyReportData report;
  final bool isDark;
  const _DigitalVsCashCard({required this.report, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Digital Payments vs Cash Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, report.digitalSpendPct.round()),
                    child: Container(color: const Color(0xFF6C5CE7)),
                  ),
                  Expanded(
                    flex: max(1, report.cashSpendPct.round()),
                    child: Container(color: const Color(0xFF00CEC9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💳 Digital: ${report.digitalSpendPct.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
              ),
              Text(
                '💵 Cash: ${report.cashSpendPct.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Payment Method Card ─────────────────────────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  final String name;
  final double amount, pct;
  final int txCount;
  final double avgAmount;
  final String currency;
  final bool isDark;

  const _PaymentMethodCard({
    required this.name,
    required this.amount,
    required this.pct,
    required this.txCount,
    required this.avgAmount,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getPmIcon(name), color: const Color(0xFF6C5CE7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text('$txCount transactions • Avg ${Formatters.formatCompactCurrency(avgAmount, symbol: currency)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.formatCurrency(amount, symbol: currency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getPmIcon(String pm) {
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

// ─── Recurring Cost Card ─────────────────────────────────────────────────────
class _RecurringCostCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _RecurringCostCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = report.totalExpense > 0 ? (report.recurringExpenseTotal / report.totalExpense) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00CEC9).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.repeat_rounded, color: Color(0xFF00CEC9), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fixed Subscriptions & EMIs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text('${report.recurringExpenseCount} recurring debits (${pct.toStringAsFixed(1)}% of total)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(
            Formatters.formatCurrency(report.recurringExpenseTotal, symbol: currency),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF00CEC9)),
          ),
        ],
      ),
    );
  }
}

// ─── Overall Budget Card ─────────────────────────────────────────────────────
class _OverallBudgetHealthCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _OverallBudgetHealthCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isExceeded = report.totalExpense > report.budgetLimit && report.budgetLimit > 0;
    final pct = report.budgetLimit > 0 ? (report.budgetUtilization / 100.0).clamp(0.0, 1.0) : 0.0;
    final color = isExceeded ? const Color(0xFFFF7675) : const Color(0xFF00B894);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Monthly Budget: ${Formatters.formatCompactCurrency(report.budgetLimit, symbol: currency)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isExceeded ? 'OVER BUDGET' : 'ON TRACK',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${Formatters.formatCurrency(report.totalExpense, symbol: currency)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Text(
                '${report.budgetUtilization.toStringAsFixed(1)}% used',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Month-End Forecast Card ─────────────────────────────────────────────────
class _MonthEndForecastCard extends StatelessWidget {
  final MonthlyReportData report;
  final String currency;
  final bool isDark;
  const _MonthEndForecastCard({required this.report, required this.currency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Color(0xFF6C5CE7), size: 18),
              const SizedBox(width: 8),
              const Text('Velocity & Month-End Projection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (report.isCurrentMonth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF00CEC9).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('PROJECTION', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projected Month-End', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(
                      Formatters.formatCurrency(report.projectedMonthEndExpense, symbol: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Safe Daily Allowance', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Text(
                      Formatters.formatCurrency(report.safeDailySpendRemaining, symbol: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00B894)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Category Budget Card ────────────────────────────────────────────────────
class _CategoryBudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final double spent, utilization;
  final String currency;
  final bool isDark;

  const _CategoryBudgetCard({
    required this.budget,
    required this.spent,
    required this.utilization,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = spent > budget.monthlyLimit;
    final color = isExceeded ? const Color(0xFFFF7675) : const Color(0xFF00B894);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(budget.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                '${Formatters.formatCompactCurrency(spent, symbol: currency)} / ${Formatters.formatCompactCurrency(budget.monthlyLimit, symbol: currency)}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (utilization / 100.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
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
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
