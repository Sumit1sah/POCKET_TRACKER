import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../widgets/category_icon_widget.dart';
import '../../widgets/transaction_tile.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all'; // 'all', 'exceeded', 'warning', 'ontrack', 'unbudgeted'
  bool _isChartView = false; // false = Cards View, true = Visual Chart View
  int _touchedPieIndex = -1;

  static double mathMax(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final categories = Provider.of<CategoryProvider>(context).categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final overallStatus = budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final categoryStatuses = budgetProvider.getCategoryBudgetStatuses(txProvider.transactions);
    final unbudgetedList = budgetProvider.getUnbudgetedCategories(txProvider.transactions);

    final overallLimit = overallStatus.budget.monthlyLimit;
    final totalAllocated = budgetProvider.totalAllocatedCategoryBudget;
    final unallocatedBuffer = budgetProvider.getUnallocatedBuffer(overallLimit);
    final allocationRatio = budgetProvider.getAllocationRatio(overallLimit);

    final exceededStatuses = categoryStatuses.where((s) => s.isExceeded).toList();
    final warningStatuses = categoryStatuses.where((s) => s.isWarning).toList();
    final onTrackStatuses = categoryStatuses.where((s) => !s.isExceeded && !s.isWarning).toList();

    final now = DateTime.now();
    final daysInMonth = DateTime(budgetProvider.selectedMonth.year, budgetProvider.selectedMonth.month + 1, 0).day;
    final currentDay = budgetProvider.isCurrentMonth ? now.day : daysInMonth;
    final remainingDays = (daysInMonth - currentDay) > 0 ? (daysInMonth - currentDay) : 1;
    final remainingBudget = mathMax(0.0, overallStatus.remaining);
    final dailyPace = remainingDays > 0 ? (remainingBudget / remainingDays) : 0.0;

    // Velocity & Month-End Projection Calculation
    final actualDailyBurn = currentDay > 0 ? (overallStatus.spent / currentDay) : 0.0;
    final projectedMonthEnd = overallStatus.spent + (actualDailyBurn * remainingDays);
    final projectedSurplus = overallLimit > 0 ? (overallLimit - projectedMonthEnd) : 0.0;

    // Filter categories based on selected tab
    List<BudgetStatus> displayedStatuses = categoryStatuses;
    if (_selectedFilter == 'exceeded') {
      displayedStatuses = exceededStatuses;
    } else if (_selectedFilter == 'warning') {
      displayedStatuses = warningStatuses;
    } else if (_selectedFilter == 'ontrack') {
      displayedStatuses = onTrackStatuses;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090912) : const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF090912) : const Color(0xFFF3F5FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Budget Planning',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6C5CE7), size: 20),
            tooltip: 'Transfer / Reallocate Funds',
            onPressed: () => _showTransferFundsDialog(context, budgetProvider, categoryStatuses, currency),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 20),
            tooltip: 'Smart Budget Allocator',
            onPressed: () => _showAutoAllocateDialog(
              context,
              budgetProvider,
              txProvider.transactions,
              categories,
              overallLimit > 0 ? overallLimit : 30000.0,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF6C5CE7), size: 20),
            tooltip: 'Cycle & Month Options',
            onPressed: () => _showFreshMonthOptions(context, budgetProvider, txProvider.transactions, categories, overallLimit),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(left: 12, right: 12, top: 2, bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Compact Month Selector Header ---
            _buildCompactMonthSelector(context, budgetProvider),

            // --- Compact Monthly Cycle Status Banner ---
            _buildCompactCycleBanner(context, budgetProvider),

            // --- Critical Warning / Exceeded Banner ---
            if (exceededStatuses.isNotEmpty || overallStatus.isExceeded)
              _buildCompactCriticalAlertBanner(isDark, overallStatus.isExceeded, exceededStatuses.length)
            else if (warningStatuses.isNotEmpty)
              _buildCompactWarningAlertBanner(isDark, warningStatuses.length),

            // --- Compact Hero Health & Velocity Dashboard Card ---
            _buildCompactHeroCard(
              context,
              overallStatus: overallStatus,
              overallLimit: overallLimit,
              totalAllocated: totalAllocated,
              unallocatedBuffer: unallocatedBuffer,
              allocationRatio: allocationRatio,
              dailyPace: dailyPace,
              actualDailyBurn: actualDailyBurn,
              projectedMonthEnd: projectedMonthEnd,
              projectedSurplus: projectedSurplus,
              currentDay: currentDay,
              daysInMonth: daysInMonth,
              remainingDays: remainingDays,
              currency: currency,
              categories: categories,
              budgetProvider: budgetProvider,
              txTransactions: txProvider.transactions,
              categoryStatuses: categoryStatuses,
            ),
            const SizedBox(height: 12),

            // --- Compact Unbudgeted Expenses Callout (if any) ---
            if (unbudgetedList.isNotEmpty && _selectedFilter != 'exceeded' && _selectedFilter != 'warning' && _selectedFilter != 'ontrack')
              _buildCompactUnbudgetedCallout(context, unbudgetedList, categories, currency, isDark),

            // --- Category Section Header & Filter Pills ---
            _buildCategoryHeader(
              context,
              categoryStatuses: categoryStatuses,
              unbudgetedCount: unbudgetedList.length,
              categories: categories,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // --- Content View: Spacious Charts or Cards ---
            if (_selectedFilter == 'unbudgeted')
              _buildUnbudgetedList(context, unbudgetedList, categories, currency, isDark)
            else if (_isChartView)
              _buildVisualAnalytics(
                context,
                categoryStatuses: categoryStatuses,
                overallLimit: overallLimit,
                currency: currency,
                categories: categories,
                isDark: isDark,
              )
            else
              _buildCategoryCards(
                context,
                statuses: displayedStatuses,
                overallLimit: overallLimit,
                remainingDays: remainingDays,
                currentDay: currentDay,
                daysInMonth: daysInMonth,
                currency: currency,
                categories: categories,
                budgetProvider: budgetProvider,
                txTransactions: txProvider.transactions,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPACT HERO HEALTH & VELOCITY DASHBOARD CARD
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCompactHeroCard(
    BuildContext context, {
    required BudgetStatus overallStatus,
    required double overallLimit,
    required double totalAllocated,
    required double unallocatedBuffer,
    required double allocationRatio,
    required double dailyPace,
    required double actualDailyBurn,
    required double projectedMonthEnd,
    required double projectedSurplus,
    required int currentDay,
    required int daysInMonth,
    required int remainingDays,
    required String currency,
    required List<CategoryModel> categories,
    required BudgetProvider budgetProvider,
    required List<TransactionModel> txTransactions,
    required List<BudgetStatus> categoryStatuses,
  }) {
    final double pct = overallLimit > 0 ? (overallStatus.spent / overallLimit) : 0.0;
    final double clampedPct = pct.clamp(0.0, 1.0);

    Color healthColor = const Color(0xFF00B894);
    String healthTitle = 'Safe & On Track';
    if (overallStatus.isExceeded) {
      healthColor = const Color(0xFFFF7675);
      healthTitle = 'Limit Exceeded';
    } else if (pct >= 0.9) {
      healthColor = const Color(0xFFFF7675);
      healthTitle = 'Critical (90%+)';
    } else if (pct >= 0.8) {
      healthColor = const Color(0xFFFDCB6E);
      healthTitle = 'Caution (80%+)';
    }

    final double monthProgressPct = daysInMonth > 0 ? (currentDay / daysInMonth) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A2050),
            Color(0xFF1E173D),
            Color(0xFF161230),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Compact Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: healthColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: healthColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        healthTitle,
                        style: TextStyle(
                          color: healthColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _showAddBudgetDialog(
                    context,
                    categories,
                    initialCategory: 'Overall',
                    initialAmount: overallLimit,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text('Edit Target', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Hero Radial Gauge + Amount Highlights Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact Radial Gauge (72x72)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 6.5,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: clampedPct,
                          strokeWidth: 6.5,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'SPENT',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 7.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Amount Figures
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining Allowance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          overallLimit > 0
                              ? Formatters.formatCurrency(overallStatus.remaining, symbol: currency)
                              : 'No Target Set',
                          style: TextStyle(
                            color: overallStatus.remaining < 0 ? const Color(0xFFFF7675) : const Color(0xFF55EFC4),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        'Spent ${Formatters.formatCurrency(overallStatus.spent, symbol: currency)} of ${overallLimit > 0 ? Formatters.formatCurrency(overallLimit, symbol: currency) : "₹0"}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3 Compact Metric Tiles in 1 Row
            Row(
              children: [
                Expanded(
                  child: _buildCompactMetricTile(
                    icon: Icons.speed_rounded,
                    iconColor: const Color(0xFF55EFC4),
                    label: 'Safe Pace',
                    value: '${Formatters.formatCurrency(dailyPace, symbol: currency)}/d',
                    sub: '$remainingDays days left',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactMetricTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFDCB6E),
                    label: 'Current Burn',
                    value: '${Formatters.formatCurrency(actualDailyBurn, symbol: currency)}/d',
                    sub: 'Day $currentDay of $daysInMonth',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactMetricTile(
                    icon: Icons.auto_graph_rounded,
                    iconColor: projectedSurplus >= 0 ? const Color(0xFF55EFC4) : const Color(0xFFFF7675),
                    label: 'Forecast End',
                    value: Formatters.formatCurrency(projectedMonthEnd, symbol: currency),
                    sub: projectedSurplus >= 0
                        ? '+${Formatters.formatCurrency(projectedSurplus, symbol: currency)}'
                        : '-${Formatters.formatCurrency(projectedSurplus.abs(), symbol: currency)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Compact Month Elapsed vs Budget Spent Synchronizer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Day $currentDay of $daysInMonth (${(monthProgressPct * 100).toStringAsFixed(0)}% elapsed)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                      ),
                      Text(
                        'Buffer: ${Formatters.formatCurrency(unallocatedBuffer, symbol: currency)}',
                        style: const TextStyle(color: Color(0xFF55EFC4), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: monthProgressPct.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: clampedPct,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: healthColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Compact Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAutoAllocateDialog(
                      context,
                      budgetProvider,
                      txTransactions,
                      categories,
                      overallLimit > 0 ? overallLimit : 30000.0,
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 13),
                    label: const Text('Smart Allocator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _showTransferFundsDialog(context, budgetProvider, categoryStatuses, currency),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white),
                  label: const Text('Move Funds', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 8.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          Text(
            sub,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPACT MONTH SELECTOR & QUICK SEGMENT BAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCompactMonthSelector(BuildContext context, BudgetProvider budgetProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = budgetProvider.selectedMonth;
    final monthText = Formatters.formatMonthYear(selected);

    String cycleBadgeText = 'ACTIVE';
    Color cycleBadgeColor = const Color(0xFF00B894);
    if (budgetProvider.isPastMonth) {
      cycleBadgeText = 'CLOSED';
      cycleBadgeColor = Colors.blueGrey;
    } else if (budgetProvider.isFutureMonth) {
      cycleBadgeText = 'UPCOMING';
      cycleBadgeColor = const Color(0xFF6C5CE7);
    }

    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final prev = DateTime(now.year, now.month - 1, 1);
    final next = DateTime(now.year, now.month + 1, 1);
    final months = [prev, current, next];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cycleBadgeColor.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                tooltip: 'Previous Month',
                onPressed: () => budgetProvider.previousMonth(),
              ),
              InkWell(
                onTap: () => _showProfessionalMonthPicker(context, budgetProvider),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        monthText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cycleBadgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cycleBadgeText,
                          style: TextStyle(color: cycleBadgeColor, fontWeight: FontWeight.bold, fontSize: 8),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 16),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!budgetProvider.isCurrentMonth)
                    InkWell(
                      onTap: () => budgetProvider.resetToCurrentMonth(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    tooltip: 'Next Month',
                    onPressed: () => budgetProvider.nextMonth(),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: months.map((m) {
              final isSelected = budgetProvider.selectedMonth.year == m.year &&
                  budgetProvider.selectedMonth.month == m.month;
              final isCurrentMonth = m.year == now.year && m.month == now.month;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => budgetProvider.setSelectedMonth(m),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C5CE7)
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCurrentMonth ? '${DateFormat('MMM').format(m)} (Active)' : DateFormat('MMM yyyy').format(m),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _buildCompactCycleBanner(BuildContext context, BudgetProvider budgetProvider) {
    if (budgetProvider.isCurrentMonth) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00B894).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.published_with_changes_rounded, color: Color(0xFF00B894), size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Active Month • Spending tracks against targets. Limits roll over automatically.',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF00B894)),
              ),
            ),
          ],
        ),
      );
    } else {
      final isPast = budgetProvider.isPastMonth;
      final color = isPast ? Colors.blueGrey : const Color(0xFF6C5CE7);
      final label = isPast ? 'Closed Month' : 'Upcoming Month';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(isPast ? Icons.history_rounded : Icons.upcoming_rounded, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label • ${Formatters.formatMonthYear(budgetProvider.selectedMonth)}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCompactCriticalAlertBanner(bool isDark, bool isOverallExceeded, int exceededCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7675).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF7675).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7675), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOverallExceeded
                  ? 'Overall Monthly Budget Exceeded! Rebalance funds.'
                  : '$exceededCount Category Budget(s) Exceeded! Use "Move Funds" to balance.',
              style: const TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactWarningAlertBanner(bool isDark, int warningCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDCB6E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFE67E22), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$warningCount category budget(s) have reached 80%+ capacity.',
              style: TextStyle(color: isDark ? const Color(0xFFFDCB6E) : const Color(0xFFD35400), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPACT UNBUDGETED CALLOUT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCompactUnbudgetedCallout(
    BuildContext context,
    List<UnbudgetedCategoryStatus> unbudgetedList,
    List<CategoryModel> categories,
    String currency,
    bool isDark,
  ) {
    final double totalUnbudgeted = unbudgetedList.fold(0.0, (sum, u) => sum + u.spent);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1730) : const Color(0xFFF2EFFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: Color(0xFF6C5CE7), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${unbudgetedList.length} unbudgeted spend (${Formatters.formatCurrency(totalUnbudgeted, symbol: currency)})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _selectedFilter = 'unbudgeted'),
            child: const Text('Review →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────────
  // CATEGORY ALLOCATION HEADER & FILTER PILLS (SPACIOUS & MODERN)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryHeader(
    BuildContext context, {
    required List<BudgetStatus> categoryStatuses,
    required int unbudgetedCount,
    required List<CategoryModel> categories,
    required bool isDark,
  }) {
    final exceededCount = categoryStatuses.where((s) => s.isExceeded).length;
    final warningCount = categoryStatuses.where((s) => s.isWarning).length;
    final onTrackCount = categoryStatuses.where((s) => !s.isExceeded && !s.isWarning).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category Allocations',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Mode Toggle (Cards vs Donut)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161626) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildToggleBtn(Icons.view_agenda_rounded, 'Cards', !_isChartView, () => setState(() => _isChartView = false), isDark),
                      _buildToggleBtn(Icons.pie_chart_rounded, 'Chart', _isChartView, () => setState(() => _isChartView = true), isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddBudgetDialog(
                    context,
                    categories,
                    initialCategory: categories.isNotEmpty ? categories.first.name : 'Food',
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('all', 'All (${categoryStatuses.length})', null),
              if (exceededCount > 0)
                _buildFilterChip('exceeded', '🚨 Exceeded ($exceededCount)', const Color(0xFFFF7675)),
              if (warningCount > 0)
                _buildFilterChip('warning', '⚠️ Caution ($warningCount)', const Color(0xFFFDCB6E)),
              _buildFilterChip('ontrack', '✅ On Track ($onTrackCount)', const Color(0xFF00B894)),
              if (unbudgetedCount > 0)
                _buildFilterChip('unbudgeted', '❓ Unbudgeted ($unbudgetedCount)', const Color(0xFF6C5CE7)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(IconData icon, String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color? highlightColor) {
    final bool isSelected = _selectedFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = key),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (highlightColor ?? const Color(0xFF6C5CE7))
                : (isDark ? const Color(0xFF161626) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (highlightColor ?? const Color(0xFF6C5CE7))
                  : (highlightColor?.withValues(alpha: 0.25) ?? Colors.transparent),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (highlightColor ?? const Color(0xFF6C5CE7)).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (highlightColor ?? (isDark ? Colors.white70 : Colors.black87)),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CATEGORY ALLOCATION CARDS (SPACIOUS, RICH & DETAILED)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryCards(
    BuildContext context, {
    required List<BudgetStatus> statuses,
    required double overallLimit,
    required int remainingDays,
    required int currentDay,
    required int daysInMonth,
    required String currency,
    required List<CategoryModel> categories,
    required BudgetProvider budgetProvider,
    required List<TransactionModel> txTransactions,
    required bool isDark,
  }) {
    if (statuses.isEmpty) {
      return _buildEmptyState(context, overallLimit, isDark);
    }

    final double monthProgressPct = daysInMonth > 0 ? (currentDay / daysInMonth) : 0.0;

    return Column(
      children: statuses.map((status) {
        final b = status.budget;
        final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
        final catMatch = allCats.firstWhere(
          (c) => c.name.toLowerCase() == b.category.toLowerCase(),
          orElse: () => allCats.first,
        );

        Color progressColor = const Color(0xFF00B894);
        String alertBadgeText = 'On Track';
        if (status.isExceeded) {
          progressColor = const Color(0xFFFF7675);
          alertBadgeText = 'EXCEEDED';
        } else if (status.percentage >= 0.9) {
          progressColor = const Color(0xFFFF7675);
          alertBadgeText = '90% Used';
        } else if (status.percentage >= 0.8) {
          progressColor = const Color(0xFFFDCB6E);
          alertBadgeText = '80% Used';
        }

        final double categorySharePct = overallLimit > 0 ? (b.monthlyLimit / overallLimit) * 100 : 0.0;
        final double remainingCategory = mathMax(0.0, status.remaining);
        final double catDailyPace = remainingDays > 0 ? (remainingCategory / remainingDays) : 0.0;

        final double diffFromMonthPace = status.percentage - monthProgressPct;
        String paceText = 'Safe pace';
        Color paceColor = const Color(0xFF00B894);
        if (diffFromMonthPace > 0.15) {
          paceText = '+${(diffFromMonthPace * 100).toStringAsFixed(0)}% fast';
          paceColor = const Color(0xFFFF7675);
        } else if (diffFromMonthPace < -0.15) {
          paceText = '${(diffFromMonthPace.abs() * 100).toStringAsFixed(0)}% saved';
          paceColor = const Color(0xFF00B894);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161626) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: progressColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
          ),
          child: InkWell(
            onTap: () => _showCategoryTransactionsSheet(context, b.category, txTransactions, currency, isDark),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CategoryIconWidget(
                        category: catMatch,
                        size: 42,
                        iconSize: 21,
                        showTypeBadge: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    b.category,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catMatch.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${categorySharePct.toStringAsFixed(0)}% of total',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: catMatch.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Safe pace: ${Formatters.formatCurrency(catDailyPace, symbol: currency)}/d',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: paceColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    paceText,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: paceColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showAddBudgetDialog(
                              context,
                              categories,
                              initialCategory: b.category,
                              initialAmount: b.monthlyLimit,
                            );
                          } else if (val == 'transfer') {
                            _showTransferFundsDialog(
                              context,
                              budgetProvider,
                              statuses,
                              currency,
                              initialSourceCategory: b.category,
                            );
                          } else if (val == 'history') {
                            _showCategoryTransactionsSheet(context, b.category, txTransactions, currency, isDark);
                          } else if (val == 'delete') {
                            budgetProvider.deleteBudget(b.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'history',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF6C5CE7)),
                                SizedBox(width: 10),
                                Text('View Transactions', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF00B894)),
                                SizedBox(width: 10),
                                Text('Move Funds', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16, color: Color(0xFF6C5CE7)),
                                SizedBox(width: 10),
                                Text('Edit Limit', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 16, color: Color(0xFFFF7675)),
                                SizedBox(width: 10),
                                Text('Delete Limit', style: TextStyle(fontSize: 13, color: Color(0xFFFF7675))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spent: ',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                          Text(
                            Formatters.formatCurrency(status.spent, symbol: currency),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: progressColor,
                            ),
                          ),
                          Text(
                            ' of ${Formatters.formatCurrency(b.monthlyLimit, symbol: currency)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: progressColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          alertBadgeText,
                          style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: status.percentage.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: progressColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VISUAL ANALYTICS VIEW (SPACIOUS PIE / DONUT BREAKDOWN)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildVisualAnalytics(
    BuildContext context, {
    required List<BudgetStatus> categoryStatuses,
    required double overallLimit,
    required String currency,
    required List<CategoryModel> categories,
    required bool isDark,
  }) {
    if (categoryStatuses.isEmpty) {
      return _buildEmptyState(context, overallLimit, isDark);
    }

    final double totalLimit = categoryStatuses.fold(0.0, (sum, s) => sum + s.budget.monthlyLimit);
    final double totalSpent = categoryStatuses.fold(0.0, (sum, s) => sum + s.spent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Allocation Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Total Spent: ${Formatters.formatCurrency(totalSpent, symbol: currency)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spacious Donut Chart
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                sections: List.generate(categoryStatuses.length, (i) {
                  final s = categoryStatuses[i];
                  final isTouched = i == _touchedPieIndex;
                  final double radius = isTouched ? 44.0 : 38.0;
                  final double pct = totalLimit > 0 ? (s.budget.monthlyLimit / totalLimit) * 100 : 0.0;

                  final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
                  final catMatch = allCats.firstWhere(
                    (c) => c.name.toLowerCase() == s.budget.category.toLowerCase(),
                    orElse: () => allCats.first,
                  );
                  return PieChartSectionData(
                    color: catMatch.color,
                    value: s.budget.monthlyLimit,
                    title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                    radius: radius,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 18),

          ...categoryStatuses.map((s) {
            final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
            final catMatch = allCats.firstWhere(
              (c) => c.name.toLowerCase() == s.budget.category.toLowerCase(),
              orElse: () => allCats.first,
            );
            final double pctOfLimit = s.percentage;
            final Color color = s.isExceeded
                ? const Color(0xFFFF7675)
                : (pctOfLimit >= 0.8 ? const Color(0xFFFDCB6E) : const Color(0xFF00B894));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: catMatch.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.budget.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                      Text(
                        '${Formatters.formatCurrency(s.spent, symbol: currency)} / ${Formatters.formatCurrency(s.budget.monthlyLimit, symbol: currency)}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pctOfLimit.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // SPACIOUS UNBUDGETED LIST
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildUnbudgetedList(
    BuildContext context,
    List<UnbudgetedCategoryStatus> unbudgetedList,
    List<CategoryModel> categories,
    String currency,
    bool isDark,
  ) {
    if (unbudgetedList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161626) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('All categories with expenses this month have budget limits assigned! 🎉', style: TextStyle(fontSize: 13)),
        ),
      );
    }

    return Column(
      children: unbudgetedList.map((item) {
        final allCats = categories.isNotEmpty ? categories : AppConstants.defaultCategories;
        final catMatch = allCats.firstWhere(
          (c) => c.name.toLowerCase() == item.category.toLowerCase(),
          orElse: () => allCats.first,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161626) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CategoryIconWidget(category: catMatch, size: 40, showTypeBadge: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${item.transactionCount} transactions • Spent: ${Formatters.formatCurrency(item.spent, symbol: currency)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showAddBudgetDialog(
                  context,
                  categories,
                  initialCategory: item.category,
                  initialAmount: item.spent * 1.2,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Set Budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPACT EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, double overallLimit, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pie_chart_outline_rounded, size: 36, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 10),
          const Text(
            'No category budget allocations set.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribute your target budget across Food, Grocery, Bills, Travel & more.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
              final txProvider = Provider.of<TransactionProvider>(context, listen: false);
              final categories = Provider.of<CategoryProvider>(context, listen: false).categories;
              _showAutoAllocateDialog(context, budgetProvider, txProvider.transactions, categories, overallLimit > 0 ? overallLimit : 30000.0);
            },
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('Smart Auto-Allocate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // INTERACTIVE SMART ALLOCATOR MODAL
  // ─────────────────────────────────────────────────────────────────────────────
  void _showAutoAllocateDialog(
    BuildContext context,
    BudgetProvider budgetProvider,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    double currentOverallLimit,
  ) {
    final limitController = TextEditingController(
      text: currentOverallLimit > 0 ? currentOverallLimit.toStringAsFixed(0) : '30000',
    );

    final Map<String, TextEditingController> percentControllers = {
      'Grocery': TextEditingController(text: '20'),
      'Bills': TextEditingController(text: '15'),
      'Travel': TextEditingController(text: '15'),
      'Food': TextEditingController(text: '15'),
      'Shopping': TextEditingController(text: '10'),
      'Entertainment': TextEditingController(text: '5'),
      'Investment': TextEditingController(text: '20'),
    };

    final Map<String, IconData> categoryIcons = {
      'Investment': Icons.trending_up,
      'Grocery': Icons.local_grocery_store,
      'Bills': Icons.receipt_long,
      'Travel': Icons.directions_car,
      'Food': Icons.restaurant,
      'Shopping': Icons.shopping_bag,
      'Entertainment': Icons.movie,
      'Rent': Icons.home,
      'Medical': Icons.medical_services,
      'Fuel': Icons.local_gas_station,
      'Education': Icons.school,
    };

    String activePreset = '50_30_20';

    void applyPreset(String preset, void Function(void Function()) setDialogState) {
      activePreset = preset;
      if (preset == '50_30_20') {
        percentControllers['Grocery']?.text = '20';
        percentControllers['Bills']?.text = '15';
        percentControllers['Travel']?.text = '15';
        percentControllers['Food']?.text = '15';
        percentControllers['Shopping']?.text = '10';
        percentControllers['Entertainment']?.text = '5';
        percentControllers['Investment']?.text = '20';
      } else if (preset == '70_20_10') {
        percentControllers['Grocery']?.text = '25';
        percentControllers['Bills']?.text = '25';
        percentControllers['Travel']?.text = '20';
        percentControllers['Investment']?.text = '20';
        percentControllers['Food']?.text = '5';
        percentControllers['Shopping']?.text = '5';
        percentControllers['Entertainment']?.text = '0';
      } else if (preset == 'prev_month') {
        final prevSpending = budgetProvider.getPreviousMonthCategorySpending(transactions, categories: categories);
        final totalPrev = prevSpending.values.fold(0.0, (sum, val) => sum + val);

        if (totalPrev > 0) {
          percentControllers.forEach((cat, ctrl) {
            final spent = prevSpending[cat] ?? 0.0;
            final pct = ((spent / totalPrev) * 100).round();
            ctrl.text = pct.toString();
          });
        }
      }
      setDialogState(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final overallLimit = double.tryParse(limitController.text) ?? 0.0;

            double totalPercent = 0.0;
            final Map<String, double> currentPercentages = {};

            percentControllers.forEach((cat, ctrl) {
              final pct = double.tryParse(ctrl.text) ?? 0.0;
              currentPercentages[cat] = pct;
              totalPercent += pct;
            });

            final bool isValidTotal = (totalPercent - 100.0).abs() < 0.1;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Smart Budget Allocator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose a rule preset or customize individual percentages:',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      const SizedBox(height: 10),

                      // Presets Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('🌟 50/30/20', activePreset == '50_30_20', () => applyPreset('50_30_20', setDialogState)),
                            const SizedBox(width: 6),
                            _buildPresetChip('🎯 70/20/10', activePreset == '70_20_10', () => applyPreset('70_20_10', setDialogState)),
                            const SizedBox(width: 6),
                            _buildPresetChip('🔄 Last Month', activePreset == 'prev_month', () => applyPreset('prev_month', setDialogState)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: limitController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monthly Target Budget',
                          prefixText: '₹ ',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Category Allocations',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isValidTotal
                                  ? const Color(0xFF00B894).withValues(alpha: 0.15)
                                  : const Color(0xFFFF7675).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Total: ${totalPercent.toStringAsFixed(0)}% ${isValidTotal ? '✅' : '⚠️ Must=100%'}',
                              style: TextStyle(
                                color: isValidTotal ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      ...percentControllers.entries.map((entry) {
                        final catName = entry.key;
                        final ctrl = entry.value;
                        final pct = double.tryParse(ctrl.text) ?? 0.0;
                        final calculatedAmount = (overallLimit * (pct / 100.0)).roundToDouble();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(categoryIcons[catName] ?? Icons.category, size: 15, color: const Color(0xFF6C5CE7)),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  catName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                height: 30,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    suffixStyle: const TextStyle(fontSize: 10),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    isDense: true,
                                  ),
                                  onChanged: (_) {
                                    activePreset = 'custom';
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 65,
                                child: Text(
                                  '₹${calculatedAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              actions: [
                TextButton(
                  onPressed: () => applyPreset('50_30_20', setDialogState),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final target = double.tryParse(limitController.text);
                    if (target != null && target > 0) {
                      if (!isValidTotal) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Percentages sum to ${totalPercent.toStringAsFixed(0)}%. Please make total 100%.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      budgetProvider.autoAllocateBudgets(
                        target,
                        categoryPercentages: currentPercentages,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Smart budget allocation applied!')),
                      );
                    }
                  },
                  child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C5CE7) : const Color(0xFF6C5CE7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF6C5CE7),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MONEY TRANSFER & REBALANCE DIALOG ("MOVE FUNDS")
  // ─────────────────────────────────────────────────────────────────────────────
  void _showTransferFundsDialog(
    BuildContext context,
    BudgetProvider budgetProvider,
    List<BudgetStatus> statuses,
    String currency, {
    String? initialSourceCategory,
  }) {
    if (statuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one category budget before transferring funds.')),
      );
      return;
    }

    final categoryNames = statuses.map((s) => s.budget.category).toList();
    String sourceCategory = initialSourceCategory ?? categoryNames.first;
    String destCategory = categoryNames.length > 1
        ? categoryNames.firstWhere((c) => c.toLowerCase() != sourceCategory.toLowerCase(), orElse: () => categoryNames.first)
        : categoryNames.first;

    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final sourceStatus = statuses.firstWhere(
              (s) => s.budget.category.toLowerCase() == sourceCategory.toLowerCase(),
              orElse: () => statuses.first,
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: Color(0xFF6C5CE7), size: 18),
                  SizedBox(width: 8),
                  Text('Move Funds Between Budgets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reallocate monthly limit from surplus category to another:', style: TextStyle(fontSize: 11.5)),
                    const SizedBox(height: 10),

                    // From Category
                    DropdownButtonFormField<String>(
                      initialValue: sourceCategory,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'From (Source)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: categoryNames.map((cat) {
                        final s = statuses.firstWhere((st) => st.budget.category == cat);
                        return DropdownMenuItem(
                          value: cat,
                          child: Text('$cat (Limit: ₹${s.budget.monthlyLimit.toStringAsFixed(0)})', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => sourceCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available limit: ${Formatters.formatCurrency(sourceStatus.budget.monthlyLimit, symbol: currency)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    // To Category
                    DropdownButtonFormField<String>(
                      initialValue: destCategory,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'To (Destination)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: categoryNames.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => destCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Amount Field
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Transfer Amount',
                        prefixText: '$currency ',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [500, 1000, 2000, 5000].map((amt) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                final cur = double.tryParse(amountController.text) ?? 0.0;
                                amountController.text = (cur + amt).toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('+$amt', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
                      return;
                    }
                    if (sourceCategory.toLowerCase() == destCategory.toLowerCase()) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and destination must be different.')));
                      return;
                    }
                    if (amount > sourceStatus.budget.monthlyLimit) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer amount exceeds source category limit.')));
                      return;
                    }

                    final success = await budgetProvider.transferBudget(
                      fromCategory: sourceCategory,
                      toCategory: destCategory,
                      amount: amount,
                    );
                    if (success) {
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Moved ${Formatters.formatCurrency(amount, symbol: currency)} from $sourceCategory to $destCategory!')),
                        );
                      }
                    }
                  },
                  child: const Text('Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CATEGORY TRANSACTIONS BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCategoryTransactionsSheet(
    BuildContext context,
    String categoryName,
    List<TransactionModel> allTransactions,
    String currency,
    bool isDark,
  ) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final targetMonth = budgetProvider.selectedMonth;

    final categoryTxs = allTransactions.where((t) =>
        t.category.toLowerCase() == categoryName.toLowerCase() &&
        t.date.year == targetMonth.year &&
        t.date.month == targetMonth.month).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalSpent = categoryTxs.fold(0.0, (sum, t) => sum + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$categoryName Transactions',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${Formatters.formatMonthYear(targetMonth)} • ${categoryTxs.length} items',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.formatCurrency(totalSpent, symbol: currency),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF6C5CE7)),
                  ),
                ],
              ),
              const Divider(height: 16),

              if (categoryTxs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No transactions recorded in this category for this month.', style: TextStyle(fontSize: 12)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categoryTxs.length,
                    itemBuilder: (context, index) {
                      return TransactionTile(
                        transaction: categoryTxs[index],
                        showDeleteButton: false,
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

  // ─────────────────────────────────────────────────────────────────────────────
  // ADD / EDIT BUDGET DIALOG
  // ─────────────────────────────────────────────────────────────────────────────
  void _showAddBudgetDialog(
    BuildContext context,
    List<CategoryModel> categories, {
    String? initialCategory,
    double? initialAmount,
  }) {
    final limitController = TextEditingController(text: initialAmount != null ? initialAmount.toStringAsFixed(0) : '');
    String selectedCategory = initialCategory ?? 'Overall';

    final List<String> targetOptions = ['Overall', ...categories.map((c) => c.name)];
    if (!targetOptions.contains(selectedCategory) && selectedCategory.isNotEmpty) {
      targetOptions.add(selectedCategory);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                selectedCategory == 'Overall' ? 'Set Target Monthly Budget' : 'Set Category Budget Limit',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: targetOptions.contains(selectedCategory) ? selectedCategory : targetOptions.first,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Budget Scope / Category', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: targetOptions.map<DropdownMenuItem<String>>((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Text(name == 'Overall' ? 'Overall Monthly Target' : name, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Limit Amount',
                        prefixText: '₹ ',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1000, 2000, 5000, 10000].map((amt) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                final cur = double.tryParse(limitController.text) ?? 0.0;
                                limitController.text = (cur + amt).toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('+₹$amt', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final limit = double.tryParse(limitController.text);
                    if (limit != null && limit > 0) {
                      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                      budgetProvider.setBudget(
                        BudgetModel(
                          id: 'b_${selectedCategory.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
                          uid: 'local_user',
                          category: selectedCategory,
                          monthlyLimit: limit,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PROFESSIONAL MONTH PICKER BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────────
  void _showProfessionalMonthPicker(BuildContext context, BudgetProvider budgetProvider) {
    int tempYear = budgetProvider.selectedMonth.year;

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Color(0xFF6C5CE7), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Select Budget Month',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          onPressed: () => setSheetState(() => tempYear--),
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6C5CE7)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          onPressed: () => setSheetState(() => tempYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNumber = index + 1;
                      final isSelected = tempYear == budgetProvider.selectedMonth.year &&
                          monthNumber == budgetProvider.selectedMonth.month;
                      final isCurrentMonth = tempYear == now.year && monthNumber == now.month;

                      return InkWell(
                        onTap: () {
                          budgetProvider.setSelectedMonth(DateTime(tempYear, monthNumber, 1));
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
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
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6C5CE7)
                                  : (isCurrentMonth
                                      ? const Color(0xFF00B894)
                                      : Colors.transparent),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                monthNames[index].substring(0, 3).toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                                    fontSize: 7.5,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            budgetProvider.resetToCurrentMonth();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Current Month', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done', style: TextStyle(fontSize: 11)),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // FRESH MONTH & CYCLE OPTIONS
  // ─────────────────────────────────────────────────────────────────────────────
  void _showFreshMonthOptions(
    BuildContext context,
    BudgetProvider budgetProvider,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    double overallLimit,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final monthStr = Formatters.formatMonthYear(budgetProvider.selectedMonth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.published_with_changes_rounded, color: Color(0xFF6C5CE7), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Budget Cycle Options ($monthStr)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Spending resets to ₹0 when a new month starts while target limits carry over.',
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const Divider(height: 16),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 18),
                title: const Text('Smart Auto-Allocate Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Apply 50/30/20 or previous month spend rules', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutoAllocateDialog(context, budgetProvider, transactions, categories, overallLimit > 0 ? overallLimit : 30000.0);
                },
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF00B894), size: 18),
                title: const Text('Renew Current Monthly Limits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Carry existing target limits into this cycle', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Monthly budget limits confirmed for $monthStr!')),
                  );
                },
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFFF7675), size: 18),
                title: const Text('Clear All Category Allocations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Start with a blank slate for this month', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Clear All Allocations?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      content: const Text('This will remove all category budget limits so you can configure a fresh budget setup.', style: TextStyle(fontSize: 12)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), foregroundColor: Colors.white, minimumSize: const Size(0, 32)),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await budgetProvider.clearAllBudgets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All category budget allocations cleared for fresh setup.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
