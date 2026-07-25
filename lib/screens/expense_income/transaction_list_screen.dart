import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/transaction_notification.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final transactions = txProvider.filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by category, note, amount...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => txProvider.setSearchQuery(val),
            ),
          ),

          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No transactions match your query.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
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
                            description: t.description.isNotEmpty ? t.description : t.paymentMethod,
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

  void _showFilterBottomSheet(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  txProvider.resetFilters();
                  Navigator.pop(context);
                },
                child: const Text('Reset All Filters'),
              ),
            ],
          ),
        );
      },
    );
  }
}
