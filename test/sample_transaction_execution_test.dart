import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/savings_provider.dart';
import 'package:expense_tracker/services/local_storage_service.dart';
import 'package:expense_tracker/services/sms_parser_service.dart';
import 'package:expense_tracker/services/sms_auto_capture_service.dart';
import 'package:expense_tracker/utils/formatters.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./test_hive_sample');
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

  group('Sample Transactions Execution & Demonstration Suite', () {
    test('Perform manual expense and income sample transactions', () async {
      final txProvider = TransactionProvider();
      final now = DateTime.now();

      print('\n🚀 --- PERFORMING SAMPLE TRANSACTIONS ---');

      // 1. Add Monthly Salary Income
      final salaryTx = TransactionModel(
        id: 'sample_salary_001',
        uid: 'user_guest',
        type: TransactionType.income,
        amount: 85000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        description: 'Monthly Salary Credit',
        date: now.subtract(const Duration(days: 5)),
      );
      await txProvider.addTransaction(salaryTx);
      print('✅ [1/5] Executed Income Transaction: Salary ₹85,000 via Bank Transfer');

      // 2. Add Swiggy Food Expense
      final foodTx = TransactionModel(
        id: 'sample_food_002',
        uid: 'user_guest',
        type: TransactionType.expense,
        amount: 680.0,
        category: 'Food',
        paymentMethod: 'UPI',
        description: 'Swiggy Dinner Order',
        date: now.subtract(const Duration(days: 2)),
      );
      await txProvider.addTransaction(foodTx);
      print('✅ [2/5] Executed Expense Transaction: Food ₹680 via UPI');

      // 3. Add Amazon Credit Card Purchase
      final ccTx = TransactionModel(
        id: 'sample_shopping_003',
        uid: 'user_guest',
        type: TransactionType.expense,
        amount: 4500.0,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        description: 'Amazon Headphones Purchase ending 2235',
        date: now.subtract(const Duration(days: 1)),
      );
      await txProvider.addTransaction(ccTx);
      print('✅ [3/5] Executed Credit Card Expense: Shopping ₹4,500 on CC ••2235');

      // 4. Simulate Auto-Captured HDFC Bank SMS Transaction
      const smsBody = 'Paid Rs 1250.00 to Starbucks via Google Pay GPay UPI from HDFC Bank.';
      final parsedResult = SMSParserService.parseSMS(smsBody, senderAddress: 'AX-HDFCBK');
      expect(parsedResult, isNotNull);

      final smsTx = TransactionModel(
        id: 'sample_sms_004',
        uid: 'user_guest',
        type: parsedResult!.type,
        amount: parsedResult.amount,
        category: parsedResult.category,
        paymentMethod: parsedResult.paymentMethod,
        description: 'Coffee at Starbucks (${parsedResult.detectedApp})',
        date: now,
      );
      await txProvider.addTransaction(smsTx);
      print('✅ [4/5] Executed SMS Auto-Captured Transaction: Starbucks ₹1,250 via GPay UPI');

      // 5. Credit Card Refund Transaction
      final refundTx = TransactionModel(
        id: 'sample_refund_005',
        uid: 'user_guest',
        type: TransactionType.income,
        amount: 1500.0,
        category: 'Refund',
        paymentMethod: 'Credit Card',
        description: 'Amazon Return Refund credited to CC ending 2235',
        date: now,
      );
      await txProvider.addTransaction(refundTx);
      print('✅ [5/5] Executed Credit Card Refund: Refund ₹1,500 to CC ••2235');

      // Verification of totals
      print('\n📊 --- UPDATED FINANCIAL SYSTEM SUMMARY ---');
      print('Total Income:        ${Formatters.formatCurrency(txProvider.totalIncome)}');
      print('Total Expense:       ${Formatters.formatCurrency(txProvider.totalExpense)}');
      print('Net Credit Card Spent: ${Formatters.formatCurrency(txProvider.totalCreditCardSpent)}');
      print('Net Available Balance: ${Formatters.formatCurrency(txProvider.netBalance)}');

      expect(txProvider.transactions.length, equals(5));
      expect(txProvider.totalIncome, equals(86500.0)); // 85000 + 1500 refund
      expect(txProvider.totalExpense, equals(6430.0));  // 680 + 4500 + 1250
      expect(txProvider.totalCreditCardSpent, equals(3000.0)); // 4500 - 1500 refund = 3000
    });
  });
}
