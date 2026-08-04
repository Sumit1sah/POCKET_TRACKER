import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Screen — Advanced Financial Intelligence & Interactive Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'This Month';
  String _chartStyle = 'bar'; // 'bar' | 'continuous'
  String? _selectedBreakdownCategory;
  DateTime? _selectedSingleDate;
  DateTimeRange? _selectedCustomRange;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _hoveredChartIndex;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  bool get _isPastMonth {
    final now = DateTime.now();
    final currentFirst = DateTime(now.year, now.month, 1);
    return _selectedMonth.isBefore(currentFirst);
  }

  bool get _isFutureMonth {
    final now = DateTime.now();
    final currentFirst = DateTime(now.year, now.month, 1);
    return _selectedMonth.isAfter(currentFirst);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      _selectedPeriod = 'This Month';
      _hoveredChartIndex = null;
    });
    _resetAndAnimate();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      _selectedPeriod = 'This Month';
      _hoveredChartIndex = null;
    });
    _resetAndAnimate();
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
      _selectedPeriod = 'This Month';
      _hoveredChartIndex = null;
    });
    _resetAndAnimate();
  }

  void _setSelectedMonth(DateTime date) {
    setState(() {
      _selectedMonth = DateTime(date.year, date.month, 1);
      _selectedPeriod = 'This Month';
      _hoveredChartIndex = null;
    });
    _resetAndAnimate();
  }

  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Last 7 Days',
    'Last 30 Days',
    'Last Month',
    'Single Date',
    'Custom Range',
    'All Time',
  ];

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
    setState(() {
      _selectedPeriod = period;
      _hoveredChartIndex = null;
    });
    _resetAndAnimate();
  }

  Future<void> _onPeriodTap(String period) async {
    if (period == 'Single Date') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedSingleDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedSingleDate = picked;
          _selectedPeriod = period;
          _hoveredChartIndex = null;
        });
        _resetAndAnimate();
      }
    } else if (period == 'Custom Range') {
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedCustomRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedCustomRange = picked;
          _selectedPeriod = period;
          _hoveredChartIndex = null;
        });
        _resetAndAnimate();
      }
    } else {
      _changePeriod(period);
    }
  }

  void _resetAndAnimate() {
    _barController.reset();
    _pieController.reset();
    _barController.forward();
    _pieController.forward();
  }

  List<TransactionModel> _filter(List<TransactionModel> all) {
    final now = DateTime.now();
    return all.where((t) {
      switch (_selectedPeriod) {
        case 'Today':
          return t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          return t.date.isAfter(start.subtract(const Duration(seconds: 1)));
        case 'Last 7 Days':
          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          return t.date.isAfter(start.subtract(const Duration(seconds: 1)));
        case 'This Month':
          return t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month;
        case 'Last Month':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          return t.date.year == lastMonth.year && t.date.month == lastMonth.month;
        case 'Last 30 Days':
          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
          return t.date.isAfter(start.subtract(const Duration(seconds: 1)));
        case 'This Year':
          return t.date.year == _selectedMonth.year;
        case 'Single Date':
          if (_selectedSingleDate == null) return true;
          return t.date.year == _selectedSingleDate!.year &&
              t.date.month == _selectedSingleDate!.month &&
              t.date.day == _selectedSingleDate!.day;
        case 'Custom Range':
          if (_selectedCustomRange == null) return true;
          final start = DateTime(
              _selectedCustomRange!.start.year,
              _selectedCustomRange!.start.month,
              _selectedCustomRange!.start.day);
          final end = DateTime(
              _selectedCustomRange!.end.year,
              _selectedCustomRange!.end.month,
              _selectedCustomRange!.end.day,
              23,
              59,
              59);
          return (t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(end.add(const Duration(seconds: 1))));
        case 'All Time':
        default:
          return true;
      }
    }).toList();
  }

  static String _dayShort(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
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
        totalIncome > 0 ? (netBalance / totalIncome * 100.0) : (netBalance > 0 ? 100.0 : 0.0);

    // Category totals
    final Map<String, double> catTotals = {};
    for (final t in expenses) {
      catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Dynamic Chart Data based on selected period
    final now = DateTime.now();
    List<_MonthData> chartData = [];
    String chartTitle = '📊 Overview';
    String chartSubtitle = 'Spending & Income trend';

    if (_selectedPeriod == 'Today' || _selectedPeriod == 'Single Date') {
      chartTitle = '📊 Hourly Breakdown';
      chartSubtitle = 'Activity by time block';
      final targetDate = _selectedPeriod == 'Single Date' ? (_selectedSingleDate ?? now) : now;

      final blocks = [
        {'label': 'Morning', 'start': 6, 'end': 12},
        {'label': 'Noon', 'start': 12, 'end': 17},
        {'label': 'Evening', 'start': 17, 'end': 21},
        {'label': 'Night', 'start': 21, 'end': 30},
      ];

      chartData = blocks.map((b) {
        final startH = b['start'] as int;
        final endH = b['end'] as int;
        final label = b['label'] as String;

        final blockTxs = txProvider.transactions.where((t) {
          if (t.date.year != targetDate.year ||
              t.date.month != targetDate.month ||
              t.date.day != targetDate.day) {
            return false;
          }
          final hour = t.date.hour;
          if (startH == 21) return hour >= 21 || hour < 6;
          return hour >= startH && hour < endH;
        }).toList();

        final exp = blockTxs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);
        final inc = blockTxs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.amount);
        return _MonthData(label: label, expense: exp, income: inc);
      }).toList();

    } else if (_selectedPeriod == 'This Week' || _selectedPeriod == 'Last 7 Days') {
      chartTitle = '📊 Daily Trend';
      chartSubtitle = 'Breakdown by day';

      chartData = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        final dayTxs = txProvider.transactions.where((t) =>
            t.date.year == d.year && t.date.month == d.month && t.date.day == d.day).toList();

        final exp = dayTxs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);
        final inc = dayTxs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.amount);
        return _MonthData(label: _dayShort(d.weekday), expense: exp, income: inc);
      });

    } else if (_selectedPeriod == 'This Month' || _selectedPeriod == 'Last Month' || _selectedPeriod == 'Last 30 Days') {
      final selectedMonthName = Formatters.formatMonthYear(_selectedMonth);
      chartTitle = '📊 Weekly Trend ($selectedMonthName)';
      chartSubtitle = 'Breakdown by week for $selectedMonthName';

      chartData = List.generate(4, (w) {
        final startDay = w * 7 + 1;
        final endDay = (w == 3) ? 31 : (w + 1) * 7;
        final weekTxs = filtered.where((t) => t.date.day >= startDay && t.date.day <= endDay).toList();

        final exp = weekTxs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);
        final inc = weekTxs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.amount);
        return _MonthData(label: 'W${w + 1}', expense: exp, income: inc);
      });

    } else if (_selectedPeriod == 'This Year') {
      chartTitle = '📊 Monthly Trend (${_selectedMonth.year})';
      chartSubtitle = 'Breakdown by month of ${_selectedMonth.year}';

      chartData = List.generate(12, (i) {
        final monthNum = i + 1;
        final mExp = txProvider.transactions
            .where((t) => t.type == TransactionType.expense && t.date.year == _selectedMonth.year && t.date.month == monthNum)
            .fold(0.0, (s, t) => s + t.amount);
        final mInc = txProvider.transactions
            .where((t) => t.type == TransactionType.income && t.date.year == _selectedMonth.year && t.date.month == monthNum)
            .fold(0.0, (s, t) => s + t.amount);
        return _MonthData(label: _monthShort(monthNum), expense: mExp, income: mInc);
      });

    } else {
      chartTitle = '📊 Multi-Month Overview';
      chartSubtitle = '6-month comparison';
      chartData = List.generate(6, (i) {
        final month = DateTime(now.year, now.month - (5 - i));
        final mExp = txProvider.transactions
            .where((t) => t.type == TransactionType.expense && t.date.year == month.year && t.date.month == month.month)
            .fold(0.0, (s, t) => s + t.amount);
        final mInc = txProvider.transactions
            .where((t) => t.type == TransactionType.income && t.date.year == month.year && t.date.month == month.month)
            .fold(0.0, (s, t) => s + t.amount);
        return _MonthData(label: _monthShort(month.month), expense: mExp, income: mInc);
      });
    }

    final maxMonthly = chartData.isEmpty
        ? 1.0
        : chartData.map((m) => math.max(m.expense, m.income)).reduce(math.max);

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

          // ── Calendar Month Selector ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildMonthSelector(context, isDark),
          ),

          // ── Period Chips ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildPeriodChips(context, isDark),
          ),

          // ── Selected Date / Range Banner ────────────────────────────────
          SliverToBoxAdapter(
            child: _buildSelectedDateBanner(context, isDark),
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


            // ── Dynamic Bar / Continuous Line Chart ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _sectionHeader(context, chartTitle, chartSubtitle)),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _chartStyle = 'bar'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _chartStyle == 'bar' ? const Color(0xFF6C5CE7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.bar_chart_rounded, size: 13, color: _chartStyle == 'bar' ? Colors.white : Colors.grey),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Bar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _chartStyle == 'bar' ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _chartStyle = 'continuous'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _chartStyle == 'continuous' ? const Color(0xFF6C5CE7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.show_chart_rounded, size: 13, color: _chartStyle == 'continuous' ? Colors.white : Colors.grey),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Flow',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _chartStyle == 'continuous' ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AnimatedBuilder(
                  animation: _barAnim,
                  builder: (context, child) => _chartStyle == 'continuous'
                      ? _buildContinuousFlowChart(
                          context,
                          chartData,
                          maxMonthly,
                          isDark,
                          _barAnim.value,
                          currency,
                        )
                      : _buildPremiumBarChart(
                          context,
                          chartData,
                          maxMonthly,
                          isDark,
                          _barAnim.value,
                          currency,
                        ),
                ),
              ),
            ),

            // ── Donut + Category Breakdown ──────────────────────────────────
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
                    builder: (context, child) => _buildBreakdownCard(
                      context,
                      sortedCats,
                      totalExpense,
                      currency,
                      isDark,
                      _pieAnim.value,
                      expenses,
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

  // ── CALENDAR MONTH SELECTOR ───────────────────────────────────────────────
  Widget _buildMonthSelector(BuildContext context, bool isDark) {
    final selected = _selectedMonth;
    final monthText = Formatters.formatMonthYear(selected);

    String cycleBadgeText = 'ACTIVE CYCLE';
    Color cycleBadgeColor = const Color(0xFF00B894);
    if (_isPastMonth) {
      cycleBadgeText = 'CLOSED CYCLE';
      cycleBadgeColor = Colors.blueGrey;
    } else if (_isFutureMonth) {
      cycleBadgeText = 'UPCOMING CYCLE';
      cycleBadgeColor = const Color(0xFF6C5CE7);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cycleBadgeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : cycleBadgeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 26),
                      tooltip: 'Previous Month',
                      onPressed: _previousMonth,
                    ),
                  ],
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _showProfessionalMonthPicker(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      monthText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cycleBadgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cycleBadgeText,
                                    style: TextStyle(
                                      color: cycleBadgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isCurrentMonth)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: TextButton.icon(
                          onPressed: _resetToCurrentMonth,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFF00B894).withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF00B894),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.today_rounded, size: 14),
                          label: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 26),
                      tooltip: 'Next Month',
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildQuickMonthSegmentBar(context, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickMonthSegmentBar(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final prev = DateTime(now.year, now.month - 1, 1);
    final next = DateTime(now.year, now.month + 1, 1);

    final months = [prev, current, next];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: months.map((m) {
          final isSelected = _selectedMonth.year == m.year &&
              _selectedMonth.month == m.month;
          final isCurrentMonth = m.year == now.year && m.month == now.month;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => _setSelectedMonth(m),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C5CE7)
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCurrentMonth ? '${DateFormat('MMM').format(m)} (Active)' : DateFormat('MMM yyyy').format(m),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showProfessionalMonthPicker(BuildContext context) {
    int tempYear = _selectedMonth.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final now = DateTime.now();
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final monthNames = [
              'January', 'February', 'March', 'April',
              'May', 'June', 'July', 'August',
              'September', 'October', 'November', 'December'
            ];

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Color(0xFF6C5CE7)),
                          SizedBox(width: 8),
                          Text(
                            'Select Analytics Month',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => setSheetState(() => tempYear--),
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6C5CE7)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => setSheetState(() => tempYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNumber = index + 1;
                      final isSelected = tempYear == _selectedMonth.year &&
                          monthNumber == _selectedMonth.month;
                      final isCurrentMonth = tempYear == now.year && monthNumber == now.month;

                      return InkWell(
                        onTap: () {
                          _setSelectedMonth(DateTime(tempYear, monthNumber, 1));
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isCurrentMonth
                                    ? const Color(0xFF00B894).withValues(alpha: 0.12)
                                    : (isDark ? Colors.grey[900] : Colors.grey[100])),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6C5CE7)
                                  : (isCurrentMonth
                                      ? const Color(0xFF00B894)
                                      : Colors.transparent),
                              width: isCurrentMonth || isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                monthNames[index].substring(0, 3).toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : (isCurrentMonth
                                          ? const Color(0xFF00B894)
                                          : (isDark ? Colors.white : Colors.black87)),
                                ),
                              ),
                              if (isCurrentMonth)
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white70 : const Color(0xFF00B894),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _resetToCurrentMonth();
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.today_rounded, size: 16),
                          label: const Text('Current Month', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Done', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── PERIOD CHIPS ──────────────────────────────────────────────────────────
  Widget _buildPeriodChips(BuildContext context, bool isDark) {
    const primaryFrontPeriods = ['Today', 'This Week', 'This Month', 'Custom Range'];
    final visibleChips = List<String>.from(primaryFrontPeriods);
    if (!primaryFrontPeriods.contains(_selectedPeriod)) {
      visibleChips.add(_selectedPeriod);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: visibleChips.map((p) {
                  final isSelected = p == _selectedPeriod;
                  return GestureDetector(
                    onTap: () => _onPeriodTap(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 12.5,
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
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter All Timeframes',
            icon: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF6C5CE7)),
            ),
            onSelected: (val) => _onPeriodTap(val),
            itemBuilder: (ctx) => _periods
                .map((p) => PopupMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Icon(
                            p == _selectedPeriod
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: const Color(0xFF6C5CE7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: p == _selectedPeriod
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── SELECTED DATE / RANGE BANNER ───────────────────────────────────────────
  Widget _buildSelectedDateBanner(BuildContext context, bool isDark) {
    if (_selectedPeriod != 'Single Date' && _selectedPeriod != 'Custom Range') {
      return const SizedBox.shrink();
    }

    String labelText = '';
    if (_selectedPeriod == 'Single Date') {
      final dateStr = _selectedSingleDate != null
          ? Formatters.formatDate(_selectedSingleDate!)
          : 'Tap to Select Date';
      labelText = 'Selected Date: $dateStr';
    } else if (_selectedPeriod == 'Custom Range') {
      if (_selectedCustomRange != null) {
        final startStr = Formatters.formatShortDate(_selectedCustomRange!.start);
        final endStr = Formatters.formatShortDate(_selectedCustomRange!.end);
        labelText = 'Selected Range: $startStr - $endStr';
      } else {
        labelText = 'Tap to Select Date Range';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: InkWell(
        onTap: () => _onPeriodTap(_selectedPeriod),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF6C5CE7), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    labelText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF6C5CE7)),
                ],
              ),
            ],
          ),
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
    final count = data.length;
    final isMany = count > 8;
    final isVeryMany = count > 10;

    final barW = isVeryMany ? 4.5 : (isMany ? 7.0 : 12.0);
    final gapW = isVeryMany ? 1.5 : (isMany ? 2.0 : 3.0);
    final fontSize = isVeryMany ? 8.5 : (isMany ? 9.5 : 10.0);
    final chipPaddingH = isVeryMany ? 2.0 : 4.0;

    final maxFormatted = Formatters.formatCompactCurrency(maxVal, symbol: currency);
    final midFormatted = Formatters.formatCompactCurrency(maxVal / 2, symbol: currency);
    final minFormatted = Formatters.formatCompactCurrency(0, symbol: currency);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, size: 13, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 4),
                    Text(
                      'Range: $minFormatted – $maxFormatted',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _dot('Income', const Color(0xFF6C5CE7)),
              const SizedBox(width: 12),
              _dot('Expense', const Color(0xFFFF7675)),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: barMaxH + 52,
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: barMaxH + 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          maxFormatted,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      Text(
                        midFormatted,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Text(
                          minFormatted,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 20),
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 26),
                              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            ),
                          ],
                        ),
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: data.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final m = entry.value;
                          final incH = maxVal > 0 ? (m.income / maxVal * barMaxH * animValue) : 0.0;
                          final expH = maxVal > 0 ? (m.expense / maxVal * barMaxH * animValue) : 0.0;
                          final highestVal = math.max(m.income, m.expense);
                          final isCurrentMonth = m.label == _monthShort(DateTime.now().month);
                          final isHovered = _hoveredChartIndex == idx;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _hoveredChartIndex = isHovered ? null : idx;
                                });
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: 14,
                                    child: highestVal > 0
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              Formatters.formatCompactCurrency(highestVal, symbol: currency),
                                              style: TextStyle(
                                                fontSize: isVeryMany ? 7.5 : 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: m.expense >= m.income
                                                    ? const Color(0xFFFF7675)
                                                    : const Color(0xFF6C5CE7),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: 2),

                                  SizedBox(
                                    height: barMaxH,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: barW,
                                          height: incH.clamp(2.0, barMaxH),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ),
                                        SizedBox(width: gapW),
                                        Container(
                                          width: barW,
                                          height: expH.clamp(2.0, barMaxH),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: chipPaddingH, vertical: 2),
                                    decoration: isCurrentMonth || isHovered
                                        ? BoxDecoration(
                                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          )
                                        : null,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        m.label,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: isCurrentMonth || isHovered ? FontWeight.bold : FontWeight.w500,
                                          color: isCurrentMonth || isHovered
                                              ? const Color(0xFF6C5CE7)
                                              : (isDark ? Colors.white54 : Colors.black45),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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

  // ── CONTINUOUS FLOW & TREND CHART ─────────────────────────────────────────
  Widget _buildContinuousFlowChart(
    BuildContext context,
    List<_MonthData> data,
    double maxVal,
    bool isDark,
    double animValue,
    String currency,
  ) {
    final cardColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    const chartHeight = 130.0;

    final maxFormatted = Formatters.formatCompactCurrency(maxVal, symbol: currency);
    final midFormatted = Formatters.formatCompactCurrency(maxVal / 2, symbol: currency);
    final minFormatted = Formatters.formatCompactCurrency(0, symbol: currency);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 13, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 4),
                    Text(
                      'Continuous: $minFormatted – $maxFormatted',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _dot('Income', const Color(0xFF6C5CE7)),
              const SizedBox(width: 12),
              _dot('Expense', const Color(0xFFFF7675)),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: chartHeight + 40,
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: chartHeight + 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          maxFormatted,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      Text(
                        midFormatted,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Text(
                          minFormatted,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 10),
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 26),
                              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            ),
                          ],
                        ),
                      ),

                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ContinuousLinePainter(
                            data: data,
                            maxVal: maxVal,
                            animValue: animValue,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  static Map<String, dynamic> _getCategoryMeta(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('food') || lower.contains('grocer') || lower.contains('fuel') || lower.contains('rent') || lower.contains('bill') || lower.contains('health') || lower.contains('medic')) {
      return {'tag': 'Needs', 'color': const Color(0xFF00B894), 'icon': Icons.shopping_basket_rounded};
    } else if (lower.contains('shop') || lower.contains('entertain') || lower.contains('movie') || lower.contains('travel') || lower.contains('cafe')) {
      return {'tag': 'Wants', 'color': const Color(0xFFE17055), 'icon': Icons.local_activity_rounded};
    } else if (lower.contains('debt') || lower.contains('emi') || lower.contains('loan') || lower.contains('repay')) {
      return {'tag': 'Obligations', 'color': const Color(0xFFD63031), 'icon': Icons.credit_card_rounded};
    } else {
      return {'tag': 'General', 'color': const Color(0xFF0984E3), 'icon': Icons.category_rounded};
    }
  }

  // ── BREAKDOWN CARD ────────────────────────────────────────────────────────
  Widget _buildBreakdownCard(
    BuildContext context,
    List<MapEntry<String, double>> sorted,
    double total,
    String currency,
    bool isDark,
    double animValue,
    List<TransactionModel> expenses,
  ) {
    final cardColor = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final catColors = _getCategoryColors(sorted);

    MapEntry<String, double>? selectedEntry;
    if (_selectedBreakdownCategory != null) {
      for (final e in sorted) {
        if (e.key == _selectedBreakdownCategory) {
          selectedEntry = e;
          break;
        }
      }
    }

    final displayLabel = selectedEntry != null ? selectedEntry.key : 'Total Expense';
    final displayAmount = selectedEntry != null ? selectedEntry.value : total;
    final displayPct = (total > 0 && selectedEntry != null)
        ? (selectedEntry.value / total * 100).toStringAsFixed(1)
        : null;

    final displayList = sorted.toList();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(190, 190),
                    painter: _DonutPainter(
                      data: sorted,
                      total: total,
                      colors: catColors,
                      animValue: animValue,
                      selectedCategory: _selectedBreakdownCategory,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedBreakdownCategory = null);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.formatCurrency(displayAmount, symbol: currency),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (displayPct != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$displayPct% of total',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (sorted.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top spending: ${sorted.first.key} (${(total > 0 ? (sorted.first.value / total * 100) : 0).toStringAsFixed(0)}% of total)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 16),

          ...displayList.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            final pct = total > 0 ? cat.value / total : 0.0;
            final color = catColors[idx % catColors.length];
            final isSelected = _selectedBreakdownCategory == cat.key;
            final meta = _getCategoryMeta(cat.key);
            final categoryTransactions = expenses.where((t) => t.category == cat.key).toList();
            final txCount = categoryTransactions.length;

            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedBreakdownCategory == cat.key) {
                        _selectedBreakdownCategory = null;
                      } else {
                        _selectedBreakdownCategory = cat.key;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF252538) : const Color(0xFFF8F9FE)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(meta['icon'] as IconData, size: 16, color: color),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        cat.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (meta['color'] as Color).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          meta['tag'] as String,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: meta['color'] as Color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    Formatters.formatCurrency(cat.value, symbol: currency),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct * animValue,
                                        minHeight: 5,
                                        backgroundColor: color.withValues(alpha: 0.12),
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                  if (txCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '• $txCount txns',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isSelected && categoryTransactions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions in ${cat.key}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                            ),
                            Text(
                              '${categoryTransactions.length} entries',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...categoryTransactions.take(4).map((tx) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_rounded, size: 12, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tx.description.isNotEmpty ? tx.description : tx.paymentMethod,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                Formatters.formatShortDate(tx.date),
                                style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '-$currency${Formatters.formatCurrency(tx.amount, symbol: "")}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF7675)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── ADVANCED QUICK STATS GRID ─────────────────────────────────────────────
  Widget _buildQuickStatsGrid(
    BuildContext context, {
    required List<TransactionModel> expenses,
    required List<TransactionModel> incomes,
    required double totalExpense,
    required String currency,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final daysInPeriod = _selectedPeriod == 'Today'
        ? 1
        : _selectedPeriod == 'This Week' || _selectedPeriod == 'Last 7 Days'
            ? 7
            : _selectedPeriod == 'This Month' || _selectedPeriod == 'Last Month' || _selectedPeriod == 'Last 30 Days'
                ? now.day
                : _selectedPeriod == 'This Year'
                    ? now.dayOfYear
                    : 30;

    final avgDaily = daysInPeriod > 0 ? totalExpense / daysInPeriod : 0.0;
    final avgTxSize = expenses.isNotEmpty ? totalExpense / expenses.length : 0.0;

    double largestExpense = 0;
    String largestCategory = '-';
    String largestMerchant = '';
    for (final t in expenses) {
      if (t.amount > largestExpense) {
        largestExpense = t.amount;
        largestCategory = t.category;
        largestMerchant = t.description;
      }
    }

    final Map<String, int> catFreq = {};
    for (final t in expenses) {
      catFreq[t.category] = (catFreq[t.category] ?? 0) + 1;
    }
    final mostFrequentEntry = catFreq.isNotEmpty
        ? catFreq.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final Map<int, double> dayTotals = {};
    for (final t in expenses) {
      dayTotals[t.date.weekday] = (dayTotals[t.date.weekday] ?? 0.0) + t.amount;
    }
    final peakDayEntry = dayTotals.isNotEmpty
        ? dayTotals.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final peakDayName = peakDayEntry != null ? _dayShort(peakDayEntry.key) : '-';
    final peakDayAmount = peakDayEntry != null ? peakDayEntry.value : 0.0;

    final totalInc = incomes.fold(0.0, (s, t) => s + t.amount);
    final retentionPct = totalInc > 0 ? ((totalInc - totalExpense) / totalInc * 100) : 0.0;

    final stats = [
      _QuickStat(
        icon: Icons.calendar_today_rounded,
        gradient: const [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
        label: 'Daily Avg Spend',
        value: Formatters.formatCurrency(avgDaily, symbol: currency),
        subtitle: 'Est. Mo: ${Formatters.formatCompactCurrency(avgDaily * 30, symbol: currency)}',
        badge: 'Daily',
      ),
      _QuickStat(
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFFF6B6B), Color(0xFFD63031)],
        label: 'Largest Expense',
        value: largestExpense > 0
            ? Formatters.formatCurrency(largestExpense, symbol: currency)
            : '-',
        subtitle: largestMerchant.isNotEmpty
            ? largestMerchant
            : (largestCategory != '-' ? largestCategory : null),
        badge: largestCategory != '-' ? largestCategory : null,
      ),
      _QuickStat(
        icon: Icons.event_repeat_rounded,
        gradient: const [Color(0xFFFDAA5A), Color(0xFFFF7675)],
        label: 'Peak Spend Day',
        value: peakDayEntry != null ? '$peakDayName (${Formatters.formatCompactCurrency(peakDayAmount, symbol: currency)})' : '-',
        subtitle: peakDayEntry != null ? 'Highest daily outflow' : null,
        badge: 'Peak',
      ),
      _QuickStat(
        icon: Icons.repeat_rounded,
        gradient: const [Color(0xFF00B894), Color(0xFF00CEC9)],
        label: 'Top Category',
        value: mostFrequentEntry?.key ?? '-',
        subtitle: mostFrequentEntry != null ? '${mostFrequentEntry.value} transactions' : null,
        badge: 'Frequent',
      ),
      _QuickStat(
        icon: Icons.receipt_long_rounded,
        gradient: const [Color(0xFF0984E3), Color(0xFF74B9FF)],
        label: 'Avg Tx Size',
        value: Formatters.formatCurrency(avgTxSize, symbol: currency),
        subtitle: '${expenses.length + incomes.length} total txns',
        badge: '${expenses.length} exp',
      ),
      _QuickStat(
        icon: Icons.savings_rounded,
        gradient: const [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
        label: 'Income Retained',
        value: totalInc > 0 ? '${retentionPct.toStringAsFixed(1)}%' : 'N/A',
        subtitle: retentionPct >= 0 ? 'Positive Savings' : 'Deficit spend',
        badge: retentionPct >= 0 ? '🟢 Safe' : '🔴 Alert',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(context, stats[i], isDark),
    );
  }

  Widget _buildStatCard(BuildContext context, _QuickStat s, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
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
                child: Icon(s.icon, color: Colors.white, size: 16),
              ),
              if (s.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: s.gradient.first.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.badge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: s.gradient.first,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              s.value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ),
          if (s.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              s.subtitle!,
              style: TextStyle(
                fontSize: 9.5,
                color: s.gradient.first,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
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
  final String? selectedCategory;

  _DonutPainter({
    required this.data,
    required this.total,
    required this.colors,
    required this.animValue,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 10;
    const baseStrokeWidth = 24.0;
    const gapAngle = 0.03;

    final trackPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerRadius, trackPaint);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final catKey = data[i].key;
      final isSelected = selectedCategory == catKey;
      final isAnySelected = selectedCategory != null;

      final pct = data[i].value / total;
      final sweepAngle = (pct * math.pi * 2 - gapAngle) * animValue;
      if (sweepAngle <= 0) continue;

      Color color = i < colors.length ? colors[i] : const Color(0xFF6C5CE7);
      if (isAnySelected && !isSelected) {
        color = color.withValues(alpha: 0.3);
      }

      final strokeWidth = isSelected ? baseStrokeWidth + 6.0 : baseStrokeWidth;

      if (isSelected) {
        final shadowPaint = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          startAngle,
          sweepAngle,
          false,
          shadowPaint,
        );
      }

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
      old.animValue != animValue || old.data != data || old.selectedCategory != selectedCategory;
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
  final String? badge;
  const _QuickStat({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.value,
    this.subtitle,
    this.badge,
  });
}

extension _DateTimeExt on DateTime {
  int get dayOfYear => difference(DateTime(year, 1, 1)).inDays + 1;
}

class _ContinuousLinePainter extends CustomPainter {
  final List<_MonthData> data;
  final double maxVal;
  final double animValue;
  final bool isDark;

  _ContinuousLinePainter({
    required this.data,
    required this.maxVal,
    required this.animValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartH = size.height - 28;
    final chartW = size.width;
    final count = data.length;
    final stepX = count > 1 ? chartW / (count - 1) : chartW;

    final expPoints = <Offset>[];
    final incPoints = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = (count == 1) ? chartW / 2 : i * stepX;
      final eVal = maxVal > 0 ? (data[i].expense / maxVal * chartH * animValue) : 0.0;
      final iVal = maxVal > 0 ? (data[i].income / maxVal * chartH * animValue) : 0.0;

      final ey = chartH - eVal + 6;
      final iy = chartH - iVal + 6;

      expPoints.add(Offset(x, ey));
      incPoints.add(Offset(x, iy));
    }

    void drawSmoothCurve(List<Offset> points, Color color) {
      if (points.isEmpty) return;

      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, chartH + 6);
      fillPath.lineTo(points.first.dx, chartH + 6);
      fillPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, chartW, chartH + 6))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, areaPaint);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()..color = color;
      final innerDotPaint = Paint()..color = Colors.white;

      for (final pt in points) {
        canvas.drawCircle(pt, 3.5, dotPaint);
        canvas.drawCircle(pt, 1.5, innerDotPaint);
      }
    }

    drawSmoothCurve(incPoints, const Color(0xFF6C5CE7));
    drawSmoothCurve(expPoints, const Color(0xFFFF7675));

    final textStyle = TextStyle(
      fontSize: count > 10 ? 8.0 : 9.0,
      color: isDark ? Colors.white54 : Colors.black45,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < count; i++) {
      final textSpan = TextSpan(text: data[i].label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (count == 1) ? chartW / 2 : i * stepX;
      final clampedX = (x - textPainter.width / 2).clamp(0.0, chartW - textPainter.width);
      textPainter.paint(
        canvas,
        Offset(clampedX, chartH + 12),
      );
    }
  }

  @override
  bool shouldRepaint(_ContinuousLinePainter old) =>
      old.animValue != animValue || old.data != data || old.isDark != isDark;
}
