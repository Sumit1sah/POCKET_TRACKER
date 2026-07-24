import 'package:flutter/material.dart';
import 'home_dashboard_screen.dart';
import '../expense_income/transaction_list_screen.dart';
import '../analytics/analytics_screen.dart';
import '../budget/budget_screen.dart';
import '../profile/profile_screen.dart';
import '../expense_income/add_edit_transaction_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeDashboardScreen(),
    TransactionListScreen(),
    AnalyticsScreen(),
    BudgetScreen(),
    ProfileScreen(),
  ];

  void _showAddEntryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF7675)),
                ),
                title: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Log money spent on food, bills, shopping...'),
                onTap: () {
                  Navigator.pop(modalContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditTransactionScreen(isExpense: true),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Color(0xFF00B894)),
                ),
                title: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Log money received from salary, freelance...'),
                onTap: () {
                  Navigator.pop(modalContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditTransactionScreen(isExpense: false),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryModal(context),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 10,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Home')),
            Expanded(child: _buildNavItem(1, Icons.receipt_long_rounded, 'History')),
            const SizedBox(width: 48), // Space for floating center FAB
            Expanded(child: _buildNavItem(2, Icons.pie_chart_rounded, 'Analytics')),
            Expanded(child: _buildNavItem(3, Icons.account_balance_wallet_rounded, 'Budget')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
