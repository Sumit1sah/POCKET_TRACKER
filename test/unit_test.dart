import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/services/sms_parser_service.dart';
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
}
