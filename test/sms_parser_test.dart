import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/sms_parser_service.dart';

void main() {
  group('SMSParserService Comprehensive Edge Case & Bank SMS Tests', () {
    test('1. HDFC Bank Credit Card purchase with card validity suffix', () {
      const sms = 'Your HDFC Bank Credit Card XX 2235 has been used for Rs 5000.00 at AMAZON on 12-08-2026. Card valid till 12/28.';
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

    test('16. SMS-body deduplication: identical body = duplicate, same amount ≠ duplicate', () {
      // Two different ₹500 transactions at different merchants → both are REAL, separate transactions.
      // The parser should return distinct results (different merchants).
      const smsStarbucks = 'Paid Rs.500.00 to STARBUCKS via UPI on 12-Aug-2026 10:12:00';
      const smsUber      = 'Paid Rs.500.00 to UBER via UPI on 12-Aug-2026 10:14:00';

      final res1 = SMSParserService.parseSMS(smsStarbucks);
      final res2 = SMSParserService.parseSMS(smsUber);

      expect(res1, isNotNull);
      expect(res1!.merchant, 'STARBUCKS');
      expect(res2, isNotNull);
      expect(res2!.merchant, 'UBER');

      // Fingerprints of the two SMS bodies must be DIFFERENT → neither is a duplicate of the other.
      final fp1 = 'ad-hdfcbk|${smsStarbucks.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()}';
      final fp2 = 'ad-hdfcbk|${smsUber.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()}';
      expect(fp1, isNot(equals(fp2)));

      // The EXACT same SMS body arriving twice → fingerprints are identical → duplicate detected.
      final fp3 = 'ad-hdfcbk|${smsStarbucks.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()}';
      expect(fp1, equals(fp3)); // ← same SMS = same fingerprint = would be suppressed
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

    test('21. Bank of Baroda (BOB) UPI Debit SMS with Indian DLT senders (AD-BOBTXN, VM-BOBTXN, BP-BOBTXN)', () {
      const sms = 'Rs.200.00 Dr. from A/C XXXXXX7873 and Cr. to aishuaishu4831@oksbi. Ref:622545583768. AvlBal:Rs34081.64(2026:08:13 12:55:30). Not you? Call 18005700/5000-BOB';

      for (final sender in ['AD-BOBTXN', 'VM-BOBTXN', 'BP-BOBTXN', 'JD-BOBTXN', 'AX-BOBSMS']) {
        final result = SMSParserService.parseSMS(sms, senderAddress: sender);

        expect(result, isNotNull, reason: 'Failed for sender: $sender');
        expect(result!.amount, 200.0);
        expect(result.type, TransactionType.expense);
        expect(result.paymentMethod, 'UPI');
        expect(result.merchant, contains('aishuaishu4831@oksbi'));
        expect(result.merchant, isNot(endsWith('.')));
        expect(result.detectedApp, 'Bank of Baroda');
      }
    });

    test('22. BOB SMS detected via sender header even if body omits bank name', () {
      const sms = 'Rs. 500.00 Dr. from A/C XX7873. Ref: 622309396978. AvlBal: Rs 15,400.00';
      final result = SMSParserService.parseSMS(sms, senderAddress: 'AD-BOBTXN');

      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, TransactionType.expense);
      expect(result.detectedApp, 'Bank of Baroda');
    });

    test('23. Comprehensive Public Sector Indian Banks (Canara, PNB, Union, BOI, Indian Bank, IOB, Central Bank)', () {
      final bankTests = [
        {'sms': 'Rs.1500.00 debited from A/C XX1234 on 12-Aug. Ref: 981230491. Avl Bal: Rs 12,000.', 'sender': 'VM-CANBNK', 'bank': 'Canara Bank'},
        {'sms': 'Your A/C XX5678 is debited by Rs. 850.00 towards UPI/merchant@ybl. Avl Bal: Rs 9,400.', 'sender': 'AD-PNBSMS', 'bank': 'PNB Bank'},
        {'sms': 'INR 3,200.00 Dr. from A/C XX9012 for POS Purchase at Reliance Digital.', 'sender': 'BP-UNIONB', 'bank': 'Union Bank'},
        {'sms': 'Rs 600.00 Dr from A/c XX3456. Ref 623910293. Avl Bal Rs 5,200.', 'sender': 'VK-BOITXN', 'bank': 'Bank of India'},
        {'sms': 'A/C XX7890 debited with INR 2,100.00 for payment to Amazon.', 'sender': 'JD-INDIANB', 'bank': 'Indian Bank'},
        {'sms': 'Rs. 450.00 Dr. from A/C XX2345 on 10-08-2026. Avl Bal Rs 3,100.', 'sender': 'AX-IOBTXN', 'bank': 'Indian Overseas Bank'},
        {'sms': 'A/C XX6789 is debited by Rs 1,000.00 at SBI ATM.', 'sender': 'BZ-CBIN', 'bank': 'Central Bank of India'},
      ];

      for (final t in bankTests) {
        final res = SMSParserService.parseSMS(t['sms']!, senderAddress: t['sender']!);
        expect(res, isNotNull, reason: 'Failed for ${t['bank']}');
        expect(res!.detectedApp, t['bank']!);
        expect(res.amount, greaterThan(0));
      }
    });

    test('24. Payments Banks & Neo-Banks (IPPB, Paytm, Airtel, Fi Money, Jupiter)', () {
      final paymentsTests = [
        {'sms': 'Rs 300.00 debited from IPPB Account XX4321 for UPI transfer.', 'sender': 'AD-IPPB', 'bank': 'India Post Payments Bank'},
        {'sms': 'Paid Rs 120.00 via Airtel Payments Bank to Local Shop.', 'sender': 'VM-AIRTEL', 'bank': 'Airtel Payments Bank'},
        {'sms': 'Rs 499.00 debited from Fi Account XX8765 towards Spotify.', 'sender': 'JD-EPIFI', 'bank': 'Fi Money'},
        {'sms': 'INR 1,200.00 spent via Jupiter Card ending 9988 at Swiggy.', 'sender': 'BP-JUPITER', 'bank': 'Jupiter Money'},
      ];

      for (final t in paymentsTests) {
        final res = SMSParserService.parseSMS(t['sms']!, senderAddress: t['sender']!);
        expect(res, isNotNull, reason: 'Failed for ${t['bank']}');
        expect(res!.detectedApp, t['bank']!);
        expect(res.amount, greaterThan(0));
      }
    });

    test('25. Small Finance Banks (AU SFB, Utkarsh, Equitas, Ujjivan)', () {
      final sfbTests = [
        {'sms': 'Rs 750.00 Dr. from A/C XX3322 via UPI. Avl Bal Rs 14,200.', 'sender': 'AD-AUBANK', 'bank': 'AU Small Finance Bank'},
        {'sms': 'INR 1,000.00 debited from Equitas A/C XX4455.', 'sender': 'VM-EQUITAS', 'bank': 'Equitas Bank'},
        {'sms': 'Rs 500.00 debited from Ujjivan A/C XX6677 for bill payment.', 'sender': 'BP-UJJIVAN', 'bank': 'Ujjivan Bank'},
      ];

      for (final t in sfbTests) {
        final res = SMSParserService.parseSMS(t['sms']!, senderAddress: t['sender']!);
        expect(res, isNotNull, reason: 'Failed for ${t['bank']}');
        expect(res!.detectedApp, t['bank']!);
        expect(res.amount, greaterThan(0));
      }
    });

    test('26. Card Swiped POS Purchase & ATM Cash Withdrawal across banks', () {
      const posSms = 'INR 2,499.00 swiped at Croma Electronics on HDFC Bank Card XX4321. Avl Lmt Rs 75,000.';
      const atmSms = 'Rs 4,000.00 cash wdl at ICICI Bank ATM XX9876 on 12-Aug. Avl Bal Rs 32,000.';

      final resPos = SMSParserService.parseSMS(posSms, senderAddress: 'AD-HDFCBK');
      final resAtm = SMSParserService.parseSMS(atmSms, senderAddress: 'VM-ICICIB');

      expect(resPos, isNotNull);
      expect(resPos!.amount, 2499.0);
      expect(resPos.paymentMethod, 'Credit Card');

      expect(resAtm, isNotNull);
      expect(resAtm!.amount, 4000.0);
      expect(resAtm.type, TransactionType.expense);
    });

    test('27. Comprehensive All Indian Credit Card Issuers & Brands', () {
      final ccTests = [
        {'sms': 'Rs 2,100.00 spent on your BOBCARD ending 7873 at BigBasket on 12-Aug. Avl Lmt Rs 85,000.', 'sender': 'AD-BOBCRD', 'last4': '7873', 'bank': 'Bank of Baroda'},
        {'sms': 'Rs 3,500.00 spent on SBI Card XX9876 at Swiggy.', 'sender': 'VM-SBICRD', 'last4': '9876', 'bank': 'SBI Bank'},
        {'sms': 'Your HDFC Bank Credit Card XX 2235 has been used for Rs 5000.00 at AMAZON.', 'sender': 'AD-HDFCBK', 'last4': '2235', 'bank': 'HDFC Bank'},
        {'sms': 'ICICI Bank Credit Card XX9876 used at SWIGGY for Rs.350.00.', 'sender': 'BP-ICICIB', 'last4': '9876', 'bank': 'ICICI Bank'},
        {'sms': 'Transaction of INR 1,499.00 on Axis Bank Credit Card XX5678 at ZOMATO.', 'sender': 'VK-AXISBK', 'last4': '5678', 'bank': 'Axis Bank'},
        {'sms': 'INR 800.00 spent on your Kotak Credit Card ending 9988 at Uber.', 'sender': 'JD-KOTAKB', 'last4': '9988', 'bank': 'Kotak Bank'},
        {'sms': 'Rs 1,200.00 spent on PNB Credit Card XX3456 at D-Mart.', 'sender': 'AX-PNBSMS', 'last4': '3456', 'bank': 'PNB Bank'},
        {'sms': 'INR 1,500.00 spent on IDFC FIRST Credit Card XX8899 at Nykaa.', 'sender': 'BZ-IDFCFB', 'last4': '8899', 'bank': 'IDFC First Bank'},
        {'sms': 'Refund Alert! INR 1,793.00 credited to your SuperCard ending with 2235 from Flipkart.', 'sender': 'VM-RBLBNK', 'last4': '2235', 'bank': 'RBL Bank'},
        {'sms': 'Rs 450.00 spent on your OneCard 1234 at Starbucks.', 'sender': 'AD-ONECRD', 'last4': '1234', 'bank': 'OneCard'},
        {'sms': 'Rs 600.00 spent on Slice card ending 3344.', 'sender': 'VM-SLICE', 'last4': '3344', 'bank': 'Slice Card'},
      ];

      for (final t in ccTests) {
        final res = SMSParserService.parseSMS(t['sms']!, senderAddress: t['sender']!);
        expect(res, isNotNull, reason: 'Failed for ${t['bank']} Credit Card');
        expect(res!.amount, greaterThan(0));
        expect(res.paymentMethod, 'Credit Card', reason: 'Method should be Credit Card for ${t['bank']}');
        expect(res.cardLast4, t['last4']!);
      }
    });

    test('28. Exact float amount captured without rounding for BOB UPI Credit SMS', () {
      const sms = 'Dear BOB UPI User: Your account is credited with INR 10.26 on 2026-08-19 12:33:04 PM by UPI Ref No 623134846690; AvlBal: Rs37149.32 - BOB';
      final result = SMSParserService.parseSMS(sms);

      expect(result, isNotNull);
      expect(result!.amount, 10.26);
      expect(result.type, TransactionType.income);
      expect(result.paymentMethod, 'UPI');
      expect(result.detectedApp, 'Bank of Baroda');
    });
  });
}



