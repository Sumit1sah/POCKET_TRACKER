import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Screen
// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['This Week', 'This Month', 'This Year', 'All Time'];

  late AnimationController _heroController;
  late AnimationController _barController;
  late AnimationController _pieController;
  late Animation<double> _heroAnim;
  late Animation<double> _barAnim;
  late Animation<double> _pieAnim;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _barController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pieController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _heroAnim = CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic);
    _barAnim = CurvedAnimation(parent: _barController, curve: Curves.easeOutBack);
    _pieAnim = CurvedAnimation(parent: _pieController, curve: Curves.easeOutCubic);

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _barController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pieController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _barController.dispose();
    _pieController.dispose();
    super.dispose();
  }

  void _changePeriod(String period) {
    setState(() => _selectedPeriod = period);
    _barController.reset();
    _pieController.reset();
    _barController.forward();
    _pieController.forward();
  }

  List<TransactionModel> _filter(List<TransactionModel> all) {
    final now = DateTime.now();
    return all.where((t) {
      switch (_selectedPeriod) {
        case 'This Week':
          return t.date.isAfter(now.subtract(const Duration(days: 7)));
        case 'This Month':
          return t.date.year == now.year && t.date.month == now.month;
        case 'This Year':
          return t.date.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _filter(txProvider.transactions);
    final expenses =
        filtered.where((t) => t.type == TransactionType.expense).toList();
    final incomes =
        filtered.where((t) => t.type == TransactionType.income).toList();

    final totalExpense = expenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome = incomes.fold(0.0, (s, t) => s + t.amount);
    final netBalance = totalIncome - totalExpense;
    final savingsRate =
        totalIncome > 0 ? (netBalance / totalIncome * 100) : 0.0;

    // Category totals
    final Map<String, double> catTotals = {};
    for (final t in expenses) {
      catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Last 6 months
    final now = DateTime.now();
    final monthlyData = List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      final mExp = txProvider.transactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.date.year == month.year &&
              t.date.month == month.month)
          .fold(0.0, (s, t) => s + t.amount);
      final mInc = txProvider.transactions
          .where((t) =>
              t.type == TransactionType.income &&
              t.date.year == month.year &&
              t.date.month == month.month)
          .fold(0.0, (s, t) => s + t.amount);
      return _MonthData(label: _monthShort(month.month), expense: mExp, income: mInc);
    });

    final maxMonthly = monthlyData
        .map((m) => m.expense > m.income ? m.expense : m.income)
        .reduce((a, b) => a > b ? a : b);

    final bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF0F2FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── Sticky Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark),
          ),

          // ── Period Chips ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildPeriodChips(context, isDark),
          ),

          if (filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty(context))
          else ...[
            // ── Hero Stats Card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: FadeTransition(
                  opacity: _heroAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_heroAnim),
                    child: _buildHeroCard(
                      context,
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                      netBalance: netBalance,
                      savingsRate: savingsRate,
                      currency: currency,
                    ),
                  ),
                ),
              ),
            ),

            // ── Monthly Bar Chart ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _sectionHeader(context, '📊 Monthly Overview', '6-month trend'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AnimatedBuilder(
                  animation: _barAnim,
                  builder: (_, __) => _buildPremiumBarChart(
                    context,
                    monthlyData,
                    maxMonthly,
                    isDark,
                    _barAnim.value,
                    currency,
                  ),
                ),
              ),
            ),

            // ── Donut + Category ──────────────────────────────────────────
            if (sortedCats.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _sectionHeader(
                      context, '🎯 Spending Breakdown', 'By category this period'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AnimatedBuilder(
                    animation: _pieAnim,
                    builder: (_, __) => _buildBreakdownCard(
                      context,
                      sortedCats,
                      totalExpense,
                      currency,
                      isDark,
                      _pieAnim.value,
                    ),
                  ),
                ),
              ),
            ],

            // ── Quick Stats Grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _sectionHeader(
                    context, '⚡ Quick Stats', 'At a glance'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: _buildQuickStatsGrid(
                  context,
                  expenses: expenses,
                  incomes: incomes,
                  totalExpense: totalExpense,
                  currency: currency,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                      ).createShader(const Rect.fromLTWH(0, 0, 160, 32)),
                  ),
                ),
                Text(
                  'Your financial overview',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  // ── PERIOD CHIPS ───────────────────────────────────────────────────────────
  Widget _buildPeriodChips(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _periods.map((p) {
            final isSelected = p == _selectedPeriod;
            return GestureDetector(
              onTap: () => _changePeriod(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                          ? const Color(0xFF1C1C2E)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── HERO CARD ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard(
    BuildContext context, {
    required double totalIncome,
    required double totalExpense,
    required double netBalance,
    required double savingsRate,
    required String currency,
  }) {
    final isPositive = netBalance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8A4FE8), Color(0xFF5A4FCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(netBalance, symbol: currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF00B894).withValues(alpha: 0.25)
                      : const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPositive
                        ? const Color(0xFF00B894).withValues(alpha: 0.5)
                        : const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isPositive
                          ? const Color(0xFF00B894)
                          : const Color(0xFFFF6B6B),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF00B894)
                            : const Color(0xFFFF6B6B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Income / Expense row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroStat(
                    label: 'Income',
                    amount: totalIncome,
                    currency: currency,
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF55EFC4),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _heroStat(
                    label: 'Expense',
                    amount: totalExpense,
                    currency: currency,
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFFFF7675),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required String label,
    required double amount,
    required String currency,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11)),
                Text(
                  Formatters.formatCurrency(amount, symbol: currency),
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

  // ── PREMIUM BAR CHART ──────────────────────────────────────────────────────
  Widget _buildPremiumBarChart(
    BuildContext context,
    List<_MonthData> data,
    double maxVal,
    bool isDark,
    double animValue,
    String currency,
  ) {
    final cardColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    const barMaxH = 110.0;
    const barW = 12.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _dot('Income', const Color(0xFF6C5CE7)),
              const SizedBox(width: 16),
              _dot('Expense', const Color(0xFFFF7675)),
            ],
          ),
          const SizedBox(height: 16),

          // Bars
          SizedBox(
            height: barMaxH + 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((m) {
                final incH =
                    maxVal > 0 ? (m.income / maxVal * barMaxH * animValue) : 0.0;
                final expH =
                    maxVal > 0 ? (m.expense / maxVal * barMaxH * animValue) : 0.0;
                final isCurrentMonth = m.label ==
                    _monthShort(DateTime.now().month);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value tooltip for tallest
                      SizedBox(
                        height: barMaxH,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Income bar
                                Container(
                                  width: barW,
                                  height: incH.clamp(2.0, barMaxH),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C5CE7),
                                        Color(0xFF8E7CFE),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                // Expense bar
                                Container(
                                  width: barW,
                                  height: expH.clamp(2.0, barMaxH),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B6B),
                                        Color(0xFFFF8E53),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: isCurrentMonth
                            ? BoxDecoration(
                                color: const Color(0xFF6C5CE7)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentMonth
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrentMonth
                                ? const Color(0xFF6C5CE7)
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Horizontal grid line at bottom
          const SizedBox(height: 4),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06)),
        ],
      ),
    );
  }

  // ── BREAKDOWN CARD (Donut + List) ──────────────────────────────────────────
  Widget _buildBreakdownCard(
    BuildContext context,
    List<MapEntry<String, double>> sorted,
    double total,
    String currency,
    bool isDark,
    double animValue,
  ) {
    final cardColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final catColors = _getCategoryColors(sorted);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Donut Chart
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _DonutPainter(
                    data: sorted.take(6).toList(),
                    total: total,
                    colors: catColors,
                    animValue: animValue,
                  ),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    Text(
                      Formatters.formatCurrency(total, symbol: currency),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 16),
          // Category rows
          ...sorted.take(6).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            final pct = total > 0 ? cat.value / total : 0.0;
            final color = catColors[idx % catColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat.key,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              Formatters.formatCurrency(cat.value,
                                  symbol: currency),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct * animValue,
                            minHeight: 5,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
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

  // ── QUICK STATS GRID ───────────────────────────────────────────────────────
  Widget _buildQuickStatsGrid(
    BuildContext context, {
    required List<TransactionModel> expenses,
    required List<TransactionModel> incomes,
    required double totalExpense,
    required String currency,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final daysInPeriod = _selectedPeriod == 'This Week'
        ? 7
        : _selectedPeriod == 'This Month'
            ? now.day
            : _selectedPeriod == 'This Year'
                ? now.dayOfYear
                : 30;
    final avgDaily = daysInPeriod > 0 ? totalExpense / daysInPeriod : 0.0;

    double largestExpense = 0;
    String largestCategory = '-';
    for (final t in expenses) {
      if (t.amount > largestExpense) {
        largestExpense = t.amount;
        largestCategory = t.category;
      }
    }

    final Map<String, int> catFreq = {};
    for (final t in expenses) {
      catFreq[t.category] = (catFreq[t.category] ?? 0) + 1;
    }
    final mostFrequent = catFreq.isNotEmpty
        ? catFreq.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '-';

    final stats = [
      _QuickStat(
        icon: Icons.calendar_today_rounded,
        gradient: const [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
        label: 'Daily Avg Spend',
        value: Formatters.formatCurrency(avgDaily, symbol: currency),
      ),
      _QuickStat(
        icon: Icons.receipt_long_rounded,
        gradient: const [Color(0xFFFDAA5A), Color(0xFFFF7675)],
        label: 'Transactions',
        value: '${expenses.length + incomes.length}',
      ),
      _QuickStat(
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFFF6B6B), Color(0xFFD63031)],
        label: 'Largest Expense',
        value: largestExpense > 0
            ? Formatters.formatCurrency(largestExpense, symbol: currency)
            : '-',
        subtitle: largestCategory != '-' ? largestCategory : null,
      ),
      _QuickStat(
        icon: Icons.repeat_rounded,
        gradient: const [Color(0xFF00B894), Color(0xFF00CEC9)],
        label: 'Top Category',
        value: mostFrequent,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(context, stats[i], isDark),
    );
  }

  Widget _buildStatCard(BuildContext context, _QuickStat s, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: s.gradient),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: s.gradient.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(s.icon, color: Colors.white, size: 18),
          ),
          const Spacer(),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (s.subtitle != null)
            Text(
              s.subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: s.gradient.first,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _sectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black38)),
      ],
    );
  }

  Widget _dot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)]),
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.bar_chart_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('No data yet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Add income or expenses\nto unlock analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }

  List<Color> _getCategoryColors(List<MapEntry<String, double>> cats) {
    final allCats = AppConstants.defaultCategories;
    return cats.take(6).map((e) {
      final match = allCats.firstWhere(
        (c) => c.name.toLowerCase() == e.key.toLowerCase(),
        orElse: () => allCats.first,
      );
      return match.name.toLowerCase() == e.key.toLowerCase()
          ? match.color
          : const Color(0xFF6C5CE7);
    }).toList();
  }

  String _monthShort(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[month - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut Painter
// ─────────────────────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double total;
  final List<Color> colors;
  final double animValue;

  _DonutPainter({
    required this.data,
    required this.total,
    required this.colors,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 8;
    const strokeWidth = 26.0;
    const gapAngle = 0.03;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerRadius, trackPaint);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final pct = data[i].value / total;
      final sweepAngle = (pct * math.pi * 2 - gapAngle) * animValue;
      if (sweepAngle <= 0) continue;

      final color = i < colors.length ? colors[i] : const Color(0xFF6C5CE7);

      // Shadow arc
      final shadowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
        shadowPaint,
      );

      // Main arc
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.animValue != animValue || old.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────
class _MonthData {
  final String label;
  final double expense;
  final double income;
  const _MonthData(
      {required this.label, required this.expense, required this.income});
}

class _QuickStat {
  final IconData icon;
  final List<Color> gradient;
  final String label;
  final String value;
  final String? subtitle;
  const _QuickStat({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.value,
    this.subtitle,
  });
}

extension _DateTimeExt on DateTime {
  int get dayOfYear => difference(DateTime(year, 1, 1)).inDays + 1;
}
