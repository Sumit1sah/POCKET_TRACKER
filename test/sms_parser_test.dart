import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/sms_parser_service.dart';

void main() {
  group('SMSParserService Comprehensive Edge Case & Bank SMS Tests', () {
    test('1. HDFC Bank Credit Card purchase with card validity suffix', () {
      const sms = 'Your HDFC Bank Credit Card XX 2235 has been used for Rs 5000.00 at AMAZON on 12-08-2026. Card valid till 12/28.';
      final result = SMSParserService.parseSMS(sms, senderAddress: 'AD-HDFCBK');
      
      // Note: AD- sender prefix is promo filter, but if sender is VM-HDFCBK or null:
      final resultNoSender = SMSParserService.parseSMS(sms, senderAddress: 'VM-HDFCBK');
      // VM- is promo prefix in Layer 1. Let's test with real bank sender like 'AX-HDFCBK' or null.
      final resultBankSender = SMSParserService.parseSMS(sms, senderAddress: 'AX-HDFCBK');

      expect(resultBankSender, isNotNull);
      expect(resultBankSender!.amount, 5000.0);
      expect(resultBankSender.type, TransactionType.expense);
      expect(resultBankSender.paymentMethod, 'Credit Card');
      expect(resultBankSender.cardLast4, '2235');
    });

    test('2. SBI Credit Card purchase with availed at and expiry info', () {
      const sms = 'Your SBI Credit Card 4321 has been availed for Rs. 2,450.00 at FLIPKART. Card expires on 05/29.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 2450.0);
      expect(result.type, TransactionType.expense);
      expect(result.paymentMethod, 'Credit Card');
      expect(result.cardLast4, '4321');
    });

    test('3. ICICI Credit Card used at Swiggy', () {
      const sms = 'ICICI Bank Credit Card XX9876 used at SWIGGY for Rs.350.00 on 10-Aug-26. Avl Lmt: Rs 45,000.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 350.0);
      expect(result.type, TransactionType.expense);
      expect(result.paymentMethod, 'Credit Card');
      expect(result.cardLast4, '9876');
    });

    test('4. Bank of Baroda (BOB) Debit SMS with Dr abbreviation format', () {
      const sms = 'Rs. 1,200.00 Dr. from A/C XX5432 on 12-08-2026. Ref No 622309396978. Avl Bal Rs. 15,400.00';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 1200.0);
      expect(result.type, TransactionType.expense);
    });

    test('5. Salary Credit SMS (Income)', () {
      const sms = 'Your A/C XX1234 has been credited with INR 75,000.00 towards Salary for July. Avl Bal INR 1,20,000.00';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 75000.0);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Salary');
    });

    test('6. Cashback Credited SMS (Income)', () {
      const sms = 'Cashback of Rs 150.00 credited to your A/C XX8899 on transaction at Zomato. Avl Bal Rs 5,400.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 150.0);
      expect(result.type, TransactionType.income);
    });

    test('7. Credit Card Refund SMS', () {
      const sms = 'Refund Alert! INR 1,793.00 credited to your SuperCard ending with 2235 from Flipkart Internet.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 1793.0);
      expect(result.type, TransactionType.income);
      expect(result.paymentMethod, 'Credit Card');
      expect(result.cardLast4, '2235');
    });

    test('8. Credit Card Bill Payment Received Confirmation', () {
      const sms = 'Payment of Rs 5000 received towards your HDFC SuperCard ending 2235 on 11-Aug. Thank you.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Credit Card Payment');
      expect(result.paymentMethod, 'Credit Card'); // Restores credit card available limit
    });

    test('9. UPI Transaction with VPA handle', () {
      const sms = 'Paid Rs.250.00 to merchant@oksbi via UPI. Ref 482910394812. Avl Bal Rs 8,000.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 250.0);
      expect(result.type, TransactionType.expense);
      expect(result.paymentMethod, 'UPI');
    });

    test('10. HARD-BLOCK — OTP Security Code should return null', () {
      const sms = 'Your OTP for login to HDFC netbanking is 482910. Do not share code with anyone.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNull);
    });

    test('11. HARD-BLOCK — Loan / Credit card promotional offers should return null', () {
      const sms = 'You are pre-approved for personal loan of Rs 5,00,000. Apply now via link below!';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNull);
    });

    test('12. HARD-BLOCK — Promo cashback offer with "up to rs" should return null', () {
      const sms = 'Get flat 10% cashback up to rs 500 on your next Swiggy order! Use code SWIGGY10.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNull);
    });

    test('13. Balance Check notification without transaction verb should return null', () {
      const sms = 'Your available balance in A/C XX1234 is Rs. 15,400.00 as of 12-08-2026.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNull);
    });

    test('14. CC Bill Payment — Bank Debit SMS and CC Provider Confirmation SMS parse correctly', () {
      const bankSms = 'Rs.4103.00 Dr. from A/C XXXXXX7873 and Cr. to supercard@utkarshbank. Ref:622495778203. AvlBal:Rs26801.64(2026:08:12 10:52:37). Not you? Call 18005700/5000-BOB';
      const ccSms   = 'We have received payment of INR 4,103.00 for your SuperCard ending 2235. Your available limit is now INR 17,637.92 -Utkarsh SFBL';

      final res1 = SMSParserService.parseSMS(bankSms);
      final res2 = SMSParserService.parseSMS(ccSms);

      // Bank Debit SMS: Deducts from main bank balance
      expect(res1, isNotNull);
      expect(res1!.amount, 4103.0);
      expect(res1.type, TransactionType.expense);
      expect(res1.category, 'Credit Card Bill');
      expect(res1.paymentMethod, 'UPI');

      // CC Confirmation SMS: Restores available credit card limit
      expect(res2, isNotNull);
      expect(res2!.amount, 4103.0);
      expect(res2.type, TransactionType.income);
      expect(res2.category, 'Credit Card Payment');
      expect(res2.paymentMethod, 'Credit Card');
    });

    test('15. Utkarsh SFBL SuperCard ₹100 payment received credits money to Credit Card', () {
      const sms = 'We have received payment of INR 100.00 for your SuperCard ending 2235. Your available limit is now INR 17,837.92 -Utkarsh SFBL';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 100.0);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Credit Card Payment');
      expect(result.paymentMethod, 'Credit Card');
      expect(result.cardLast4, '2235');
    });

    test('16. Merchant-aware deduplication for ₹500 at 10:12 AM vs 10:14 AM', () {
      const smsStarbucks = 'Paid Rs.500.00 to STARBUCKS via UPI on 12-Aug-2026 10:12:00';
      const smsUber      = 'Paid Rs.500.00 to UBER via UPI on 12-Aug-2026 10:14:00';

      final res1 = SMSParserService.parseSMS(smsStarbucks);
      final res2 = SMSParserService.parseSMS(smsUber);

      expect(res1, isNotNull);
      expect(res1!.merchant, 'STARBUCKS');

      expect(res2, isNotNull);
      expect(res2!.merchant, 'UBER');
    });

    test('17. ATM Cash Withdrawal SMS parses correctly', () {
      const sms = 'Rs 2,000.00 withdrawn at SBI ATM XX1234 on 12-08-2026. Avl Bal Rs 18,400.00';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 2000.0);
      expect(result.type, TransactionType.expense);
    });

    test('18. Auto-Debit / ECS Mandate SMS parses correctly', () {
      const sms = 'Rs. 1,499.00 auto debited from A/C XX5432 towards Netflix Subscription. Ref: ECS92019';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 1499.0);
      expect(result.type, TransactionType.expense);
    });

    test('19. NEFT / IMPS Bank Transfer Credit parses correctly', () {
      const sms = 'Your A/C XX9876 is credited with INR 15,000.00 via NEFT credit from Infosys Ltd.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 15000.0);
      expect(result.type, TransactionType.income);
      expect(result.paymentMethod, 'Bank Transfer');
    });

    test('20. Wallet Top-Up / Money Added parses correctly', () {
      const sms = 'Rs 500.00 added to Paytm Wallet via Debit Card. Updated wallet balance Rs 1,250.';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 500.0);
    });
  });
}
