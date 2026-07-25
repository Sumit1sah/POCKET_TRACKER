import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../widgets/balance_summary_card.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/transaction_notification.dart';
import '../authentication/login_screen.dart';
import '../profile/profile_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const HomeDashboardScreen({super.key, this.onSeeAll});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final recentTransactions = txProvider.transactions.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeString = DateFormat('hh:mm:ss a').format(_now);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Header with Time & Notifications
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              authProvider.currentUser?.name.characters.first.toUpperCase() ?? 'P',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              authProvider.currentUser?.name ?? 'User',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Real-Time Local Device Clock Badge (Time only)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
                          : const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          size: 13,
                          color: Color(0xFF6C5CE7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C5CE7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications up to date!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Logout Account',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Logout Account'),
                            ],
                          ),
                          content: const Text('Are you sure you want to log out of Pocketify?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                final auth = Provider.of<AuthProvider>(context, listen: false);
                                await auth.logout();
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              child: const Text('Logout', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Unified Net Balance & Monthly Budget Card
              const BalanceSummaryCard(),
              const SizedBox(height: 16),

              // AI Spending Insight Card
              const AIInsightCard(),
              const SizedBox(height: 20),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.onSeeAll != null) {
                        widget.onSeeAll!();
                      }
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'No transactions recorded yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...recentTransactions.map(
                  (t) => TransactionTile(
                    transaction: t,
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
