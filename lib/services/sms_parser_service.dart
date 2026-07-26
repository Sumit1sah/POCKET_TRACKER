import '../models/transaction_model.dart';

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
    'sent to', 'sent', 'charged', 'auto debited',
    // Full-word credit verbs
    'credited', 'received', 'deposited', 'salary credited',
    'refund of', 'refunded', 'amount added', 'money added',
    'transfer received',
    // Bank-standard shorthand abbreviations (BOB, SBI, Kotak, PNB, etc.)
    ' dr.', ' cr.',        // " Dr. from A/C", " Cr. to VPA"
    'dr. from', 'cr. to',  // more specific BOB/SBI patterns
    'debit:', 'credit:',   // HDFC / Axis colon-prefix style
    'dr ', 'cr ',          // without dot (some banks omit it)
    'amount debited', 'amount credited',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 4 — Contextual false-positive guards.
  // Even if a required action keyword exists, these phrases indicate the
  // transaction has NOT completed yet (future/scheduled/marketing context).
  // ─────────────────────────────────────────────────────────────────────────
  static const _contextBlockKeywords = [
    'due on', 'due date', 'minimum due', 'outstanding',
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
      r'(?:avlbal|avl\s*bal|available\s*bal(?:ance)?|bal(?:ance)?)[:\s]*rs\.?\s*[\d,]+(?:\.\d{1,2})?',
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

    // ── LAYER 5: Extract amount ──────────────────────────────────────────────
    // Only strict patterns (amount near currency symbol/keyword).
    // The old "blind number fallback" is intentionally removed — it caused
    // any SMS with a number (PIN, phone no, date) to be flagged.
    double amount = 0.0;

    // Pattern A: currency keyword → number  e.g. Rs 450, ₹1200, debited 500
    final regexA = RegExp(
      r'(?:rs\.?|inr|₹|\$|debited|credited|paid|payment of|refund of|amount of)\s*([\d]+(?:\.[\d]{1,2})?)',
      caseSensitive: false,
    );
    final matchA = regexA.firstMatch(cleanMsg);
    if (matchA != null && matchA.group(1) != null) {
      amount = double.tryParse(matchA.group(1)!) ?? 0.0;
    }

    // Pattern B: number → currency keyword  e.g. 450.00 INR, 1200 Rs
    if (amount <= 0) {
      final regexB = RegExp(
        r'([\d]+(?:\.[\d]{1,2})?)\s*(?:rs\.?|inr|₹|\$)',
        caseSensitive: false,
      );
      final matchB = regexB.firstMatch(cleanMsg);
      if (matchB != null && matchB.group(1) != null) {
        amount = double.tryParse(matchB.group(1)!) ?? 0.0;
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
    // Default: expense. Switch to income only for genuine credit-to-user signals.
    //
    // For Dr./Cr. shorthand SMS (e.g., BOB):  "Rs.100 Dr. from A/C XXX Cr. to VPA"
    //   → Dr. = money left OUR account → EXPENSE
    //   → Both Dr. and Cr. present means we sent money (expense)
    // For pure Cr. SMS (income):  "Rs.5000 Cr. to A/C XXXX from employer"
    //   → only Cr. present → INCOME
    TransactionType type = TransactionType.expense;
    final hasDebitAbbr = lowerMsg.contains(' dr.') || lowerMsg.contains('dr. from') || lowerMsg.contains(' dr ');
    final hasCreditAbbr = lowerMsg.contains(' cr.') || lowerMsg.contains('cr. to') || lowerMsg.contains(' cr ');
    const incomeWords = [
      'credited', 'received', 'deposited', 'refund', 'added',
      'transfer received', 'salary credited',
    ];
    final hasIncomeWord = incomeWords.any((w) => lowerMsg.contains(w));
    // Income only when credit signal exists WITHOUT a simultaneous debit signal
    if (hasIncomeWord && !hasDebitAbbr) {
      type = TransactionType.income;
    } else if (hasCreditAbbr && !hasDebitAbbr) {
      // Pure " Cr." without " Dr." = money came INTO our account
      type = TransactionType.income;
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

    String paymentMethod;
    if (isDebitCardPattern) {
      paymentMethod = 'Debit Card';
    } else if (isCcRefundToCard || (cardLast4 != null && !isDebitCardPattern)) {
      // Refund to CC  OR  a card-number was found and it's not a debit card
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
    } else if (hasUpiVpa) {
      paymentMethod = 'UPI';
    } else {
      paymentMethod = 'Bank Transfer';
    }

    // ── Merchant & Category ───────────────────────────────────────────────
    String category = 'Others';
    String merchant = cardLast4 != null
        ? '$detectedApp Card ••$cardLast4'
        : '$detectedApp';

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

    if (lowerMsg.contains('swiggy') || lowerMsg.contains('zomato') ||
        lowerMsg.contains('restaurant') || lowerMsg.contains('food') ||
        lowerMsg.contains('cafe') || lowerMsg.contains('starbucks') ||
        lowerMsg.contains('dominos') || lowerMsg.contains('mcdonald')) {
      category = 'Food';
    } else if (lowerMsg.contains('blinkit') || lowerMsg.contains('zepto') ||
        lowerMsg.contains('instamart') || lowerMsg.contains('supermarket') ||
        lowerMsg.contains('grocery') || lowerMsg.contains('bigbasket')) {
      category = 'Grocery';
    } else if (lowerMsg.contains('amazon') || lowerMsg.contains('flipkart') ||
        lowerMsg.contains('myntra') || lowerMsg.contains('shopping') ||
        lowerMsg.contains('ajio') || lowerMsg.contains('meesho')) {
      category = 'Shopping';
    } else if (lowerMsg.contains('petrol') || lowerMsg.contains('fuel') ||
        lowerMsg.contains('hpcl') || lowerMsg.contains('bpcl') ||
        lowerMsg.contains('iocl') || lowerMsg.contains('uber') ||
        lowerMsg.contains('ola') || lowerMsg.contains('rapido')) {
      category = 'Fuel';
    } else if (lowerMsg.contains('electric') || lowerMsg.contains('electricity') ||
        lowerMsg.contains('bill') || lowerMsg.contains('recharge') ||
        lowerMsg.contains('jio') || lowerMsg.contains('airtel') ||
        lowerMsg.contains('wifi') || lowerMsg.contains('broadband')) {
      category = 'Bills';
    } else if (lowerMsg.contains('rent')) {
      category = 'Rent';
    } else if (lowerMsg.contains('salary') || lowerMsg.contains('stipend')) {
      category = 'Salary';
    } else if (lowerMsg.contains('repay') || lowerMsg.contains('repayment') ||
        lowerMsg.contains('return money') || lowerMsg.contains('returned money') ||
        lowerMsg.contains('lent') || lowerMsg.contains('borrowed')) {
      category = 'Debt / Repayment';
    } else if (lowerMsg.contains('medical') || lowerMsg.contains('hospital') ||
        lowerMsg.contains('pharmacy') || lowerMsg.contains('doctor') ||
        lowerMsg.contains('apollo') || lowerMsg.contains('practo')) {
      category = 'Medical';
    } else if (lowerMsg.contains('school') || lowerMsg.contains('college') ||
        lowerMsg.contains('university') || lowerMsg.contains('fees') ||
        lowerMsg.contains('course')) {
      category = 'Education';
    } else if (lowerMsg.contains('movie') || lowerMsg.contains('netflix') ||
        lowerMsg.contains('hotstar') || lowerMsg.contains('spotify') ||
        lowerMsg.contains('prime')) {
      category = 'Entertainment';
    } else if (lowerMsg.contains('travel') || lowerMsg.contains('flight') ||
        lowerMsg.contains('irctc') || lowerMsg.contains('train') ||
        lowerMsg.contains('hotel') || lowerMsg.contains('booking')) {
      category = 'Travel';
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
