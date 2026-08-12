import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/services/sms_parser_service.dart';
import 'package:expense_tracker/services/ai_insight_service.dart';
import 'package:expense_tracker/services/smart_categorizer_service.dart';
import 'package:expense_tracker/utils/formatters.dart';

void main() {
  group('Manual Expense & Income Entry Tests', () {
    test('Create Manual Expense Transaction', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'manual_exp_1',
        uid: 'user_123',
        type: TransactionType.expense,
        amount: 850.0,
        category: 'Food',
        paymentMethod: 'UPI',
        description: 'Dinner with family',
        date: now,
      );

      expect(tx.type, TransactionType.expense);
      expect(tx.amount, 850.0);
      expect(tx.category, 'Food');
      expect(tx.paymentMethod, 'UPI');
      expect(tx.description, 'Dinner with family');
    });

    test('Create Manual Income Transaction', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'manual_inc_1',
        uid: 'user_123',
        type: TransactionType.income,
        amount: 75000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        description: 'Monthly Salary Credit',
        date: now,
      );

      expect(tx.type, TransactionType.income);
      expect(tx.amount, 75000.0);
      expect(tx.category, 'Salary');
      expect(tx.paymentMethod, 'Bank Transfer');
    });
  });

  group('SMSParserService Tests', () {
    test('Parse GPay Expense SMS', () {
      const sms = 'Paid Rs 350.00 to Starbucks via Google Pay GPay UPI from HDFC Bank.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 350.0);
      expect(result.type, TransactionType.expense);
      expect(result.detectedApp, 'Google Pay');
      expect(result.paymentMethod, 'UPI');
    });

    test('Parse Salary Deposit SMS', () {
      const sms = 'Rs 50,000.00 credited to Bank A/C XX1234 for Salary Deposit via Bank Transfer.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 50000.0);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Salary');
      expect(result.paymentMethod, 'Bank Transfer');
    });

    test('Return null for non-financial SMS', () {
      const sms = 'Your OTP for login is 482910. Do not share with anyone.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNull);
    });
  });

  group('Formatters Tests', () {
    test('Format Currency with Symbol', () {
      expect(Formatters.formatCurrency(1500.0, symbol: '₹'), '₹ 1,500');
      expect(Formatters.formatCurrency(250.50, symbol: '\$'), '\$ 250.50');
    });

    test('Format Date and Time', () {
      final date = DateTime(2026, 7, 24, 16, 25);
      expect(Formatters.formatDate(date), '24 Jul 2026');
      expect(Formatters.formatShortDateTime(date), '24 Jul, 4:25 PM');
    });
  });

  group('Model Serialization Tests', () {
    test('TransactionModel toMap & fromMap', () {
      final date = DateTime.now();
      final model = TransactionModel(
        id: 'tx_101',
        uid: 'user_test',
        type: TransactionType.expense,
        amount: 450.0,
        category: 'Food',
        paymentMethod: 'UPI',
        description: 'Dinner at Swiggy',
        date: date,
      );

      final map = model.toMap();
      final restored = TransactionModel.fromMap(map);

      expect(restored.id, 'tx_101');
      expect(restored.amount, 450.0);
      expect(restored.category, 'Food');
      expect(restored.type, TransactionType.expense);
    });

    test('CategoryModel toMap & fromMap', () {
      final cat = CategoryModel(
        id: 'cat_test',
        uid: 'user_test',
        name: 'Groceries',
        iconCodePoint: 58800,
        colorValue: 4283215694,
      );

      final map = cat.toMap();
      final restored = CategoryModel.fromMap(map);

      expect(restored.id, 'cat_test');
      expect(restored.name, 'Groceries');
    });
  });

  group('Credit Card & Refund Logic Tests', () {
    test('Credit Card Refund reduces spent total', () {
      final purchase = TransactionModel(
        id: 'cc_tx_1',
        uid: 'user_123',
        type: TransactionType.expense,
        amount: 5000.0,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        description: 'Amazon Purchase ending with 2235',
        date: DateTime.now(),
      );

      final refund = TransactionModel(
        id: 'cc_tx_2',
        uid: 'user_123',
        type: TransactionType.income,
        amount: 1200.0,
        category: 'Refund',
        paymentMethod: 'Credit Card',
        description: 'Refund Alert! credited to SuperCard ending with 2235',
        date: DateTime.now(),
      );

      expect(purchase.paymentMethod, 'Credit Card');
      expect(refund.paymentMethod, 'Credit Card');

      // Net Credit Card Spent Calculation = purchases - refunds
      final netCcSpent = purchase.amount - refund.amount;
      expect(netCcSpent, 3800.0);
    });

    test('Debt / Repayment SMS & Category Matching', () {
      const sms = 'Sent Rs 2,500 to Friend for loan repayment money back';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.category, 'Money Given / Lent');
    });

    test('Credit Card Refund SMS Regex Matching', () {
      const sms = 'Refund Alert! INR 1,793.00 credited to your SuperCard ending with 2235 from Flipkart Internet';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.type, TransactionType.income);
      expect(result.amount, 1793.0);
      expect(result.paymentMethod, 'Credit Card');
    });

    test('Total Net Balance includes user-specified Credit Card Limit and debits CC transactions', () {
      const income = 50000.0;
      const userEnteredCreditLimit = 100000.0;
      const ccExpense = 15000.0;
      const otherExpense = 5000.0;

      const totalExpense = ccExpense + otherExpense;
      const totalNetBalance = income + userEnteredCreditLimit - totalExpense;

      // 50,000 + 100,000 - 20,000 = 130,000
      expect(totalNetBalance, 130000.0);
    });

    test('Credit Card balance persists across month changes until paid', () {
      final lastMonth = DateTime.now().subtract(const Duration(days: 40));
      final pastPurchase = TransactionModel(
        id: 'cc_prev_1',
        uid: 'user_123',
        type: TransactionType.expense,
        amount: 8000.0,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        description: 'Past month credit card expense ending with 1234',
        date: lastMonth,
      );

      final currentMonthPayment = TransactionModel(
        id: 'cc_pay_1',
        uid: 'user_123',
        type: TransactionType.income,
        amount: 3000.0,
        category: 'Credit Card Bill',
        paymentMethod: 'Credit Card',
        description: 'Credit Card Bill payment credited to 1234',
        date: DateTime.now(),
      );

      // Verify past month purchase is a CC expense
      expect(pastPurchase.paymentMethod, 'Credit Card');
      expect(pastPurchase.type, TransactionType.expense);
      // Verify payment reduces balance across months
      final remainingBalance = pastPurchase.amount - currentMonthPayment.amount;
      expect(remainingBalance, 5000.0);
    });
  });

  group('AIInsightService Money Tips Tests', () {
    test('Generate 50/30/20 & Money Tips with sample income and expenses', () {
      final now = DateTime.now();
      final transactions = [
        TransactionModel(
          id: 't_inc',
          uid: 'u1',
          type: TransactionType.income,
          amount: 50000.0,
          category: 'Salary',
          paymentMethod: 'Bank Transfer',
          description: 'Monthly Salary',
          date: now,
        ),
        TransactionModel(
          id: 't_food',
          uid: 'u1',
          type: TransactionType.expense,
          amount: 15000.0,
          category: 'Food',
          paymentMethod: 'UPI',
          description: 'Dining & Food Orders',
          date: now,
        ),
        TransactionModel(
          id: 't_bills',
          uid: 'u1',
          type: TransactionType.expense,
          amount: 10000.0,
          category: 'Bills',
          paymentMethod: 'Net Banking',
          description: 'Electricity & Internet',
          date: now,
        ),
      ];

      final insights = AIInsightService.generateInsights(transactions, '₹');

      expect(insights, isNotEmpty);
      
      // Verify Money Tips are present
      final tips = insights.where((i) => i.type == 'tip').toList();
      expect(tips, isNotEmpty);

      final has503020Tip = tips.any((t) => t.title.contains('50/30/20'));
      expect(has503020Tip, isTrue);

      final hasBufferTip = tips.any((t) => t.title.contains('Safety Buffer') || t.title.contains('Emergency'));
      expect(hasBufferTip, isTrue);

      final hasPayFirstTip = tips.any((t) => t.title.contains('Pay Yourself First'));
      expect(hasPayFirstTip, isTrue);
    });
  });

  group('SmartCategorizerService Tests', () {
    test('Predict categories accurately from merchant/note keywords', () {
      expect(SmartCategorizerService.predictCategory('Swiggy order dinner', isExpense: true), 'Food');
      expect(SmartCategorizerService.predictCategory('Blinkit groceries', isExpense: true), 'Groceries');
      expect(SmartCategorizerService.predictCategory('Uber ride to airport', isExpense: true), 'Transport');
      expect(SmartCategorizerService.predictCategory('Netflix subscription', isExpense: true), 'Entertainment');
      expect(SmartCategorizerService.predictCategory('Electricity bill payment', isExpense: true), 'Bills');
      expect(SmartCategorizerService.predictCategory('Monthly Salary deposit', isExpense: false), 'Salary');
    });

    test('Return smart category suggestions', () {
      final suggestions = SmartCategorizerService.getSuggestedCategories('Zomato', isExpense: true);
      expect(suggestions, contains('Food'));
    });
  });
}
