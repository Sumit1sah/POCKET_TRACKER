import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_dashboard_screen.dart';
import '../expense_income/transaction_list_screen.dart';
import '../analytics/analytics_screen.dart';
import '../budget/budget_screen.dart';
import '../expense_income/add_edit_transaction_screen.dart';
import '../../services/local_storage_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Show the CC onboarding question once — right after first login.
    if (!LocalStorageService.isCCPreferenceSet()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCCOnboardingDialog();
      });
    }
  }

  /// Beautiful one-time dialog: "Do you have a credit card?"
  Future<void> _showCCOnboardingDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // must make a choice
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Do you have a\nCredit Card?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'We\'ll personalise your dashboard\nto track your card spending & limits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // YES button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await LocalStorageService.setCCPreference(true);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {}); // refresh home to show CC section
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 10),
                      Text('Yes, I have a credit card',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // NO button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: () async {
                    await LocalStorageService.setCCPreference(false);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {}); // refresh home to hide CC section
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 20, color: Colors.grey.shade500),
                      const SizedBox(width: 10),
                      Text('No, I don\'t have one',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Fine print
              Text(
                'You can change this anytime in Profile → Settings',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      HomeDashboardScreen(
        onSeeAll: () => setState(() => _currentIndex = 1),
      ),
      const TransactionListScreen(),
      const AnalyticsScreen(),
      const BudgetScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddEntryModal(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2E).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.88),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: BottomAppBar(
              color: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              height: 58,
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home')),
                  Expanded(child: _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History')),
                  const SizedBox(width: 48), // Notch space for FAB
                  Expanded(child: _buildNavItem(2, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Analytics')),
                  Expanded(child: _buildNavItem(3, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Budget')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Top Glowing Active Dot Indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 3,
            width: isSelected ? 16 : 0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.8),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF6C5CE7).withValues(alpha: isDark ? 0.35 : 0.15),
                              const Color(0xFF8E7CFE).withValues(alpha: isDark ? 0.25 : 0.08),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF6C5CE7))
                          : (isDark ? const Color(0xFFA0A0B8) : Colors.grey.shade500),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF6C5CE7))
                        : (isDark ? const Color(0xFFA0A0B8) : Colors.grey.shade500),
                    fontSize: isSelected ? 10 : 9.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: isSelected ? 0.2 : 0.0,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
