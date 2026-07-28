import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/transaction_notification.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final transactions = txProvider.filteredTransactions;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Collect available category names dynamically
    final Set<String> categoryNames = {'All'};
    for (final c in categoryProvider.categories) {
      categoryNames.add(c.name);
    }
    for (final t in txProvider.transactions) {
      if (t.category.isNotEmpty) {
        categoryNames.add(t.category);
      }
    }
    final categoriesList = categoryNames.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (txProvider.hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                txProvider.resetFilters();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset All', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF7675),
              ),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Advanced Filters',
                onPressed: () {
                  _showAdvancedFilterBottomSheet(context, categoriesList);
                },
              ),
              if (txProvider.hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${txProvider.activeFilterCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search merchant, category, notes, amount...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty || txProvider.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          txProvider.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => txProvider.setSearchQuery(val),
            ),
          ),

          // Active Filters Dismissible Pills Row
          if (txProvider.hasActiveFilters) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Type Pill
                  if (txProvider.typeFilter != TransactionTypeFilter.all)
                    _buildActiveFilterChip(
                      label: txProvider.typeFilter == TransactionTypeFilter.expense ? 'Expense Only' : 'Income Only',
                      icon: txProvider.typeFilter == TransactionTypeFilter.expense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: txProvider.typeFilter == TransactionTypeFilter.expense ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                      onDeleted: () => txProvider.setTypeFilter(TransactionTypeFilter.all),
                    ),

                  // Date Preset / Range Pill
                  if (txProvider.datePreset != DatePreset.allTime)
                    _buildActiveFilterChip(
                      label: _getDatePresetLabel(txProvider),
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF6C5CE7),
                      onDeleted: () => txProvider.setDatePreset(DatePreset.allTime),
                    ),

                  // Category Pill
                  if (txProvider.selectedCategoryFilter != 'All')
                    _buildActiveFilterChip(
                      label: 'Category: ${txProvider.selectedCategoryFilter}',
                      icon: Icons.category_rounded,
                      color: const Color(0xFF0984E3),
                      onDeleted: () => txProvider.setCategoryFilter('All'),
                    ),

                  // Payment Method Pill
                  if (txProvider.selectedPaymentMethodFilter != 'All')
                    _buildActiveFilterChip(
                      label: 'Payment: ${txProvider.selectedPaymentMethodFilter}',
                      icon: Icons.credit_card_rounded,
                      color: const Color(0xFF6C5CE7),
                      onDeleted: () => txProvider.setPaymentFilter('All'),
                    ),

                  // Amount Range Pill
                  if (txProvider.minAmount != null || txProvider.maxAmount != null)
                    _buildActiveFilterChip(
                      label: _getAmountRangeLabel(txProvider, currency),
                      icon: Icons.payments_outlined,
                      color: const Color(0xFFE67E22),
                      onDeleted: () => txProvider.setAmountRange(null, null),
                    ),

                  // Sort Order Pill
                  if (txProvider.sortOrder != TransactionSortOrder.newest)
                    _buildActiveFilterChip(
                      label: 'Sort: ${_getSortOrderLabel(txProvider.sortOrder)}',
                      icon: Icons.swap_vert_rounded,
                      color: const Color(0xFF8E44AD),
                      onDeleted: () => txProvider.setSortOrder(TransactionSortOrder.newest),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Quick Category Filter Bar
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categoriesList.length,
              itemBuilder: (context, index) {
                final catName = categoriesList[index];
                final isSelected = txProvider.selectedCategoryFilter == catName;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(catName),
                    selected: isSelected,
                    onSelected: (_) {
                      txProvider.setCategoryFilter(catName);
                    },
                    selectedColor: const Color(0xFF6C5CE7),
                    backgroundColor: isDark
                        ? const Color(0xFF2D2D44)
                        : const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade300 : const Color(0xFF2D3436)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF6C5CE7)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFF6C5CE7).withValues(alpha: 0.2)),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Results & Filtered Totals Summary Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${transactions.length} ${transactions.length == 1 ? 'transaction' : 'transactions'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (transactions.isNotEmpty)
                  Row(
                    children: [
                      if (txProvider.filteredTotalIncome > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B894).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+$currency${Formatters.formatCurrency(txProvider.filteredTotalIncome, symbol: '')}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00B894),
                            ),
                          ),
                        ),
                      if (txProvider.filteredTotalIncome > 0 && txProvider.filteredTotalExpense > 0)
                        const SizedBox(width: 6),
                      if (txProvider.filteredTotalExpense > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7675).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-$currency${Formatters.formatCurrency(txProvider.filteredTotalExpense, symbol: '')}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF7675),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Transaction List View
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 52, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No transactions match your active filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try tweaking your search, date, or category filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        if (txProvider.hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              txProvider.resetFilters();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset All Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 4, bottom: 90),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      return TransactionTile(
                        transaction: t,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditTransactionScreen(
                                isExpense: t.type == TransactionType.expense,
                                transactionToEdit: t,
                              ),
                            ),
                          );
                        },
                        onDelete: () {
                          final catName = t.category;
                          final amt = t.amount.toStringAsFixed(0);
                          txProvider.deleteTransaction(t.id);
                          TransactionNotification.show(
                            context,
                            title: 'Transaction Deleted',
                            amount: amt,
                            category: catName,
                            currency: currency,
                            type: TransactionNotificationType.deleted,
                            description: t.description.isNotEmpty
                                ? t.description
                                : t.paymentMethod,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 12, color: color),
        label: Text(label),
        deleteIcon: const Icon(Icons.close_rounded, size: 13),
        onDeleted: onDeleted,
        backgroundColor: color.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        deleteIconColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  String _getDatePresetLabel(TransactionProvider provider) {
    switch (provider.datePreset) {
      case DatePreset.today:
        return 'Today';
      case DatePreset.thisWeek:
        return 'This Week';
      case DatePreset.thisMonth:
        return 'This Month';
      case DatePreset.lastMonth:
        return 'Last Month';
      case DatePreset.custom:
        if (provider.selectedDateRange != null) {
          final start = Formatters.formatShortDate(provider.selectedDateRange!.start);
          final end = Formatters.formatShortDate(provider.selectedDateRange!.end);
          return '$start – $end';
        }
        return 'Custom Dates';
      default:
        return 'All Time';
    }
  }

  String _getAmountRangeLabel(TransactionProvider provider, String currency) {
    if (provider.minAmount != null && provider.maxAmount != null) {
      return '$currency${provider.minAmount!.toStringAsFixed(0)}–$currency${provider.maxAmount!.toStringAsFixed(0)}';
    } else if (provider.minAmount != null) {
      return '> $currency${provider.minAmount!.toStringAsFixed(0)}';
    } else if (provider.maxAmount != null) {
      return '< $currency${provider.maxAmount!.toStringAsFixed(0)}';
    }
    return 'Amount';
  }

  String _getSortOrderLabel(TransactionSortOrder order) {
    switch (order) {
      case TransactionSortOrder.newest:
        return 'Newest';
      case TransactionSortOrder.oldest:
        return 'Oldest';
      case TransactionSortOrder.amountHighToLow:
        return 'Highest Amount';
      case TransactionSortOrder.amountLowToHigh:
        return 'Lowest Amount';
    }
  }

  void _showAdvancedFilterBottomSheet(BuildContext context, List<String> categories) {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currency = Provider.of<ThemeCurrencyProvider>(context, listen: false).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minController = TextEditingController(
      text: txProvider.minAmount != null ? txProvider.minAmount!.toStringAsFixed(0) : '',
    );
    final maxController = TextEditingController(
      text: txProvider.maxAmount != null ? txProvider.maxAmount!.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.84,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Modal Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Color(0xFF6C5CE7)),
                          const SizedBox(width: 8),
                          const Text(
                            'Advanced Filters',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (txProvider.hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${txProvider.activeFilterCount} active',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          txProvider.resetFilters();
                          minController.clear();
                          maxController.clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All', style: TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. TRANSACTION TYPE (All / Expense / Income)
                          const SizedBox(height: 8),
                          const Text('Transaction Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTypeChip('All Types', TransactionTypeFilter.all, txProvider.typeFilter, (t) {
                                setModalState(() => txProvider.setTypeFilter(t));
                              }),
                              const SizedBox(width: 8),
                              _buildTypeChip('Expenses Only', TransactionTypeFilter.expense, txProvider.typeFilter, (t) {
                                setModalState(() => txProvider.setTypeFilter(t));
                              }),
                              const SizedBox(width: 8),
                              _buildTypeChip('Income Only', TransactionTypeFilter.income, txProvider.typeFilter, (t) {
                                setModalState(() => txProvider.setTypeFilter(t));
                              }),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 2. SORT ORDER
                          const Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildSortBadge('Newest First', TransactionSortOrder.newest, txProvider.sortOrder, (s) {
                                setModalState(() => txProvider.setSortOrder(s));
                              }),
                              _buildSortBadge('Oldest First', TransactionSortOrder.oldest, txProvider.sortOrder, (s) {
                                setModalState(() => txProvider.setSortOrder(s));
                              }),
                              _buildSortBadge('Highest Amount', TransactionSortOrder.amountHighToLow, txProvider.sortOrder, (s) {
                                setModalState(() => txProvider.setSortOrder(s));
                              }),
                              _buildSortBadge('Lowest Amount', TransactionSortOrder.amountLowToHigh, txProvider.sortOrder, (s) {
                                setModalState(() => txProvider.setSortOrder(s));
                              }),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 3. DATE PRESETS & CUSTOM RANGE
                          const Text('Time Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDatePresetChip('All Time', DatePreset.allTime, txProvider.datePreset, () {
                                setModalState(() => txProvider.setDatePreset(DatePreset.allTime));
                              }),
                              _buildDatePresetChip('Today', DatePreset.today, txProvider.datePreset, () {
                                setModalState(() => txProvider.setDatePreset(DatePreset.today));
                              }),
                              _buildDatePresetChip('This Week', DatePreset.thisWeek, txProvider.datePreset, () {
                                setModalState(() => txProvider.setDatePreset(DatePreset.thisWeek));
                              }),
                              _buildDatePresetChip('This Month', DatePreset.thisMonth, txProvider.datePreset, () {
                                setModalState(() => txProvider.setDatePreset(DatePreset.thisMonth));
                              }),
                              _buildDatePresetChip('Last Month', DatePreset.lastMonth, txProvider.datePreset, () {
                                setModalState(() => txProvider.setDatePreset(DatePreset.lastMonth));
                              }),
                              ActionChip(
                                avatar: const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF6C5CE7)),
                                label: Text(
                                  txProvider.datePreset == DatePreset.custom && txProvider.selectedDateRange != null
                                      ? '${Formatters.formatShortDate(txProvider.selectedDateRange!.start)} – ${Formatters.formatShortDate(txProvider.selectedDateRange!.end)}'
                                      : 'Custom Date Range',
                                ),
                                onPressed: () async {
                                  final range = await showDateRangePicker(
                                    context: context,
                                    initialDateRange: txProvider.selectedDateRange ?? DateTimeRange(
                                      start: DateTime.now().subtract(const Duration(days: 30)),
                                      end: DateTime.now(),
                                    ),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (range != null) {
                                    setModalState(() {
                                      txProvider.setDatePreset(DatePreset.custom, customRange: range);
                                    });
                                  }
                                },
                                backgroundColor: txProvider.datePreset == DatePreset.custom
                                    ? const Color(0xFF6C5CE7)
                                    : const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: txProvider.datePreset == DatePreset.custom ? FontWeight.bold : FontWeight.w500,
                                  color: txProvider.datePreset == DatePreset.custom ? Colors.white : const Color(0xFF6C5CE7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 4. AMOUNT RANGE PRESETS & INPUTS
                          const Text('Amount Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildAmountPresetChip('All Amounts', null, null, txProvider, setModalState, minController, maxController),
                              _buildAmountPresetChip('< ${currency}500', null, 500, txProvider, setModalState, minController, maxController),
                              _buildAmountPresetChip('${currency}500 – ${currency}2,000', 500, 2000, txProvider, setModalState, minController, maxController),
                              _buildAmountPresetChip('${currency}2,000 – ${currency}10,000', 2000, 10000, txProvider, setModalState, minController, maxController),
                              _buildAmountPresetChip('${currency}10,000+', 10000, null, txProvider, setModalState, minController, maxController),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Min Amount ($currency)',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (val) {
                                    final min = double.tryParse(val.trim());
                                    setModalState(() {
                                      txProvider.setAmountRange(min, txProvider.maxAmount);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: maxController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Max Amount ($currency)',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (val) {
                                    final max = double.tryParse(val.trim());
                                    setModalState(() {
                                      txProvider.setAmountRange(txProvider.minAmount, max);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 5. CATEGORY FILTER
                          const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((cat) {
                              final isSelected = txProvider.selectedCategoryFilter == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (val) {
                                  setModalState(() {
                                    txProvider.setCategoryFilter(val ? cat : 'All');
                                  });
                                },
                                selectedColor: const Color(0xFF6C5CE7),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // 6. PAYMENT METHOD FILTER
                          const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['All', 'UPI', 'Credit Card', 'Bank Transfer', 'Cash', 'Debit Card', 'PayPal', 'Wallet'].map((pm) {
                              final isSelected = txProvider.selectedPaymentMethodFilter == pm;
                              return ChoiceChip(
                                label: Text(pm),
                                selected: isSelected,
                                onSelected: (val) {
                                  setModalState(() {
                                    txProvider.setPaymentFilter(val ? pm : 'All');
                                  });
                                },
                                selectedColor: const Color(0xFF6C5CE7),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Apply Filters Button
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Apply Filters (${txProvider.filteredTransactions.length} results)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeChip(
    String label,
    TransactionTypeFilter target,
    TransactionTypeFilter current,
    Function(TransactionTypeFilter) onSelect,
  ) {
    final isSel = target == current;
    Color color = const Color(0xFF6C5CE7);
    if (target == TransactionTypeFilter.expense) color = const Color(0xFFFF7675);
    if (target == TransactionTypeFilter.income) color = const Color(0xFF00B894);

    return Expanded(
      child: InkWell(
        onTap: () => onSelect(target),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? color : color.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSel ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBadge(
    String label,
    TransactionSortOrder target,
    TransactionSortOrder current,
    Function(TransactionSortOrder) onSelect,
  ) {
    final isSel = target == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => onSelect(target),
      selectedColor: const Color(0xFF6C5CE7),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSel ? Colors.white : Colors.black87,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildDatePresetChip(
    String label,
    DatePreset target,
    DatePreset current,
    VoidCallback onSelect,
  ) {
    final isSel = target == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => onSelect(),
      selectedColor: const Color(0xFF6C5CE7),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSel ? Colors.white : Colors.black87,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAmountPresetChip(
    String label,
    double? min,
    double? max,
    TransactionProvider txProvider,
    StateSetter setModalState,
    TextEditingController minCtrl,
    TextEditingController maxCtrl,
  ) {
    final isSel = txProvider.minAmount == min && txProvider.maxAmount == max;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) {
        setModalState(() {
          txProvider.setAmountRange(min, max);
          minCtrl.text = min != null ? min.toStringAsFixed(0) : '';
          maxCtrl.text = max != null ? max.toStringAsFixed(0) : '';
        });
      },
      selectedColor: const Color(0xFFE67E22),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSel ? Colors.white : Colors.black87,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
