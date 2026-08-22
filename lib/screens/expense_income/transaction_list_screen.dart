import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../widgets/transaction_notification.dart';
import '../../widgets/category_icon_widget.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _summaryAnim;
  late Animation<double> _summaryFade;

  @override
  void initState() {
    super.initState();
    _summaryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _summaryFade = CurvedAnimation(parent: _summaryAnim, curve: Curves.easeOut);
    _summaryAnim.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _summaryAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = txProvider.filteredTransactions;
    final grouped = _groupByDate(transactions);

    final Set<String> catNames = {'All'};
    for (final c in catProvider.categories) {
      catNames.add(c.name);
    }
    for (final t in txProvider.transactions) {
      if (t.category.isNotEmpty) catNames.add(t.category);
    }
    final categoriesList = catNames.toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F2FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildSliverAppBar(context, txProvider, currency, isDark, categoriesList),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _summaryFade,
              child: _buildSummaryBanner(context, txProvider, currency, isDark, transactions),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTypeToggle(txProvider, isDark),
          ),
          if (txProvider.hasActiveFilters)
            SliverToBoxAdapter(
              child: _buildActiveFilterRow(txProvider, currency),
            ),
          SliverToBoxAdapter(
            child: _buildCategoryBar(txProvider, catProvider, isDark),
          ),
          if (transactions.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(txProvider),
            )
          else ...[
            for (final entry in grouped.entries) ...[
              SliverToBoxAdapter(
                child: _buildDayHeader(context, entry.key, entry.value, currency, isDark),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = entry.value[index];
                    return _buildSwipeableTile(context, t, txProvider, catProvider, currency, isDark);
                  },
                  childCount: entry.value.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    TransactionProvider txProvider,
    String currency,
    bool isDark,
    List<String> categoriesList,
  ) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F2FF),
      elevation: 0,
      title: const Text(
        'Transaction History',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search merchant, category, amount...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty || txProvider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        txProvider.setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: txProvider.setSearchQuery,
          ),
        ),
      ),
      actions: [
        if (txProvider.hasActiveFilters)
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              txProvider.resetFilters();
            },
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Reset', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF7675)),
          ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Filters',
              onPressed: () => _showAdvancedFilterSheet(context, categoriesList),
            ),
            if (txProvider.hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C5CE7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${txProvider.activeFilterCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context,
    TransactionProvider txProvider,
    String currency,
    bool isDark,
    List<TransactionModel> transactions,
  ) {
    final income = txProvider.filteredTotalIncome;
    final expense = txProvider.filteredTotalExpense;
    final net = income - expense;
    final count = transactions.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8E54E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCell(
              '$count',
              'Entries',
              Icons.receipt_long_rounded,
              Colors.white.withValues(alpha: 0.85),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _summaryCell(
              '+$currency${Formatters.formatCurrency(income, symbol: "")}',
              'Income',
              Icons.arrow_downward_rounded,
              const Color(0xFF55EFC4),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _summaryCell(
              '-$currency${Formatters.formatCurrency(expense, symbol: "")}',
              'Expense',
              Icons.arrow_upward_rounded,
              const Color(0xFFFF7675),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _summaryCell(
              '${net >= 0 ? "+" : ""}$currency${Formatters.formatCurrency(net.abs(), symbol: "")}',
              'Net',
              net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              net >= 0 ? const Color(0xFF55EFC4) : const Color(0xFFFF7675),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTypeToggle(TransactionProvider txProvider, bool isDark) {
    final options = [
      (TransactionTypeFilter.all, 'All', Icons.swap_vert_rounded),
      (TransactionTypeFilter.income, 'Income', Icons.arrow_downward_rounded),
      (TransactionTypeFilter.expense, 'Expense', Icons.arrow_upward_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: options.map((opt) {
            final isSelected = txProvider.typeFilter == opt.$1;
            final color = opt.$1 == TransactionTypeFilter.income
                ? const Color(0xFF00B894)
                : opt.$1 == TransactionTypeFilter.expense
                    ? const Color(0xFFFF7675)
                    : const Color(0xFF6C5CE7);
            return Expanded(
              child: GestureDetector(
                onTap: () => txProvider.setTypeFilter(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt.$3,
                        size: 14,
                        color: isSelected ? Colors.white : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(
    TransactionProvider txProvider,
    CategoryProvider catProvider,
    bool isDark,
  ) {
    final Set<String> catNames = {'All'};
    for (final c in catProvider.categories) {
      catNames.add(c.name);
    }
    for (final t in txProvider.transactions) {
      if (t.category.isNotEmpty) catNames.add(t.category);
    }
    final list = catNames.toList();

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final name = list[i];
          final isSelected = txProvider.selectedCategoryFilter == name;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade300 : const Color(0xFF2D3436)),
                ),
              ),
              selected: isSelected,
              onSelected: (_) => txProvider.setCategoryFilter(name),
              selectedColor: const Color(0xFF6C5CE7),
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _buildActiveFilterRow(TransactionProvider txProvider, String currency) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (txProvider.datePreset != DatePreset.allTime)
            _filterPill(
              _dateLabel(txProvider),
              Icons.calendar_month_rounded,
              const Color(0xFF6C5CE7),
              () => txProvider.setDatePreset(DatePreset.allTime),
            ),
          if (txProvider.selectedPaymentMethodFilter != 'All')
            _filterPill(
              txProvider.selectedPaymentMethodFilter,
              Icons.credit_card_rounded,
              const Color(0xFF0984E3),
              () => txProvider.setPaymentFilter('All'),
            ),
          if (txProvider.minAmount != null || txProvider.maxAmount != null)
            _filterPill(
              _amountLabel(txProvider, currency),
              Icons.payments_outlined,
              const Color(0xFFE67E22),
              () => txProvider.setAmountRange(null, null),
            ),
          if (txProvider.sortOrder != TransactionSortOrder.newest)
            _filterPill(
              _sortLabel(txProvider.sortOrder),
              Icons.swap_vert_rounded,
              const Color(0xFF8E44AD),
              () => txProvider.setSortOrder(TransactionSortOrder.newest),
            ),
        ],
      ),
    );
  }

  Widget _filterPill(String label, IconData icon, Color color, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 11, color: color),
        label: Text(label),
        deleteIcon: const Icon(Icons.close_rounded, size: 12),
        onDeleted: onDelete,
        backgroundColor: color.withValues(alpha: 0.1),
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        deleteIconColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    String dayKey,
    List<TransactionModel> dayTxs,
    String currency,
    bool isDark,
  ) {
    final dayIncome = dayTxs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.amount);
    final dayExpense = dayTxs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E34) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              dayKey,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF6C5CE7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06))),
          const SizedBox(width: 8),
          if (dayIncome > 0)
            Text(
              '+$currency${Formatters.formatCurrency(dayIncome, symbol: "")}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00B894)),
            ),
          if (dayIncome > 0 && dayExpense > 0) const SizedBox(width: 4),
          if (dayExpense > 0)
            Text(
              '-$currency${Formatters.formatCurrency(dayExpense, symbol: "")}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF7675)),
            ),
        ],
      ),
    );
  }

  Widget _buildSwipeableTile(
    BuildContext context,
    TransactionModel t,
    TransactionProvider txProvider,
    CategoryProvider catProvider,
    String currency,
    bool isDark,
  ) {
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF7675),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await _confirmDelete(context);
      },
      onDismissed: (_) {
        final catName = t.category;
        final amt = t.amount % 1 == 0 ? t.amount.toInt().toString() : t.amount.toString();
        txProvider.deleteTransaction(t.id);
        TransactionNotification.show(
          context,
          title: 'Transaction Deleted',
          amount: amt,
          category: catName,
          currency: currency,
          type: TransactionNotificationType.deleted,
          description: t.description.isNotEmpty ? t.description : t.paymentMethod,
        );
      },
      child: _buildAdvancedTile(context, t, txProvider, catProvider, currency, isDark),
    );
  }

  Widget _buildAdvancedTile(
    BuildContext context,
    TransactionModel t,
    TransactionProvider txProvider,
    CategoryProvider catProvider,
    String currency,
    bool isDark,
  ) {
    final allCats = catProvider.categories.isNotEmpty
        ? catProvider.categories
        : AppConstants.defaultCategories;
    final catMatch = allCats.firstWhere(
      (c) => c.name.toLowerCase() == t.category.toLowerCase(),
      orElse: () => allCats.first,
    );

    final isIncome = t.type == TransactionType.income;
    final amountColor = isIncome ? const Color(0xFF00B894) : const Color(0xFFFF7675);
    final sign = isIncome ? '+' : '-';

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, t, txProvider, currency),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141428) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: amountColor.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditTransactionScreen(
                  isExpense: t.type == TransactionType.expense,
                  transactionToEdit: t,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 52,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: amountColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  CategoryIconWidget(
                    category: catMatch,
                    size: 44,
                    iconSize: 20,
                    showTypeBadge: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      t.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (t.isRecurring) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        '↻',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF6C5CE7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$sign ${Formatters.formatCurrency(t.amount, symbol: currency)}',
                              style: TextStyle(
                                color: amountColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        if (t.description.isNotEmpty &&
                            t.description.trim().toLowerCase() != t.category.trim().toLowerCase()) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 11, color: const Color(0xFF6C5CE7).withValues(alpha: 0.85)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  t.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (t.notes != null && t.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 10, color: const Color(0xFF6C5CE7).withValues(alpha: 0.8)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  t.notes!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (t.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: t.tags.take(3).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6C5CE7),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _pmBadge(t.paymentMethod, isDark),
                            const SizedBox(width: 6),
                            _bankBadge(t),
                            if (t.receiptPath != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B894).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, size: 10, color: Color(0xFF00B894)),
                              ),
                            ],
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 10,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                                const SizedBox(width: 3),
                                Text(
                                  Formatters.formatShortDateTime(t.date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pmBadge(String method, bool isDark) {
    final isCC = method == 'Credit Card';
    final isUPI = method == 'UPI';
    final color = isCC
        ? const Color(0xFF6C5CE7)
        : isUPI
            ? const Color(0xFF0984E3)
            : (isDark ? Colors.white38 : Colors.grey.shade600);

    final icon = isCC
        ? Icons.credit_card_rounded
        : isUPI
            ? Icons.qr_code_scanner_rounded
            : method == 'Cash'
                ? Icons.money_rounded
                : method == 'Bank Transfer'
                    ? Icons.account_balance_rounded
                    : Icons.account_balance_wallet_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            method,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _bankBadge(TransactionModel t) {
    final descLower = t.description.toLowerCase();
    const banks = [
      'HDFC', 'SBI', 'ICICI', 'Axis', 'Kotak', 'PNB',
      'Bank of Baroda', 'BOB', 'IndusInd', 'Yes Bank', 'Federal Bank',
      'RBL Bank', 'IDFC', 'Bandhan', 'AU Small', 'Canara', 'Union Bank',
    ];
    String? bankName;
    for (final b in banks) {
      if (descLower.contains(b.toLowerCase())) {
        bankName = b;
        break;
      }
    }
    final cardMatch = RegExp(r'[•\*]{1,4}(\d{4})').firstMatch(t.description);
    final cardDigits = cardMatch != null ? '••${cardMatch.group(1)}' : null;

    if (bankName == null && cardDigits == null) return const SizedBox.shrink();

    final displayText = bankName != null && cardDigits != null
        ? '$bankName $cardDigits'
        : (bankName ?? cardDigits!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00CEC9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_rounded, size: 9, color: Color(0xFF00838F)),
          const SizedBox(width: 3),
          Text(
            displayText,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF00838F)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    TransactionModel t,
    TransactionProvider txProvider,
    String currency,
  ) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = t.type == TransactionType.income;
    final amountColor = isIncome ? const Color(0xFF00B894) : const Color(0xFFFF7675);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t.category,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: amountColor),
                  ),
                ),
                const Spacer(),
                Text(
                  '${isIncome ? "+" : "-"}$currency${Formatters.formatCurrency(t.amount, symbol: "")}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: amountColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _ctxAction(context, Icons.edit_rounded, 'Edit Transaction', const Color(0xFF6C5CE7), () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditTransactionScreen(
                    isExpense: t.type == TransactionType.expense,
                    transactionToEdit: t,
                  ),
                ),
              );
            }),
            _ctxAction(context, Icons.copy_rounded, 'Copy Amount', const Color(0xFF0984E3), () {
              Clipboard.setData(ClipboardData(text: t.amount.toStringAsFixed(2)));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Amount copied to clipboard!'), behavior: SnackBarBehavior.floating),
              );
            }),
            _ctxAction(context, Icons.content_copy_rounded, 'Duplicate Entry', const Color(0xFF00B894), () {
              Navigator.pop(context);
              _duplicateTransaction(context, t, txProvider, currency);
            }),
            const Divider(),
            _ctxAction(context, Icons.delete_rounded, 'Delete', const Color(0xFFFF7675), () async {
              Navigator.pop(context);
              final confirm = await _confirmDelete(context);
              if (confirm == true && context.mounted) {
                txProvider.deleteTransaction(t.id);
                TransactionNotification.show(
                  context,
                  title: 'Deleted',
                  amount: t.amount % 1 == 0 ? t.amount.toInt().toString() : t.amount.toString(),
                  category: t.category,
                  currency: currency,
                  type: TransactionNotificationType.deleted,
                  description: t.description,
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _ctxAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
      onTap: onTap,
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7675),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateTransaction(
    BuildContext context,
    TransactionModel t,
    TransactionProvider txProvider,
    String currency,
  ) {
    final newTx = TransactionModel(
      id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
      uid: t.uid,
      type: t.type,
      amount: t.amount,
      category: t.category,
      paymentMethod: t.paymentMethod,
      description: '${t.description} (copy)',
      date: DateTime.now(),
      isRecurring: t.isRecurring,
    );
    txProvider.addTransaction(newTx);
    TransactionNotification.show(
      context,
      title: 'Entry Duplicated',
      amount: t.amount % 1 == 0 ? t.amount.toInt().toString() : t.amount.toString(),
      category: t.category,
      currency: currency,
      type: t.type == TransactionType.income
          ? TransactionNotificationType.income
          : TransactionNotificationType.expense,
      description: 'Added as new entry for today',
    );
  }

  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<TransactionModel>> grouped = {};
    for (final t in txs) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final String key;
      if (d == today) {
        key = 'Today';
      } else if (d == yesterday) {
        key = 'Yesterday';
      } else {
        key = Formatters.formatShortDate(t.date);
      }
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  }

  Widget _buildEmptyState(TransactionProvider txProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 38, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          if (txProvider.hasActiveFilters) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _searchController.clear();
                txProvider.resetFilters();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(TransactionProvider p) {
    switch (p.datePreset) {
      case DatePreset.today:
        return 'Today';
      case DatePreset.thisWeek:
        return 'This Week';
      case DatePreset.thisMonth:
        return 'This Month';
      case DatePreset.lastMonth:
        return 'Last Month';
      case DatePreset.custom:
        if (p.selectedDateRange != null) {
          return '${Formatters.formatShortDate(p.selectedDateRange!.start)} - ${Formatters.formatShortDate(p.selectedDateRange!.end)}';
        }
        return 'Custom';
      default:
        return 'All Time';
    }
  }

  String _amountLabel(TransactionProvider p, String cur) {
    if (p.minAmount != null && p.maxAmount != null) {
      return '$cur${p.minAmount!.toInt()}-$cur${p.maxAmount!.toInt()}';
    } else if (p.minAmount != null) {
      return '> $cur${p.minAmount!.toInt()}';
    } else {
      return '< $cur${p.maxAmount!.toInt()}';
    }
  }

  String _sortLabel(TransactionSortOrder o) {
    switch (o) {
      case TransactionSortOrder.oldest:
        return 'Oldest First';
      case TransactionSortOrder.amountHighToLow:
        return 'Highest First';
      case TransactionSortOrder.amountLowToHigh:
        return 'Lowest First';
      default:
        return 'Newest First';
    }
  }

  void _showAdvancedFilterSheet(BuildContext context, List<String> categories) {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currency = Provider.of<ThemeCurrencyProvider>(context, listen: false).currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minCtrl = TextEditingController(
      text: txProvider.minAmount != null
          ? (txProvider.minAmount! % 1 == 0
              ? txProvider.minAmount!.toInt().toString()
              : txProvider.minAmount!.toString())
          : '',
    );
    final maxCtrl = TextEditingController(
      text: txProvider.maxAmount != null
          ? (txProvider.maxAmount! % 1 == 0
              ? txProvider.maxAmount!.toInt().toString()
              : txProvider.maxAmount!.toString())
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          height: MediaQuery.of(context).size.height * 0.86,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 8),
                  const Text('Filters & Sort', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  if (txProvider.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${txProvider.activeFilterCount} active',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      txProvider.resetFilters();
                      minCtrl.clear();
                      maxCtrl.clear();
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
                      _sec('Sort By'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _sChip(set, txProvider, 'Newest First', TransactionSortOrder.newest),
                          _sChip(set, txProvider, 'Oldest First', TransactionSortOrder.oldest),
                          _sChip(set, txProvider, 'Highest Amount', TransactionSortOrder.amountHighToLow),
                          _sChip(set, txProvider, 'Lowest Amount', TransactionSortOrder.amountLowToHigh),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sec('Time Period'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dChip(set, txProvider, 'All Time', DatePreset.allTime),
                          _dChip(set, txProvider, 'Today', DatePreset.today),
                          _dChip(set, txProvider, 'This Week', DatePreset.thisWeek),
                          _dChip(set, txProvider, 'This Month', DatePreset.thisMonth),
                          _dChip(set, txProvider, 'Last Month', DatePreset.lastMonth),
                          ActionChip(
                            avatar: const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFF6C5CE7)),
                            label: Text(
                              txProvider.datePreset == DatePreset.custom && txProvider.selectedDateRange != null
                                  ? '${Formatters.formatShortDate(txProvider.selectedDateRange!.start)} - ${Formatters.formatShortDate(txProvider.selectedDateRange!.end)}'
                                  : 'Custom Range',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: txProvider.datePreset == DatePreset.custom ? FontWeight.bold : FontWeight.w500,
                                color: txProvider.datePreset == DatePreset.custom ? Colors.white : const Color(0xFF6C5CE7),
                              ),
                            ),
                            backgroundColor: txProvider.datePreset == DatePreset.custom
                                ? const Color(0xFF6C5CE7)
                                : const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                initialDateRange: txProvider.selectedDateRange ??
                                    DateTimeRange(
                                      start: DateTime.now().subtract(const Duration(days: 30)),
                                      end: DateTime.now(),
                                    ),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (range != null) {
                                set(() => txProvider.setDatePreset(DatePreset.custom, customRange: range));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sec('Amount Range'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _aChip(set, txProvider, 'All', null, null, currency),
                          _aChip(set, txProvider, '< $currency 500', null, 500, currency),
                          _aChip(set, txProvider, '$currency 500 - 2K', 500, 2000, currency),
                          _aChip(set, txProvider, '$currency 2K - 10K', 2000, 10000, currency),
                          _aChip(set, txProvider, '$currency 10K+', 10000, null, currency),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min ($currency)',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) {
                                final min = double.tryParse(v.trim());
                                set(() => txProvider.setAmountRange(min, txProvider.maxAmount));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max ($currency)',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) {
                                final max = double.tryParse(v.trim());
                                set(() => txProvider.setAmountRange(txProvider.minAmount, max));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sec('Category'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final isSel = txProvider.selectedCategoryFilter == cat;
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                            selected: isSel,
                            onSelected: (v) => set(() => txProvider.setCategoryFilter(v ? cat : 'All')),
                            selectedColor: const Color(0xFF6C5CE7),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      _sec('Payment Method'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['All', 'UPI', 'Credit Card', 'Bank Transfer', 'Cash', 'Debit Card', 'PayPal', 'Wallet'].map((pm) {
                          final isSel = txProvider.selectedPaymentMethodFilter == pm;
                          return ChoiceChip(
                            label: Text(pm, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                            selected: isSel,
                            onSelected: (v) => set(() => txProvider.setPaymentFilter(v ? pm : 'All')),
                            selectedColor: const Color(0xFF6C5CE7),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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
                    'Show ${txProvider.filteredTransactions.length} Results',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sec(String l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  Widget _sChip(StateSetter set, TransactionProvider p, String l, TransactionSortOrder o) {
    final isSel = p.sortOrder == o;
    return ChoiceChip(
      label: Text(l, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
      selected: isSel,
      onSelected: (_) => set(() => p.setSortOrder(o)),
      selectedColor: const Color(0xFF6C5CE7),
    );
  }

  Widget _dChip(StateSetter set, TransactionProvider p, String l, DatePreset dp) {
    final isSel = p.datePreset == dp;
    return ChoiceChip(
      label: Text(l, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
      selected: isSel,
      onSelected: (_) => set(() => p.setDatePreset(dp)),
      selectedColor: const Color(0xFF6C5CE7),
    );
  }

  Widget _aChip(StateSetter set, TransactionProvider p, String l, double? min, double? max, String cur) {
    final isSel = p.minAmount == min && p.maxAmount == max;
    return ChoiceChip(
      label: Text(l, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
      selected: isSel,
      onSelected: (_) => set(() => p.setAmountRange(min, max)),
      selectedColor: const Color(0xFF6C5CE7),
    );
  }
}
