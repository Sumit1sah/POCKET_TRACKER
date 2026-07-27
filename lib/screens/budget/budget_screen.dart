import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/budget_model.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final categories = Provider.of<CategoryProvider>(context).categories;

    final overallStatus = budgetProvider.getOverallBudgetStatus(txProvider.transactions);
    final categoryStatuses = budgetProvider.getCategoryBudgetStatuses(txProvider.transactions);

    final overallLimit = overallStatus.budget.monthlyLimit;
    final totalAllocated = budgetProvider.totalAllocatedCategoryBudget;
    final unallocatedBuffer = budgetProvider.getUnallocatedBuffer(overallLimit);
    final allocationRatio = budgetProvider.getAllocationRatio(overallLimit);

    final exceededCount = categoryStatuses.where((s) => s.isExceeded).length;
    final warningCount = categoryStatuses.where((s) => s.isWarning).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Allocation & Planning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Fresh Month Options',
            onPressed: () => _showFreshMonthOptions(context, budgetProvider, overallLimit),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Smart Budget Allocator',
            onPressed: () => _showAutoAllocateDialog(context, overallLimit > 0 ? overallLimit : 30000.0),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Month Selector & Navigation Header ---
            _buildMonthSelector(context, budgetProvider),

            // --- Monthly Cycle Status Banner ---
            _buildCycleStatusBanner(context, budgetProvider),

            // --- Exceeded / Critical Alert Banners ---
            if (exceededCount > 0 || overallStatus.isExceeded)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7675).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF7675).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7675)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        overallStatus.isExceeded
                            ? 'Critical Alert: Overall monthly budget limit exceeded!'
                            : '$exceededCount category budget(s) exceeded! Reallocate funds to stay on track.',
                        style: const TextStyle(
                          color: Color(0xFFFF7675),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (warningCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDCB6E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFE67E22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attention: $warningCount category budget(s) reached 80%+ capacity.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFDCB6E)
                              : const Color(0xFFD35400),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // --- Overall Monthly Budget & Allocation Overview Card ---
            _buildAllocationOverviewCard(
              context,
              overallStatus: overallStatus,
              totalAllocated: totalAllocated,
              unallocatedBuffer: unallocatedBuffer,
              allocationRatio: allocationRatio,
              currency: currency,
              categories: categories,
            ),
            const SizedBox(height: 24),

            // --- Category Breakdown Section Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Category Budget Allocations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddBudgetDialog(context, categories, initialCategory: categories.first.name),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (categoryStatuses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No category budget allocations set.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Allocate your monthly budget across Food, Shopping, Bills, Fuel & more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showAutoAllocateDialog(context, overallLimit > 0 ? overallLimit : 30000.0),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Smart Auto-Allocate'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ...categoryStatuses.map((status) {
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catMatch.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(catMatch.iconData, color: catMatch.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.category,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    '${categorySharePct.toStringAsFixed(1)}% of total budget',
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: progressColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                alertBadgeText,
                                style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                              onPressed: () {
                                _showAddBudgetDialog(context, categories, initialCategory: b.category, initialAmount: b.monthlyLimit);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                              onPressed: () {
                                budgetProvider.deleteBudget(b.id);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent: ${Formatters.formatCurrency(status.spent, symbol: currency)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Limit: ${Formatters.formatCurrency(b.monthlyLimit, symbol: currency)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: status.percentage.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationOverviewCard(
    BuildContext context, {
    required BudgetStatus overallStatus,
    required double totalAllocated,
    required double unallocatedBuffer,
    required double allocationRatio,
    required String currency,
    required List categories,
  }) {
    final overallLimit = overallStatus.budget.monthlyLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            const Color(0xFF4834DF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Overall Monthly Allocation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white),
                tooltip: 'Edit Overall Budget',
                onPressed: () => _showAddBudgetDialog(context, categories, initialCategory: 'Overall', initialAmount: overallLimit),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Limit', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  Text(
                    overallLimit > 0
                        ? Formatters.formatCurrency(overallLimit, symbol: currency)
                        : 'Not Configured',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Allocated to Categories', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  Text(
                    Formatters.formatCurrency(totalAllocated, symbol: currency),
                    style: const TextStyle(color: Color(0xFF00CEC9), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Allocation ratio bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Category Allocation: ${(allocationRatio * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buffer: ${Formatters.formatCurrency(unallocatedBuffer, symbol: currency)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: allocationRatio.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00CEC9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAutoAllocateDialog(context, overallLimit > 0 ? overallLimit : 30000.0),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Smart Auto-Allocate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _showAddBudgetDialog(context, categories, initialCategory: 'Overall', initialAmount: overallLimit),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Edit Limit', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAutoAllocateDialog(BuildContext context, double currentOverallLimit) {
    final limitController = TextEditingController(
      text: currentOverallLimit > 0 ? currentOverallLimit.toStringAsFixed(0) : '30000',
    );

    // Initial percentage configuration
    final Map<String, TextEditingController> percentControllers = {
      'Investment': TextEditingController(text: '20'),
      'Grocery': TextEditingController(text: '20'),
      'Bills': TextEditingController(text: '15'),
      'Travel': TextEditingController(text: '15'),
      'Food': TextEditingController(text: '15'),
      'Shopping': TextEditingController(text: '10'),
      'Entertainment': TextEditingController(text: '5'),
    };

    final Map<String, IconData> categoryIcons = {
      'Investment': Icons.trending_up,
      'Grocery': Icons.local_grocery_store,
      'Bills': Icons.receipt_long,
      'Travel': Icons.directions_car,
      'Food': Icons.restaurant,
      'Shopping': Icons.shopping_bag,
      'Entertainment': Icons.movie,
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final overallLimit = double.tryParse(limitController.text) ?? 0.0;

            // Compute total percentage sum
            double totalPercent = 0.0;
            final Map<String, double> currentPercentages = {};

            percentControllers.forEach((cat, ctrl) {
              final pct = double.tryParse(ctrl.text) ?? 0.0;
              currentPercentages[cat] = pct;
              totalPercent += pct;
            });

            final bool isValidTotal = (totalPercent - 100.0).abs() < 0.1;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Smart Budget Allocator', style: TextStyle(fontSize: 16)),
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
                        'Set your total target budget & adjust percentages for each category:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      // Overall Budget Input
                      TextField(
                        controller: limitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Monthly Target Budget',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Percentage Sum Chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Category Percentages',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isValidTotal
                                  ? const Color(0xFF00B894).withValues(alpha: 0.15)
                                  : const Color(0xFFFF7675).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Total: ${totalPercent.toStringAsFixed(0)}% ${isValidTotal ? '✅' : '⚠️'}',
                              style: TextStyle(
                                color: isValidTotal ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Category Percentage List
                      ...percentControllers.entries.map((entry) {
                        final catName = entry.key;
                        final ctrl = entry.value;
                        final pct = double.tryParse(ctrl.text) ?? 0.0;
                        final calculatedAmount = (overallLimit * (pct / 100.0)).roundToDouble();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(categoryIcons[catName] ?? Icons.category, size: 18, color: const Color(0xFF6C5CE7)),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  catName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 65,
                                height: 38,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 75,
                                child: Text(
                                  '₹${calculatedAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
              actions: [
                TextButton(
                  onPressed: () {
                    // Reset to default 50/30/20 rules
                    percentControllers['Investment']?.text = '20';
                    percentControllers['Grocery']?.text = '20';
                    percentControllers['Bills']?.text = '15';
                    percentControllers['Travel']?.text = '15';
                    percentControllers['Food']?.text = '15';
                    percentControllers['Shopping']?.text = '10';
                    percentControllers['Entertainment']?.text = '5';
                    setState(() {});
                  },
                  child: const Text('Reset Rules'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final target = double.tryParse(limitController.text);
                    if (target != null && target > 0) {
                      if (!isValidTotal) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Category percentages sum to ${totalPercent.toStringAsFixed(0)}%. Please adjust to 100%.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                      budgetProvider.autoAllocateBudgets(
                        target,
                        categoryPercentages: currentPercentages,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Custom percentage budget allocation applied!')),
                      );
                    }
                  },
                  child: const Text('Apply Allocation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBudgetDialog(
    BuildContext context,
    List categories, {
    String? initialCategory,
    double? initialAmount,
  }) {
    final limitController = TextEditingController(text: initialAmount != null ? initialAmount.toStringAsFixed(0) : '');
    String selectedCategory = initialCategory ?? 'Overall';

    final List<String> targetOptions = ['Overall', ...categories.map((c) => c.name as String)];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(selectedCategory == 'Overall' ? 'Set Overall Monthly Budget' : 'Set Category Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: targetOptions.contains(selectedCategory) ? selectedCategory : targetOptions.first,
                  decoration: const InputDecoration(labelText: 'Budget Scope / Category'),
                  items: targetOptions.map<DropdownMenuItem<String>>((name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name == 'Overall' ? 'Overall Monthly Budget' : name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) selectedCategory = val;
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Limit Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
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
              child: const Text('Save Allocation'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthSelector(BuildContext context, BudgetProvider budgetProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = budgetProvider.selectedMonth;
    final monthText = Formatters.formatMonthYear(selected);

    String cycleBadgeText = 'ACTIVE CYCLE';
    Color cycleBadgeColor = const Color(0xFF00B894);
    if (budgetProvider.isPastMonth) {
      cycleBadgeText = 'CLOSED CYCLE';
      cycleBadgeColor = Colors.blueGrey;
    } else if (budgetProvider.isFutureMonth) {
      cycleBadgeText = 'UPCOMING CYCLE';
      cycleBadgeColor = const Color(0xFF6C5CE7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  tooltip: 'Previous Month',
                  onPressed: () => budgetProvider.previousMonth(),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _showProfessionalMonthPicker(context, budgetProvider),
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
                    if (!budgetProvider.isCurrentMonth)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: TextButton.icon(
                          onPressed: () => budgetProvider.resetToCurrentMonth(),
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
                      onPressed: () => budgetProvider.nextMonth(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildQuickMonthSegmentBar(context, budgetProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickMonthSegmentBar(BuildContext context, BudgetProvider budgetProvider, bool isDark) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final prev = DateTime(now.year, now.month - 1, 1);
    final next = DateTime(now.year, now.month + 1, 1);

    final months = [prev, current, next];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: months.map((m) {
          final isSelected = budgetProvider.selectedMonth.year == m.year &&
              budgetProvider.selectedMonth.month == m.month;
          final isCurrentMonth = m.year == now.year && m.month == now.month;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => budgetProvider.setSelectedMonth(m),
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
                            'Select Budget Month',
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
                      final isSelected = tempYear == budgetProvider.selectedMonth.year &&
                          monthNumber == budgetProvider.selectedMonth.month;
                      final isCurrentMonth = tempYear == now.year && monthNumber == now.month;

                      return InkWell(
                        onTap: () {
                          budgetProvider.setSelectedMonth(DateTime(tempYear, monthNumber, 1));
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
                            budgetProvider.resetToCurrentMonth();
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

  Widget _buildCycleStatusBanner(BuildContext context, BudgetProvider budgetProvider) {
    final monthText = Formatters.formatMonthYear(budgetProvider.selectedMonth);

    if (budgetProvider.isCurrentMonth) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF00B894).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.published_with_changes_rounded, color: Color(0xFF00B894), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Active Month Cycle • Spending automatically resets to ₹0 when the new month starts while target limits carry over.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00B894)),
              ),
            ),
          ],
        ),
      );
    } else if (budgetProvider.isPastMonth) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.blueGrey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Closed Month ($monthText) • Showing historical spending against monthly limits.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upcoming_rounded, color: Color(0xFF6C5CE7), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upcoming Month ($monthText) • Fresh cycle ready with ₹0 spent.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showFreshMonthOptions(BuildContext context, BudgetProvider budgetProvider, double overallLimit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final monthStr = Formatters.formatMonthYear(budgetProvider.selectedMonth);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.published_with_changes_rounded, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 10),
                  Text(
                    'Budget Cycle Options ($monthStr)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'When a new month starts, spending automatically resets to ₹0 while your target limits carry over.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7)),
                title: const Text('Smart Auto-Allocate Budget'),
                subtitle: const Text('Re-calculate category limits based on custom % rules'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutoAllocateDialog(context, overallLimit > 0 ? overallLimit : 30000.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF00B894)),
                title: const Text('Renew Current Monthly Limits'),
                subtitle: const Text('Carry existing target limits into this month cycle'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Monthly budget limits confirmed for $monthStr!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFFF7675)),
                title: const Text('Clear All Category Allocations'),
                subtitle: const Text('Start with a blank slate for this month'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Clear All Allocations?'),
                      content: const Text('This will remove all category budget limits so you can configure a fresh budget setup.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Clear All'),
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
