import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/models/savings_goal_model.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/savings_provider.dart';
import 'package:expense_tracker/services/local_storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./test_hive_sys');
    await Hive.openBox(LocalStorageService.transactionsBoxName);
    await Hive.openBox(LocalStorageService.categoriesBoxName);
    await Hive.openBox(LocalStorageService.budgetsBoxName);
    await Hive.openBox(LocalStorageService.savingsBoxName);
    await Hive.openBox(LocalStorageService.settingsBoxName);
    await Hive.openBox(LocalStorageService.usersBoxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('System-Wide Transaction & Storage Lifecycle Tests', () {
    test('1. Full Transaction CRUD operations and live state update', () async {
      final provider = TransactionProvider();
      expect(provider.transactions.isEmpty, isTrue);

      final now = DateTime.now();

      // Add Salary Income
      final txIncome = TransactionModel(
        id: 'sys_tx_1',
        uid: 'local_user',
        type: TransactionType.income,
        amount: 80000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        description: 'Monthly Salary Deposit',
        date: now,
      );
      await provider.addTransaction(txIncome);

      // Add Groceries Expense
      final txExpense = TransactionModel(
        id: 'sys_tx_2',
        uid: 'local_user',
        type: TransactionType.expense,
        amount: 3500.0,
        category: 'Groceries',
        paymentMethod: 'UPI',
        description: 'Blinkit weekly groceries',
        date: now,
      );
      await provider.addTransaction(txExpense);

      expect(provider.transactions.length, equals(2));
      expect(provider.totalIncome, equals(80000.0));
      expect(provider.totalExpense, equals(3500.0));

      // Update Expense Amount
      final updatedTxExpense = txExpense.copyWith(amount: 4000.0);
      await provider.updateTransaction(updatedTxExpense);

      expect(provider.totalExpense, equals(4000.0));
      expect(provider.netBalance, equals(76000.0));

      // Delete Expense
      await provider.deleteTransaction('sys_tx_2');
      expect(provider.transactions.length, equals(1));
      expect(provider.totalExpense, equals(0.0));
      expect(provider.netBalance, equals(80000.0));

      // Clean up income tx for next tests
      await provider.deleteTransaction('sys_tx_1');
    });

    test('2. Filter, Search, and Sorting operations', () async {
      final provider = TransactionProvider();
      final date1 = DateTime(2026, 8, 1, 10, 0);
      final date2 = DateTime(2026, 8, 10, 14, 0);

      await provider.addTransaction(TransactionModel(
        id: 'f_1',
        uid: 'local_user',
        type: TransactionType.expense,
        amount: 120.0,
        category: 'Food',
        paymentMethod: 'Cash',
        description: 'Coffee at Starbucks',
        date: date1,
      ));

      await provider.addTransaction(TransactionModel(
        id: 'f_2',
        uid: 'local_user',
        type: TransactionType.expense,
        amount: 2500.0,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        description: 'Clothes from Zara ending 2235',
        date: date2,
      ));

      // Search Query Filter
      provider.setSearchQuery('Coffee');
      expect(provider.filteredTransactions.length, equals(1));
      expect(provider.filteredTransactions.first.id, equals('f_1'));

      // Category Filter
      provider.resetFilters();
      provider.setCategoryFilter('Shopping');
      expect(provider.filteredTransactions.length, equals(1));
      expect(provider.filteredTransactions.first.id, equals('f_2'));

      // Payment Method Filter
      provider.resetFilters();
      provider.setPaymentFilter('Credit Card');
      expect(provider.filteredTransactions.length, equals(1));

      // Type Filter
      provider.resetFilters();
      provider.setTypeFilter(TransactionTypeFilter.expense);
      expect(provider.filteredTransactions.length, equals(2));

      // Sort Order
      provider.resetFilters();
      provider.setSortOrder(TransactionSortOrder.amountHighToLow);
      expect(provider.filteredTransactions.first.amount, equals(2500.0));

      // Cleanup
      await provider.deleteTransaction('f_1');
      await provider.deleteTransaction('f_2');
      provider.resetFilters();
    });

    test('3. Budget Provider spent calculation tracking', () async {
      final budgetProvider = BudgetProvider();
      final txProvider = TransactionProvider();

      final now = DateTime.now();
      await budgetProvider.setBudget(BudgetModel(
        id: 'b_food',
        uid: 'local_user',
        category: 'Food',
        monthlyLimit: 5000.0,
      ));

      await txProvider.addTransaction(TransactionModel(
        id: 'tx_b1',
        uid: 'local_user',
        type: TransactionType.expense,
        amount: 1500.0,
        category: 'Food',
        paymentMethod: 'UPI',
        description: 'Restaurant bill',
        date: now,
      ));

      final budgetStatuses = budgetProvider.getCategoryBudgetStatuses(txProvider.transactions, month: now);
      final foodStatus = budgetStatuses.firstWhere((s) => s.budget.category == 'Food');
      expect(foodStatus.spent, equals(1500.0));
      expect(foodStatus.remaining, equals(3500.0));

      // Cleanup
      await txProvider.deleteTransaction('tx_b1');
      await budgetProvider.deleteBudget('b_food');
    });

    test('4. Savings Goal progress tracking', () async {
      final savingsProvider = SavingsProvider();
      await savingsProvider.addGoal(SavingsGoalModel(
        id: 'g_vacation',
        uid: 'local_user',
        title: 'Trip to Goa',
        targetAmount: 20000.0,
        savedAmount: 5000.0,
        deadline: DateTime(2026, 12, 31),
      ));

      expect(savingsProvider.goals.length, equals(1));
      expect(savingsProvider.goals.first.savedAmount, equals(5000.0));

      // Deposit to goal
      await savingsProvider.depositToGoal('g_vacation', 7000.0);

      expect(savingsProvider.goals.first.savedAmount, equals(12000.0));
      expect(savingsProvider.goals.first.progressPercentage, equals(0.6));

      await savingsProvider.deleteGoal('g_vacation');
      expect(savingsProvider.goals.isEmpty, isTrue);
    });
  });
}
