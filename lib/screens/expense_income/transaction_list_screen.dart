import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/theme_currency_provider.dart';
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
    final transactions = txProvider.filteredTransactions;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Collect all available categories dynamically from CategoryProvider + user transactions
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
              label: const Text('Reset', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF7675),
              ),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: () {
                  _showFilterBottomSheet(context, categoriesList);
                },
              ),
              if (txProvider.hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search category, note, amount...',
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

          // Horizontal Category Filter Bar
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categoriesList.length,
              itemBuilder: (context, index) {
                final catName = categoriesList[index];
                final isSelected = txProvider.selectedCategoryFilter == catName;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (catName != 'All') ...[
                          Icon(
                            _getCategoryIcon(catName),
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade300 : const Color(0xFF6C5CE7)),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(catName),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      txProvider.setCategoryFilter(catName);
                    },
                    selectedColor: const Color(0xFF6C5CE7),
                    backgroundColor: isDark
                        ? const Color(0xFF2D2D44)
                        : const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade300 : const Color(0xFF2D3436)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 8),

          // Results summary header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${transactions.length} ${transactions.length == 1 ? 'transaction' : 'transactions'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (txProvider.selectedCategoryFilter != 'All')
                  GestureDetector(
                    onTap: () => txProvider.setCategoryFilter('All'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Category: ${txProvider.selectedCategoryFilter}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 12, color: Color(0xFF6C5CE7)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          txProvider.selectedCategoryFilter != 'All'
                              ? 'No transactions found under "${txProvider.selectedCategoryFilter}".'
                              : 'No transactions match your query.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        if (txProvider.hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              txProvider.resetFilters();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 8, bottom: 90),
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
                          final currency = Provider.of<ThemeCurrencyProvider>(
                            context,
                            listen: false,
                          ).currency;
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

  static IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'salary':
      case 'income':
        return Icons.account_balance_wallet_rounded;
      case 'transport':
      case 'fuel':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'debt / repayment':
      case 'emi':
        return Icons.credit_score_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _showFilterBottomSheet(BuildContext context, List<String> categories) {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          txProvider.resetFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All', style: TextStyle(color: Color(0xFFFF7675))),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Filter by Category Header
                  const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Filter by Payment Method Header
                  const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'UPI', 'Credit Card', 'Bank Transfer', 'Cash'].map((pm) {
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
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
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
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
}
