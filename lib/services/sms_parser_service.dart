import '../models/transaction_model.dart';
import 'smart_categorizer_service.dart';

class SMSParseResult {
  final double amount;
  final TransactionType type;
  final String category;
  final String merchant;
  final String paymentMethod;
  final String originalMessage;
  final String detectedApp;
  final String? cardLast4;

  SMSParseResult({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.paymentMethod,
    required this.originalMessage,
    required this.detectedApp,
    this.cardLast4,
  });
}

class SMSParserService {
  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 1 — Sender-ID prefixes used ONLY by promotional/DND SMS senders.
  // Sender IDs starting with AD- / VM- / VK- are promo-category senders and
  // will NEVER carry real bank transaction alerts.
  // ─────────────────────────────────────────────────────────────────────────
  static const _promoSenderPrefixes = ['ad-', 'vm-', 'vk-', 'bp-', 'jd-'];

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 2 — Hard-block keywords.
  // If ANY of these appear in the message, it is NOT a real transaction.
  // ─────────────────────────────────────────────────────────────────────────
  static const _hardBlockKeywords = [
    // OTP / Security
    'otp', 'verification code', 'security code', 'do not share',
    'secret code', 'one time password', 'login attempt',

    // Offers / Discounts / Promotions
    'cashback offer', 'get flat', 'flat off', 'discount offer',
    'limited time', 'use code', 'promo code', 'coupon code',
    'click here', 'tap here', 'visit our', 'download the app',
    'avail offer', 'exclusive offer', 'special offer', 'today only',
    'offer valid', 'valid till', 'expires on', 'hurry',
    'win up to', 'earn up to', 'upto rs', 'upto inr',

    // Loan / Credit card offers (not actual disbursals)
    'pre-approved', 'pre approved', 'you are eligible',
    'check eligibility', 'apply now', 'get approved',
    'personal loan offer', 'credit limit offer',
    'increase your limit', 'credit card offer',

    // Reward / Points (not real money)
    'reward points', 'cashback will be', 'cashback credited within',
    'points earned', 'bonus points',

    // Marketing footers
    'to unsubscribe', 'to stop promotional',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 3 — REQUIRED action keywords.
  // At least ONE must be present — without a real action verb the SMS is NOT
  // a confirmed transaction (could be a balance check, offer, or reminder).
  //
  // Bank-standard ABBREVIATIONS are also included here:
  //   Dr. = Debit (used by BOB, SBI, Kotak, PNB, Canara, UCO, etc.)
  //   Cr. = Credit
  //   debit: / credit: prefix (HDFC, Axis variants)
  // ─────────────────────────────────────────────────────────────────────────
  static const _requiredActionKeywords = [
    // Full-word debit verbs
    'debited', 'deducted', 'spent', 'paid', 'payment done',
    'payment of', 'purchase of', 'withdrawn', 'transferred to',
    'sent to', 'sent', 'charged', 'auto debited', 'debit',
    // Full-word credit verbs
    'credited', 'received', 'deposited', 'salary credited',
    'refund of', 'refunded', 'amount added', 'money added',
    'transfer received', 'has sent you', 'has transferred',
    'credit of', 'credit with', 'credited with', 'credited by',
    'credited to', 'credited for', 'credited in', 'cashback credited',
    'cashback of', 'cashback received', 'credit:', 'credit',
    'money received', 'fund received', 'amount received',
    'inward transfer', 'neft credit', 'imps credit', 'upi credit',
    // Bank-standard shorthand abbreviations (BOB, SBI, Kotak, PNB, Canara, etc.)
    ' dr.', ' cr.',        // " Dr. from A/C", " Cr. to VPA"
    'dr. from', 'cr. to',  // more specific BOB/SBI patterns
    'debit:', 'credit:',   // HDFC / Axis colon-prefix style
    'dr ', 'cr ', 'cr.', 'dr.',
    'amount debited', 'amount credited', 'ac credited', 'a/c credited',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 4 — Contextual false-positive guards.
  // Even if a required action keyword exists, these phrases indicate the
  // transaction has NOT completed yet (future/scheduled/marketing context).
  // ─────────────────────────────────────────────────────────────────────────
  static const _contextBlockKeywords = [
    'due on', 'due date', 'minimum due',
    'statement', 'bill generated',
    'will be debited', 'will be charged',
    'scheduled for', 'auto-renewal', 'auto renewal',
    'get rs', 'earn rs', 'save rs', 'win rs',
  ];

  /// Strict SMS parser — only accepts genuine debit/credit transaction SMS.
  ///
  /// [senderAddress] is the optional sender ID (e.g. "AD-HDFCBK", "BN-SBIIN").
  /// Passing it enables sender-based promotional filtering.
  static SMSParseResult? parseSMS(String message, {String? senderAddress}) {
    if (message.trim().isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Strip the "AvlBal:", "Avl Bal:", "Bal:", "Balance:" suffix before amount
    // extraction so the account balance never gets picked up as the transaction
    // amount. Bank SMS format:  Rs.100.00 Dr. … AvlBal:Rs21048.53
    final balanceStripRegex = RegExp(
      r'(?:avlbal|avl\s*bal|available\s*bal(?:ance)?|total\s*bal(?:ance)?|bal(?:ance)?)[:\s]*(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?',
      caseSensitive: false,
    );
    final msgForAmount = message.replaceAll(balanceStripRegex, '');
    final cleanMsg = msgForAmount.replaceAll(',', '');

    // ── LAYER 1: Sender-ID promotion filter ──────────────────────────────────
    if (senderAddress != null) {
      final lowerSender = senderAddress.toLowerCase();
      for (final prefix in _promoSenderPrefixes) {
        if (lowerSender.startsWith(prefix)) return null;
      }
    }

    // ── LAYER 2: Hard-block promo/security keywords ──────────────────────────
    for (final kw in _hardBlockKeywords) {
      if (lowerMsg.contains(kw)) return null;
    }

    // ── LAYER 3: Require at least one confirmed financial action verb ─────────
    final hasAction =
        _requiredActionKeywords.any((kw) => lowerMsg.contains(kw));
    if (!hasAction) return null;

    // ── LAYER 4: Contextual false-positive guard ───────────────────────────
    for (final kw in _contextBlockKeywords) {
      if (lowerMsg.contains(kw)) return null;
    }

    // ── LAYER 5: Robust Amount Extraction ────────────────────────────────────
    double amount = 0.0;

    // Pattern 1: Currency symbol prefix -> e.g. "Rs. 2500", "INR 1200.50", "₹500", "Rs 5,000"
    final regexCurrencyPrefix = RegExp(
      r'(?:rs\.?|inr|₹|\$)\s*([\d]+(?:\.[\d]{1,2})?)',
      caseSensitive: false,
    );
    final match1 = regexCurrencyPrefix.firstMatch(cleanMsg);
    if (match1 != null && match1.group(1) != null) {
      amount = double.tryParse(match1.group(1)!) ?? 0.0;
    }

    // Pattern 2: Financial action verb followed by optional connector words (by/with/for/of/to/in/rs/inr/₹) and digits
    // e.g. "credited by Rs 2500", "credited with INR 1200", "received Rs 500", "credited for 350"
    if (amount <= 0) {
      final regexActionPrefix = RegExp(
        r'(?:debited|credited|received|deposited|paid|refunded|transferred|added|payment|refund|amount|cashback)\s+(?:by|with|for|of|to|in|a\/c|ac|rs\.?|inr|₹|\$|\s)*\s*([\d]+(?:\.[\d]{1,2})?)',
        caseSensitive: false,
      );
      final match2 = regexActionPrefix.firstMatch(cleanMsg);
      if (match2 != null && match2.group(1) != null) {
        amount = double.tryParse(match2.group(1)!) ?? 0.0;
      }
    }

    // Pattern 3: Digits followed by currency symbol or credit/debit keyword
    // e.g. "2500.00 INR", "1200 Rs", "500.00 credited", "450 debited"
    if (amount <= 0) {
      final regexSuffix = RegExp(
        r'([\d]+(?:\.[\d]{1,2})?)\s*(?:rs\.?|inr|₹|\$|credited|debited|received|deposited|cr\.?|dr\.?)',
        caseSensitive: false,
      );
      final match3 = regexSuffix.firstMatch(cleanMsg);
      if (match3 != null && match3.group(1) != null) {
        amount = double.tryParse(match3.group(1)!) ?? 0.0;
      }
    }

    // Minimum floor — ignore amounts < ₹1
    if (amount < 1.0) return null;

    // ── Detect Payment App / Bank ─────────────────────────────────────────
    String detectedApp = 'Bank Alert';
    if (lowerMsg.contains('gpay') || lowerMsg.contains('google pay') || lowerMsg.contains('googlepay')) {
      detectedApp = 'Google Pay';
    } else if (lowerMsg.contains('phonepe') || lowerMsg.contains('phone pe')) {
      detectedApp = 'PhonePe';
    } else if (lowerMsg.contains('paytm')) {
      detectedApp = 'Paytm';
    } else if (lowerMsg.contains('cred')) {
      detectedApp = 'CRED';
    } else if (lowerMsg.contains('bhim')) {
      detectedApp = 'BHIM UPI';
    } else if (lowerMsg.contains('hdfc')) {
      detectedApp = 'HDFC Bank';
    } else if (lowerMsg.contains('sbi') || lowerMsg.contains('state bank')) {
      detectedApp = 'SBI Bank';
    } else if (lowerMsg.contains('icici')) {
      detectedApp = 'ICICI Bank';
    } else if (lowerMsg.contains('axis')) {
      detectedApp = 'Axis Bank';
    } else if (lowerMsg.contains('kotak')) {
      detectedApp = 'Kotak Bank';
    } else if (lowerMsg.contains('pnb') || lowerMsg.contains('punjab national')) {
      detectedApp = 'PNB Bank';
    } else if (lowerMsg.contains('bank of baroda') || lowerMsg.contains(' bob ') || lowerMsg.contains('-bob')) {
      detectedApp = 'Bank of Baroda';
    } else if (lowerMsg.contains('indusind')) {
      detectedApp = 'IndusInd Bank';
    } else if (lowerMsg.contains('yes bank') || lowerMsg.contains('yesbank')) {
      detectedApp = 'Yes Bank';
    } else if (lowerMsg.contains('federal bank') || lowerMsg.contains('fedbank')) {
      detectedApp = 'Federal Bank';
    } else if (lowerMsg.contains('rbl bank') || lowerMsg.contains('ratnakar')) {
      detectedApp = 'RBL Bank';
    } else if (lowerMsg.contains('idfc') || lowerMsg.contains('idfcfirst')) {
      detectedApp = 'IDFC First Bank';
    } else if (lowerMsg.contains('bandhan')) {
      detectedApp = 'Bandhan Bank';
    } else if (lowerMsg.contains('utkarsh') || lowerMsg.contains('sfbl')) {
      detectedApp = 'Utkarsh Bank';
    } else if (lowerMsg.contains('au small') || lowerMsg.contains('au bank') || lowerMsg.contains('ausf')) {
      detectedApp = 'AU Small Finance Bank';
    } else if (lowerMsg.contains('equitas')) {
      detectedApp = 'Equitas Bank';
    } else if (lowerMsg.contains('ujjivan')) {
      detectedApp = 'Ujjivan Bank';
    } else if (lowerMsg.contains('canara')) {
      detectedApp = 'Canara Bank';
    } else if (lowerMsg.contains('union bank') || lowerMsg.contains('unionbank')) {
      detectedApp = 'Union Bank';
    } else if (lowerMsg.contains('bank of india') || lowerMsg.contains(' boi ')) {
      detectedApp = 'Bank of India';
    } else if (lowerMsg.contains('central bank')) {
      detectedApp = 'Central Bank of India';
    } else if (lowerMsg.contains('indian bank')) {
      detectedApp = 'Indian Bank';
    } else if (lowerMsg.contains('uco bank')) {
      detectedApp = 'UCO Bank';
    } else if (lowerMsg.contains('dcb bank') || lowerMsg.contains('development credit')) {
      detectedApp = 'DCB Bank';
    } else if (lowerMsg.contains('upi')) {
      detectedApp = 'UPI Payment';
    }

    // ── Transaction Type ──────────────────────────────────────────────────
    TransactionType type = TransactionType.expense;

    final hasCreditVerb = RegExp(
      r'(?:credited|credited\s+with|credited\s+by|credited\s+to|credited\s+in|credited\s+into|credited\s+for|a\/c\s+credited|account\s+credited|received|deposited|salary|refund|refunded|cashback|inward|added\s+to|sent\s+you|transfer\s+received|money\s+received|fund\s+received|payment\s+received|cr\.?\s+to|cr\.?\s+in|cr\.?\s+for|cr\.?\s+by|credit\s+of|credit\s+with|credit:|\bcr\.?\b)',
      caseSensitive: false,
    ).hasMatch(lowerMsg);

    final hasDebitVerb = RegExp(
      r'(?:debited|debited\s+from|debited\s+for|deducted|spent|paid\s+to|paid\s+for|purchase|purchased|withdrawn|charged|dr\.?\s+from|dr\.?\s+to\s+vpa|dr\s+from|debit:|\bdr\.?\b)',
      caseSensitive: false,
    ).hasMatch(lowerMsg);

    if (hasCreditVerb && !hasDebitVerb) {
      type = TransactionType.income;
    } else if (hasCreditVerb && hasDebitVerb) {
      // Both verbs matched (e.g. "Rs 500 credited to A/c for payment received")
      final creditIdx = lowerMsg.indexOf(RegExp(
        r'(?:credited|received|deposited|salary|refund|cashback|cr\.?\s+to|cr\.?\s+in|credit:)',
        caseSensitive: false,
      ));
      final debitIdx = lowerMsg.indexOf(RegExp(
        r'(?:debited|spent|purchase|withdrawn|dr\.?\s+from|debit:)',
        caseSensitive: false,
      ));
      if (creditIdx != -1 && (debitIdx == -1 || creditIdx < debitIdx)) {
        type = TransactionType.income;
      }
    }

    // ── Payment Method ────────────────────────────────────────────────────
    // Credit card detection — check for card-number pattern first:
    //   "SuperCard 2235 debited"         → supercard + digits
    //   "Card ending 2235"               → ending + digits  
    //   "SuperCard ending with 2235"      → ending with + digits  (NEW)
    //   "card ending in 2235"            → ending in + digits    (NEW)
    // This runs BEFORE the UPI check because credit cards can be used via UPI.
    final cardNumberPattern = RegExp(
      r'(?:card|supercard|creditcard|credit card|rupay|visa|mastercard|amex|diners)'
      r'\s*(?:no\.?|number|ending(?:\s+(?:with|in))?|xx+|x+)?\s*(\d{4})',
      caseSensitive: false,
    );
    final cardMatch = cardNumberPattern.firstMatch(message);
    final cardLast4 = cardMatch?.group(1); // e.g. "2235"

    final isDebitCardPattern = RegExp(
      r'(?:debit card|dc card|atm card)',
      caseSensitive: false,
    ).hasMatch(message);

    // UPI VPA pattern: word@bankshortcode (e.g. anamikasingh@oksbi, raj@ybl)
    final hasUpiVpa = RegExp(
      r'\w+@(?:oksbi|okaxis|okhdfcbank|ybl|upi|paytm|apl|waicici|ibl|sbi|hdfc|icici|federal|rbl|indus|bandhan)',
      caseSensitive: false,
    ).hasMatch(message);

    // ── CC Refund detection ───────────────────────────────────────────────
    // "credited to your SuperCard", "refund...credit card" etc.
    // When money is credited BACK to the CC (not bank), it must be tagged
    // as paymentMethod = 'Credit Card' so the CC widget can subtract it from
    // the card's spent total.  Without this, it defaults to 'Bank Transfer'
    // and the CC balance never decreases.
    final isCcRefundToCard = RegExp(
      r'(?:credited|refund)[^.]{0,60}(?:supercard|credit card|creditcard|card ending|card no)',
      caseSensitive: false,
    ).hasMatch(message);

    // ── CC Bill Payment detection ─────────────────────────────────────────
    // Matches bank/CC-company SMS confirming that a bill payment was received
    // TOWARDS the credit card — e.g.:
    //   "Payment of Rs 5000 received for your HDFC SuperCard 2235"
    //   "Rs 10000 credited to your SBI Credit Card account"
    //   "Thank you for payment of INR 8000 towards ICICI Bank Card"
    //   "CRED: Rs 3000 paid towards your Axis Credit Card"
    //   "Your credit card payment of Rs 5000 has been processed"
    final isCcBillPayment = RegExp(
      r'(?:'                                           // open outer group
      r'payment\s+(?:of\s+)?(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?\s*'
        r'(?:received|processed|credited|confirmed|successful|accepted)\s*'
        r'(?:towards?|for|against|to)?\s*'
        r'(?:your\s+)?(?:credit card|cc|supercard|card|creditcard)'  // card mention
      r'|'                                             // OR
      r'(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?'
        r'\s+(?:credited|received|processed)\s+'
        r'(?:towards?|for|against|to)?\s*'
        r'(?:your\s+)?(?:credit card|cc|supercard|creditcard)'       // card mention
      r'|'                                             // OR
      r'thank(?:s|\s+you)?\s+for\s+(?:the\s+)?payment'
        r'[^.]{0,80}'
        r'(?:credit card|supercard|cc\s+card|creditcard|card ending|card no\.?\s*\d{4})'
      r'|'                                             // OR
      r'(?:credit card|supercard)\s+(?:bill\s+)?payment\s+'
        r'(?:of\s+)?(?:rs\.?|inr|₹)?\s*[\d,]+'
        r'\s*(?:has\s+been\s+)?(?:processed|received|successful|credited|accepted)'
      r'|'                                             // OR — CRED/app style
      r'paid\s+(?:rs\.?|inr|₹)?\s*[\d,]+[^.]{0,60}'
        r'(?:credit card|cc\s+card|supercard|card\s+ending|card\s+no)'
      r')',
      caseSensitive: false,
    ).hasMatch(message);

    String paymentMethod;
    if (isDebitCardPattern) {
      paymentMethod = 'Debit Card';
    } else if (isCcBillPayment || isCcRefundToCard || (cardLast4 != null && !isDebitCardPattern)) {
      // CC bill payment, refund to CC, or any card-number found → tag as Credit Card
      paymentMethod = 'Credit Card';
    } else if (lowerMsg.contains('credit card') || lowerMsg.contains(' cc ')) {
      paymentMethod = 'Credit Card';
    } else if (lowerMsg.contains('debit card') || lowerMsg.contains(' dc ')) {
      paymentMethod = 'Debit Card';
    } else if (lowerMsg.contains('neft') || lowerMsg.contains('imps')) {
      paymentMethod = 'Bank Transfer';
    } else if (lowerMsg.contains('upi') || hasUpiVpa) {
      paymentMethod = 'UPI';
    } else if (lowerMsg.contains('cash')) {
      paymentMethod = 'Cash';
    } else {
      paymentMethod = 'Bank Transfer';
    }

    // ── Merchant & Category ───────────────────────────────────────────────
    String category = type == TransactionType.income ? 'Other Income' : 'Others';

    // Override category immediately for CC bill payment SMS before smart categorizer
    if (isCcBillPayment && type == TransactionType.income) {
      category = 'Credit Card Payment';
    }

    String merchant = cardLast4 != null
        ? '$detectedApp Card ••$cardLast4'
        : detectedApp;

    final merchantRegex = RegExp(
      r'(?:at|to|for|vpa)\s+([A-Za-z0-9\s&]+?)(?=\s+(?:via|on|ref|using|from|by|link|bal|a\/c|\.|$))',
      caseSensitive: false,
    );
    final mMatch = merchantRegex.firstMatch(message);
    if (mMatch?.group(1) != null) {
      final extracted = mMatch!.group(1)!.trim();
      if (extracted.isNotEmpty && extracted.length < 30) {
        if (cardLast4 != null) {
          merchant = '$extracted ($detectedApp Card ••$cardLast4)';
        } else if (detectedApp != 'Bank Alert' && detectedApp != 'UPI Payment') {
          merchant = '$extracted ($detectedApp)';
        } else {
          merchant = extracted;
        }
      }
    }

    // Smart categorizer — skip if category is already pinned (CC bill payment)
    if (category != 'Credit Card Payment') {
      final smartCat = SmartCategorizerService.predictCategory(
        message,
        isExpense: type == TransactionType.expense,
      );
      if (smartCat != null) {
        category = smartCat;
      }
    }

    return SMSParseResult(
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      paymentMethod: paymentMethod,
      originalMessage: message,
      detectedApp: detectedApp,
      cardLast4: cardLast4,
    );
  }
}
