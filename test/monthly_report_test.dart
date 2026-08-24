import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/services/monthly_report_service.dart';

void main() {
  group('MonthlyReportService Advanced Data & Metrics Tests', () {
    final targetMonth = DateTime(2026, 8, 1);
    final prevMonth = DateTime(2026, 7, 1);

    final transactions = [
      // Current month transactions (Aug 2026)
      TransactionModel(
        id: 'tx_inc_1',
        uid: 'user_1',
        type: TransactionType.income,
        amount: 100000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        description: 'August Salary',
        date: DateTime(2026, 8, 1),
      ),
      TransactionModel(
        id: 'tx_exp_rent',
        uid: 'user_1',
        type: TransactionType.expense,
        amount: 25000.0,
        category: 'Rent',
        paymentMethod: 'Bank Transfer',
        description: 'House Rent',
        date: DateTime(2026, 8, 2),
      ),
      TransactionModel(
        id: 'tx_exp_grocery',
        uid: 'user_1',
        type: TransactionType.expense,
        amount: 8000.0,
        category: 'Grocery',
        paymentMethod: 'UPI',
        description: 'Monthly Groceries',
        date: DateTime(2026, 8, 5),
      ),
      TransactionModel(
        id: 'tx_exp_shopping',
        uid: 'user_1',
        type: TransactionType.expense,
        amount: 12000.0,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        description: 'New Clothes & Shoes',
        date: DateTime(2026, 8, 15), // Saturday
      ),
      TransactionModel(
        id: 'tx_exp_food',
        uid: 'user_1',
        type: TransactionType.expense,
        amount: 5000.0,
        category: 'Food',
        paymentMethod: 'UPI',
        description: 'Dining Out',
        date: DateTime(2026, 8, 16), // Sunday
      ),

      // Previous month transactions (Jul 2026) for MoM calculation
      TransactionModel(
        id: 'tx_prev_inc',
        uid: 'user_1',
        type: TransactionType.income,
        amount: 90000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        description: 'July Salary',
        date: DateTime(2026, 7, 1),
      ),
      TransactionModel(
        id: 'tx_prev_exp',
        uid: 'user_1',
        type: TransactionType.expense,
        amount: 40000.0,
        category: 'Rent',
        paymentMethod: 'Bank Transfer',
        description: 'July Rent & Others',
        date: DateTime(2026, 7, 2),
      ),
    ];

    final budgets = [
      BudgetModel(
        id: 'b_overall',
        uid: 'user_1',
        category: 'Overall',
        monthlyLimit: 60000.0,
      ),
      BudgetModel(
        id: 'b_food',
        uid: 'user_1',
        category: 'Food',
        monthlyLimit: 8000.0,
      ),
    ];

    test('Computes Totals, Net Savings, and Savings Rate accurately', () {
      final report = MonthlyReportService.generateReport(
        transactions: transactions,
        budgets: budgets,
        targetMonth: targetMonth,
      );

      expect(report.totalIncome, 100000.0);
      expect(report.totalExpense, 50000.0);
      expect(report.netSavings, 50000.0);
      expect(report.savingsRate, 50.0);
      expect(report.transactionCount, 5);
      expect(report.incomeCount, 1);
      expect(report.expenseCount, 4);
    });

    test('Computes Month-over-Month (MoM) Deltas accurately', () {
      final report = MonthlyReportService.generateReport(
        transactions: transactions,
        budgets: budgets,
        targetMonth: targetMonth,
      );

      expect(report.prevMonthIncome, 90000.0);
      expect(report.prevMonthExpense, 40000.0);
      expect(report.incomeMoMChangePct, closeTo(11.11, 0.1)); // (100k - 90k) / 90k * 100
      expect(report.expenseMoMChangePct, 25.0); // (50k - 40k) / 40k * 100
    });

    test('Computes 50/30/20 Needs vs Wants correctly', () {
      final report = MonthlyReportService.generateReport(
        transactions: transactions,
        budgets: budgets,
        targetMonth: targetMonth,
      );

      // Rent (25k) + Grocery (8k) = 33k (Needs)
      // Shopping (12k) + Food (5k) = 17k (Wants)
      // Net Savings = 50k (Savings/Investments)
      expect(report.needsAmount, 33000.0);
      expect(report.wantsAmount, 17000.0);
      expect(report.savingsInvestmentsAmount, 50000.0);
      expect(report.needsPct, 33.0);
      expect(report.wantsPct, 17.0);
      expect(report.savingsInvestmentsPct, 50.0);
    });

    test('Computes Daily Spend, Weekend vs Weekday analysis and Peak Days', () {
      final report = MonthlyReportService.generateReport(
        transactions: transactions,
        budgets: budgets,
        targetMonth: targetMonth,
      );

      expect(report.highestSpendDay, 2); // Aug 2 (Rent: 25k)
      expect(report.highestSpendDayAmount, 25000.0);
      expect(report.weekendExpense, 42000.0); // Aug 2 (Sunday: 25k) + Aug 15 (Sat: 12k) + Aug 16 (Sun: 5k)
      expect(report.weekdayExpense, 8000.0); // Aug 5 (Wednesday: 8k)
    });

    test('Calculates Payment Methods Breakdown and Health Score', () {
      final report = MonthlyReportService.generateReport(
        transactions: transactions,
        budgets: budgets,
        targetMonth: targetMonth,
      );

      expect(report.paymentMethodExpenses['Bank Transfer'], 25000.0);
      expect(report.paymentMethodExpenses['UPI'], 13000.0);
      expect(report.paymentMethodExpenses['Credit Card'], 12000.0);
      expect(report.digitalSpendPct, 100.0); // All were Bank, UPI, CC
      expect(report.healthGrade, isNotNull);
      expect(report.healthScore, greaterThanOrEqualTo(80));
    });
  });
}
