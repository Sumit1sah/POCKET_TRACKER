import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/theme_currency_provider.dart';
import '../services/ai_insight_service.dart';

class AIInsightCard extends StatelessWidget {
  const AIInsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = Provider.of<TransactionProvider>(context).transactions;
    final budgetProvider = Provider.of<BudgetProvider>(context);
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
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
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topInsight.description,
                        style: TextStyle(
                          fontSize: 12,
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
              const SizedBox(height: 10),
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
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: bc.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: bc.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _shortLabel(ins.type),
                              style: TextStyle(
                                  fontSize: 10,
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
                    icon: const Icon(Icons.expand_more_rounded, size: 16),
                    label: Text(
                      '${insights.length - 1} more',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
class _AIInsightsSheet extends StatelessWidget {
  final List<AIInsight> insights;
  final String currency;

  const _AIInsightsSheet({required this.insights, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    // Separate by severity
    final criticals =
        insights.where((i) => i.type == 'critical').toList();
    final warnings =
        insights.where((i) => i.type == 'warning').toList();
    final tips = insights.where((i) => i.type == 'tip').toList();
    final positives =
        insights.where((i) => i.type == 'positive').toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                          'AI Financial Insights',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${insights.length} personalized insights based on your budget & spending',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  // Summary chips
                  if (criticals.isNotEmpty)
                    _SummaryPill(
                        label: criticals.length.toString(),
                        color: const Color(0xFFD63031)),
                  if (warnings.isNotEmpty)
                    _SummaryPill(
                        label: warnings.length.toString(),
                        color: const Color(0xFFE17055)),
                  if (positives.isNotEmpty)
                    _SummaryPill(
                        label: positives.length.toString(),
                        color: const Color(0xFF00B894)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.grey.shade200, height: 20),
            // Insight list
            Expanded(
              child: ListView(
                controller: scrollController,
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (criticals.isNotEmpty) ...[
                    _SectionHeader(
                        label: '🚨 Critical Alerts',
                        color: const Color(0xFFD63031)),
                    ...criticals.map((i) => _InsightTile(insight: i)),
                    const SizedBox(height: 8),
                  ],
                  if (warnings.isNotEmpty) ...[
                    _SectionHeader(
                        label: '⚠️ Warnings',
                        color: const Color(0xFFE17055)),
                    ...warnings.map((i) => _InsightTile(insight: i)),
                    const SizedBox(height: 8),
                  ],
                  if (tips.isNotEmpty) ...[
                    _SectionHeader(
                        label: '💡 Smart Tips',
                        color: const Color(0xFF6C5CE7)),
                    ...tips.map((i) => _InsightTile(insight: i)),
                    const SizedBox(height: 8),
                  ],
                  if (positives.isNotEmpty) ...[
                    _SectionHeader(
                        label: '✅ Positives',
                        color: const Color(0xFF00B894)),
                    ...positives.map((i) => _InsightTile(insight: i)),
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
  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) =
        AIInsightCard._resolveStyle(insight.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
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
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (insight.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          insight.category!,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.75)),
                ),
                if (insight.impactAmount != null &&
                    insight.impactAmount! > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Impact: ₹${insight.impactAmount!.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
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
