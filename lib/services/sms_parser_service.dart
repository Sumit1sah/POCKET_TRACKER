import '../models/transaction_model.dart';

class SMSParseResult {
  final double amount;
  final TransactionType type;
  final String category;
  final String merchant;
  final String paymentMethod;
  final String originalMessage;
  final String detectedApp;

  SMSParseResult({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.paymentMethod,
    required this.originalMessage,
    required this.detectedApp,
  });
}

class SMSParserService {
  /// Ultra-Permissive SMS & Payment Alert Parser for any Bank, GPay, Paytm, PhonePe, or UPI alert
  static SMSParseResult? parseSMS(String message) {
    if (message.trim().isEmpty) return null;

    final lowerMsg = message.toLowerCase();
    final cleanMsg = message.replaceAll(',', '');

    // Filter out non-financial messages like OTP, verification codes, login alerts
    if (lowerMsg.contains('otp') ||
        lowerMsg.contains('verification code') ||
        lowerMsg.contains('security code') ||
        lowerMsg.contains('do not share') ||
        lowerMsg.contains('secret code') ||
        lowerMsg.contains('one time password')) {
      return null;
    }

    // 1. Detect Payment App / Bank
    String detectedApp = 'Payment Alert';
    if (lowerMsg.contains('gpay') || lowerMsg.contains('google pay') || lowerMsg.contains('googlepay')) {
      detectedApp = 'Google Pay';
    } else if (lowerMsg.contains('phonepe') || lowerMsg.contains('phone pe')) {
      detectedApp = 'PhonePe';
    } else if (lowerMsg.contains('paytm')) {
      detectedApp = 'Paytm';
    } else if (lowerMsg.contains('cred')) {
      detectedApp = 'CRED';
    } else if (lowerMsg.contains('bhim') || lowerMsg.contains('upi')) {
      detectedApp = 'UPI App';
    } else if (lowerMsg.contains('hdfc')) {
      detectedApp = 'HDFC Bank';
    } else if (lowerMsg.contains('sbi')) {
      detectedApp = 'SBI Bank';
    } else if (lowerMsg.contains('icici')) {
      detectedApp = 'ICICI Bank';
    } else if (lowerMsg.contains('axis')) {
      detectedApp = 'Axis Bank';
    } else if (lowerMsg.contains('kotak')) {
      detectedApp = 'Kotak Bank';
    }

    // 2. Transaction Type (Expense vs Income)
    TransactionType type = TransactionType.expense;
    if (lowerMsg.contains('credited') ||
        lowerMsg.contains('received') ||
        lowerMsg.contains('deposited') ||
        lowerMsg.contains('refund') ||
        lowerMsg.contains('added')) {
      type = TransactionType.income;
    }

    // 3. Extract Amount with Multiple Fallbacks
    double amount = 0.0;

    // Pattern 1: Currency Symbol/Keyword followed by number (e.g. Rs 450, Rs.450, INR 1200, ₹450, paid 350, debited 500)
    final amountRegex1 = RegExp(
      r'(?:rs\.?|inr|₹|\$|paid|debited|spent|credited|amount|amt|vpa)\s*([\d]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final match1 = amountRegex1.firstMatch(cleanMsg);
    if (match1 != null && match1.group(1) != null) {
      amount = double.tryParse(match1.group(1)!) ?? 0.0;
    }

    // Pattern 2: Number followed by symbol/keyword (e.g. 450.00 INR, 1200 Rs)
    if (amount <= 0) {
      final amountRegex2 = RegExp(
        r'([\d]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹|\$|debited|credited|paid)',
        caseSensitive: false,
      );
      final match2 = amountRegex2.firstMatch(cleanMsg);
      if (match2 != null && match2.group(1) != null) {
        amount = double.tryParse(match2.group(1)!) ?? 0.0;
      }
    }

    // Pattern 3: Fallback first non-year standalone number
    if (amount <= 0) {
      final fallbackRegex = RegExp(r'\b\d+(?:\.\d{1,2})?\b');
      final matches = fallbackRegex.allMatches(cleanMsg);
      for (final m in matches) {
        final val = double.tryParse(m.group(0)!) ?? 0.0;
        if (val > 0 && val != 2026 && val != 2025 && val != 2024 && val < 1000000) {
          amount = val;
          break;
        }
      }
    }

    if (amount <= 0) return null;

    // 4. Payment Method
    String paymentMethod = 'UPI';
    if (lowerMsg.contains('credit card') || lowerMsg.contains('cc')) {
      paymentMethod = 'Credit Card';
    } else if (lowerMsg.contains('debit card') || lowerMsg.contains('dc')) {
      paymentMethod = 'Debit Card';
    } else if (lowerMsg.contains('bank transfer') || lowerMsg.contains('neft') || lowerMsg.contains('imps')) {
      paymentMethod = 'Bank Transfer';
    } else if (lowerMsg.contains('cash')) {
      paymentMethod = 'Cash';
    }

    // 5. Dynamic Merchant & Category Extraction
    String category = 'Others';
    String merchant = '$detectedApp Transaction';

    // Merchant extraction from "at <merchant>" or "to <merchant>" or "for <merchant>"
    final merchantRegex = RegExp(r'(?:at|to|for|vpa)\s+([A-Za-z0-9\s&]+?)(?=\s+(?:via|on|ref|using|from|by|link|bal|a/c|\.|$))', caseSensitive: false);
    final mMatch = merchantRegex.firstMatch(message);
    if (mMatch != null && mMatch.group(1) != null) {
      final extracted = mMatch.group(1)!.trim();
      if (extracted.isNotEmpty && extracted.length < 30) {
        merchant = extracted;
      }
    }

    if (lowerMsg.contains('swiggy') || lowerMsg.contains('zomato') || lowerMsg.contains('restaurant') || lowerMsg.contains('food') || lowerMsg.contains('cafe') || lowerMsg.contains('starbucks') || lowerMsg.contains('dominos') || lowerMsg.contains('mcdonald')) {
      category = 'Food';
    } else if (lowerMsg.contains('blinkit') || lowerMsg.contains('zepto') || lowerMsg.contains('instamart') || lowerMsg.contains('supermarket') || lowerMsg.contains('grocery') || lowerMsg.contains('mart') || lowerMsg.contains('bigbasket')) {
      category = 'Grocery';
    } else if (lowerMsg.contains('amazon') || lowerMsg.contains('flipkart') || lowerMsg.contains('myntra') || lowerMsg.contains('shopping') || lowerMsg.contains('ajio') || lowerMsg.contains('zara')) {
      category = 'Shopping';
    } else if (lowerMsg.contains('petrol') || lowerMsg.contains('fuel') || lowerMsg.contains('hpcl') || lowerMsg.contains('bpcl') || lowerMsg.contains('iocl') || lowerMsg.contains('uber') || lowerMsg.contains('ola') || lowerMsg.contains('rapido')) {
      category = 'Fuel';
    } else if (lowerMsg.contains('electric') || lowerMsg.contains('bill') || lowerMsg.contains('recharge') || lowerMsg.contains('jio') || lowerMsg.contains('airtel') || lowerMsg.contains('wifi') || lowerMsg.contains('rent')) {
      category = 'Bills';
    } else if (lowerMsg.contains('salary') || lowerMsg.contains('stipend')) {
      category = 'Salary';
    }

    return SMSParseResult(
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      paymentMethod: paymentMethod,
      originalMessage: message,
      detectedApp: detectedApp,
    );
  }
}
