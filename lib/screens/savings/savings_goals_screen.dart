import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../models/savings_goal_model.dart';
import '../../utils/formatters.dart';

class SavingsGoalsScreen extends StatelessWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final savingsProvider = Provider.of<SavingsProvider>(context);
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final goals = savingsProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddGoalDialog(context),
          ),
        ],
      ),
      body: goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No savings goals set yet.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddGoalDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Goal'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final pct = (goal.progressPercentage * 100).round();

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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: goal.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(goal.iconData, color: goal.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Target: ${Formatters.formatCurrency(goal.targetAmount, symbol: currency)}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: goal.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saved: ${Formatters.formatCurrency(goal.savedAmount, symbol: currency)}'),
                            ElevatedButton(
                              onPressed: () => _showDepositDialog(context, goal),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: goal.color,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Deposit', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: goal.progressPercentage,
                            minHeight: 10,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Savings Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Goal Title (e.g. New Laptop)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target Amount'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final target = double.tryParse(targetController.text);
                if (titleController.text.isNotEmpty && target != null && target > 0) {
                  final savingsProvider = Provider.of<SavingsProvider>(context, listen: false);
                  savingsProvider.addGoal(
                    SavingsGoalModel(
                      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
                      uid: 'local_user',
                      title: titleController.text.trim(),
                      targetAmount: target,
                      deadline: DateTime.now().add(const Duration(days: 90)),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Create Goal'),
            ),
          ],
        );
      },
    );
  }

  void _showDepositDialog(BuildContext context, SavingsGoalModel goal) {
    final depositController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Deposit to ${goal.title}'),
          content: SingleChildScrollView(
            child: TextField(
              controller: depositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Deposit Amount'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final deposit = double.tryParse(depositController.text);
                if (deposit != null && deposit > 0) {
                  final savingsProvider = Provider.of<SavingsProvider>(context, listen: false);
                  savingsProvider.depositToGoal(goal.id, deposit);
                  Navigator.pop(context);
                }
              },
              child: const Text('Confirm Deposit'),
            ),
          ],
        );
      },
    );
  }
}
