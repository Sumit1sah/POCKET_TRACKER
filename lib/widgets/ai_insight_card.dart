import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/savings_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../services/ai_insight_service.dart';

class AIInsightCard extends StatelessWidget {
  const AIInsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final transactions = txProvider.transactions;
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final savingsProvider = Provider.of<SavingsProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;

    // Build budget data for AI engine
    final overallStatus = budgetProvider.getOverallBudgetStatus(transactions);
    final categoryStatuses = budgetProvider.getCategoryBudgetStatuses(transactions);

    final Map<String, double> categoryLimits = {
      for (final s in categoryStatuses) s.budget.category: s.budget.monthlyLimit,
    };
    final Map<String, double> categorySpend = {
      for (final s in categoryStatuses) s.budget.category: s.spent,
    };

    final budgetData = overallStatus.budget.monthlyLimit > 0
        ? BudgetInsightData(
            overallLimit: overallStatus.budget.monthlyLimit,
            totalSpent: overallStatus.spent,
            categoryLimits: categoryLimits,
            categorySpend: categorySpend,
          )
        : null;

    final insights = AIInsightService.generateInsights(
      transactions,
      currency,
      budget: budgetData,
      savingsGoals: savingsProvider.goals,
      totalCreditLimit: txProvider.totalCreditLimit,
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    // Show top insight inline, rest in bottom sheet
    final topInsight = insights.first;
    final hasMore = insights.length > 1;

    final (Color color, IconData icon) = _resolveStyle(topInsight.type);

    return GestureDetector(
      onTap: hasMore
          ? () => _showAllInsights(context, insights, currency)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topInsight.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topInsight.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasMore) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mini insight badges
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: insights.skip(1).take(3).map((ins) {
                          final (Color bc, _) = _resolveStyle(ins.type);
                          return Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: bc.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: bc.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _shortLabel(ins.type),
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: bc),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showAllInsights(context, insights, currency),
                    icon: const Icon(Icons.expand_more_rounded, size: 14),
                    label: Text(
                      '${insights.length - 1} more',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllInsights(
      BuildContext context, List<AIInsight> insights, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AIInsightsSheet(insights: insights, currency: currency),
    );
  }

  static (Color, IconData) _resolveStyle(String type) {
    switch (type) {
      case 'health_score':
        return (const Color(0xFF6C5CE7), Icons.speed_rounded);
      case 'prediction':
        return (const Color(0xFF0984E3), Icons.psychology_rounded);
      case 'critical':
        return (const Color(0xFFD63031), Icons.error_outline_rounded);
      case 'warning':
        return (const Color(0xFFE17055), Icons.warning_amber_rounded);
      case 'positive':
        return (const Color(0xFF00B894), Icons.check_circle_outline_rounded);
      case 'tip':
      default:
        return (const Color(0xFF6C5CE7), Icons.auto_awesome_rounded);
    }
  }

  static String _shortLabel(String type) {
    switch (type) {
      case 'health_score':
        return '🌟 Score';
      case 'prediction':
        return '🔮 Forecast';
      case 'critical':
        return '🚨 Critical';
      case 'warning':
        return '⚠️ Warning';
      case 'positive':
        return '✅ Good';
      case 'tip':
      default:
        return '💡 Tip';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full AI Insights Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AIInsightsSheet extends StatefulWidget {
  final List<AIInsight> insights;
  final String currency;

  const _AIInsightsSheet({required this.insights, required this.currency});

  @override
  State<_AIInsightsSheet> createState() => _AIInsightsSheetState();
}

class _AIInsightsSheetState extends State<_AIInsightsSheet> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    final healthScores =
        widget.insights.where((i) => i.type == 'health_score').toList();
    final criticals =
        widget.insights.where((i) => i.type == 'critical').toList();
    final warnings =
        widget.insights.where((i) => i.type == 'warning').toList();
    final predictions =
        widget.insights.where((i) => i.type == 'prediction').toList();
    final tips = widget.insights.where((i) => i.type == 'tip').toList();
    final positives =
        widget.insights.where((i) => i.type == 'positive').toList();

    List<AIInsight> filteredList = widget.insights;
    if (_selectedFilter == 'Tips') {
      filteredList = tips;
    } else if (_selectedFilter == 'Alerts') {
      filteredList = [...criticals, ...warnings];
    } else if (_selectedFilter == 'Forecasts') {
      filteredList = predictions;
    } else if (_selectedFilter == 'Wins') {
      filteredList = positives;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF6C5CE7), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Financial Insights & Money Tips',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.insights.length} personalized insights & money tips',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Filter Pills Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChipItem(
                    label: 'All (${widget.insights.length})',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  _FilterChipItem(
                    label: '💡 Money Tips (${tips.length})',
                    isSelected: _selectedFilter == 'Tips',
                    color: const Color(0xFF6C5CE7),
                    onTap: () => setState(() => _selectedFilter = 'Tips'),
                  ),
                  if (criticals.isNotEmpty || warnings.isNotEmpty)
                    _FilterChipItem(
                      label: '🚨 Alerts (${criticals.length + warnings.length})',
                      isSelected: _selectedFilter == 'Alerts',
                      color: const Color(0xFFE17055),
                      onTap: () => setState(() => _selectedFilter = 'Alerts'),
                    ),
                  if (predictions.isNotEmpty)
                    _FilterChipItem(
                      label: '🔮 Forecasts (${predictions.length})',
                      isSelected: _selectedFilter == 'Forecasts',
                      color: const Color(0xFF0984E3),
                      onTap: () => setState(() => _selectedFilter = 'Forecasts'),
                    ),
                  if (positives.isNotEmpty)
                    _FilterChipItem(
                      label: '✅ Wins (${positives.length})',
                      isSelected: _selectedFilter == 'Wins',
                      color: const Color(0xFF00B894),
                      onTap: () => setState(() => _selectedFilter = 'Wins'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 8),
            // Insight list
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (_selectedFilter == 'All') ...[
                    if (healthScores.isNotEmpty) ...[
                      ...healthScores.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                      const SizedBox(height: 8),
                    ],
                    if (criticals.isNotEmpty) ...[
                      _SectionHeader(
                          label: '🚨 Critical Alerts',
                          color: const Color(0xFFD63031)),
                      ...criticals.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                      const SizedBox(height: 8),
                    ],
                    if (warnings.isNotEmpty) ...[
                      _SectionHeader(
                          label: '⚠️ Spending Warnings',
                          color: const Color(0xFFE17055)),
                      ...warnings.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                      const SizedBox(height: 8),
                    ],
                    if (predictions.isNotEmpty) ...[
                      _SectionHeader(
                          label: '🔮 Predictive Goal Forecasts',
                          color: const Color(0xFF0984E3)),
                      ...predictions.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                      const SizedBox(height: 8),
                    ],
                    if (tips.isNotEmpty) ...[
                      _SectionHeader(
                          label: '💡 Financial Advice & Money Tips',
                          color: const Color(0xFF6C5CE7)),
                      ...tips.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                      const SizedBox(height: 8),
                    ],
                    if (positives.isNotEmpty) ...[
                      _SectionHeader(
                          label: '✅ Financial Wins',
                          color: const Color(0xFF00B894)),
                      ...positives.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                    ],
                  ] else ...[
                    if (filteredList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No insights under this category.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...filteredList.map((i) => _InsightTile(insight: i, currency: widget.currency)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    this.color = const Color(0xFF6C5CE7),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final AIInsight insight;
  final String currency;
  const _InsightTile({required this.insight, required this.currency});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) =
        AIInsightCard._resolveStyle(insight.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                    if (insight.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          insight.category!,
                          style: TextStyle(
                              fontSize: 9.5,
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  insight.description,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.75)),
                ),
                if (insight.impactAmount != null &&
                    insight.impactAmount! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 12, color: color),
                      const SizedBox(width: 3),
                      Text(
                        'Impact: $currency ${insight.impactAmount!.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

