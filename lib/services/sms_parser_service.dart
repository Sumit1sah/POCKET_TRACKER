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
  // Note: Standard TRAI 2-letter operator circle codes (AD-, VM-, VK-, BP-, JD-)
  // are attached to all bank transaction headers in India (e.g. AD-BOBTXN, VM-SBIIN).
  // ─────────────────────────────────────────────────────────────────────────
  static const _promoSenderPrefixes = ['promo-', 'dnd-'];

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
    'hurry',
    'win up to', 'earn up to', 'upto rs', 'upto inr', 'up to rs', 'up to inr',

    // Loan / Credit card offers (not actual disbursals)
    'pre-approved', 'pre approved', 'you are eligible',
    'check eligibility', 'apply now', 'get approved',
    'personal loan offer', 'credit limit offer',
    'increase your limit', 'credit card offer',

    // Reward / Points (not real money)
    // NOTE: keep these specific — some CC cashback SMS mention "reward points" as
    // bonus info alongside a real credited amount (e.g. "Rs 200 cashback credited.
    // 50 reward points also added."). Only block if the SMS is ONLY about points.
    'cashback will be',
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
    // Full-word debit verbs & ATM / Auto-debit / Transfer keywords
    'debited', 'deducted', 'spent', 'paid', 'payment done',
    'payment of', 'purchase of', 'withdrawn', 'transferred to',
    'sent to', 'sent', 'charged', 'auto debited', 'auto-debited', 'debit',
    'atm wdl', 'atm withdrawal', 'cash withdrawn', 'withdrawn at atm', 'atm cash', 'cash wdl',
    'pos transaction', 'pos txn', 'pos purchase', 'ecom transaction', 'ecom txn', 'swiped at', 'swiped for', 'spent on card',
    'ecs debit', 'nach debit', 'mandate debited', 'standing instruction',
    'neft dr', 'imps dr', 'rtgs dr', 'neft debit', 'imps debit', 'rtgs debit',
    'added to wallet', 'wallet debited', 'wallet loaded',
    // Passive-voice debit (BOB / SBI / PNB format: "A/c XX1234 is Debited by Rs.500")
    'is debited', 'has been debited', 'a/c debited', 'ac debited', 'account debited',
    // ── Credit Card purchase verbs (most commonly missed) ─────────────────
    // HDFC CC: "Your HDFC Bank Credit Card XX 1234 has been used for Rs 5000 at AMAZON"
    'has been used', 'been used',
    // ICICI / Axis CC: "ICICI Credit Card XX1234 used at SWIGGY for Rs.500"
    'used at', 'used for', 'used on',
    // SBI Card: "Your SBI Credit Card has been availed for Rs.2000 at FLIPKART"
    'availed', 'has been availed',
    // Generic CC purchase phrases
    'purchase made', 'purchase at', 'purchase for',
    'transaction made', 'tran of', 'txn of', 'txn at', 'txn for',
    // Full-word credit verbs & reversals
    'credited', 'received', 'deposited', 'salary credited',
    'refund of', 'refunded', 'reversal of', 'reversed', 'txn reversed',
    'amount added', 'money added', 'wallet credit',
    'transfer received', 'has sent you', 'has transferred',
    'credit of', 'credit with', 'credited with', 'credited by',
    'credited to', 'credited for', 'credited in', 'cashback credited',
    'cashback of', 'cashback received', 'credit:', 'credit',
    'money received', 'fund received', 'amount received',
    'inward transfer', 'neft credit', 'imps credit', 'rtgs credit', 'upi credit',
    // Passive-voice credit (formal bank style)
    'is credited', 'has been credited', 'a/c credited', 'ac credited', 'account credited',
    // Bank-standard shorthand abbreviations (BOB, SBI, Kotak, PNB, Canara, etc.)
    ' dr.', ' cr.',        // " Dr. from A/C", " Cr. to VPA"
    'dr. from', 'cr. to',  // more specific BOB/SBI patterns
    'debit:', 'credit:',   // HDFC / Axis colon-prefix style
    'dr ', 'cr ', 'cr.', 'dr.',
    // Kotak / Yes Bank without dot: "INR 1000 Dr from your Kotak A/c"
    'dr from', 'cr to', 'cr from',
    'amount debited', 'amount credited',
    // Transaction-style phrases used by some private banks
    'transaction of', 'transaction for', 'transfer of',
    'upi debit', 'upi txn', 'paid via upi', 'received via upi',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 4 — Contextual false-positive guards.
  // Even if a required action keyword exists, these phrases indicate the
  // transaction has NOT completed yet (future/scheduled/marketing context).
  //
  // IMPORTANT: 'due on', 'due date', 'minimum due' are only blocked when the
  // SMS is NOT a CC bill payment confirmation.  Many banks append "Next due
  // date: Sep 15" or "Min due: ₹0" to a payment-received confirmation — those
  // must NOT be rejected.
  // ─────────────────────────────────────────────────────────────────────────

  // Keywords that indicate a future/unprocessed event — always block these.
  static const _contextBlockKeywords = [
    // "statement" alone is too broad — Axis/ICICI CC purchase SMS sometimes append
    // "Avl Stmt Bal" or "Outstanding Stmt Bal" as secondary info.
    // Block only the actual billing statement notification phrases:
    'statement generated', 'monthly statement', 'card statement',
    'billing statement', 'e-statement',
    'bill generated',
    'will be debited', 'will be charged',
    'scheduled for', 'auto-renewal', 'auto renewal',
    'get rs', 'earn rs', 'save rs', 'win rs',
  ];

  // 'due'-related keywords that are ONLY blocked when the SMS is not a
  // CC bill payment confirmation (e.g. pure billing reminders).
  static const _dueContextBlockKeywords = [
    'due on', 'due date', 'minimum due',
  ];

  // A CC bill payment confirmation phrase — if this matches we know the
  // payment was already processed and 'due date' appears only as trailing info.
  static final _ccPaymentConfirmedPattern = RegExp(
    r'(?:'
    r'payment\s+(?:of\s+)?(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?\s*'
      r'(?:received|processed|credited|confirmed|successful|accepted)'
    r'|'
    r'(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?\s*'
      r'(?:credited|received|processed)\s+'
      r'(?:towards?|for|against|to)?\s*'
      r'(?:your\s+)?(?:credit card|cc|supercard|card)'
    r'|'
    r'thank(?:s|\s+you)?\s+for\s+(?:the\s+)?payment'
    r'|'
    r'(?:credit card|supercard|card)\s+(?:bill\s+)?payment\s+'
      r'(?:of\s+)?(?:rs\.?|inr|₹)?\s*[\d,]+'
      r'\s*(?:has\s+been\s+)?(?:processed|received|successful|credited|accepted)'
    r'|'   // Utkarsh/SFBL: "received payment of INR X for your SuperCard"
    r'(?:have\s+)?received\s+payment\s+(?:of\s+)?(?:rs\.?|inr|₹|\$)?\s*[\d,]+'
      r'[^.]{0,60}(?:credit card|cc|supercard|card|creditcard)'
    r')',
    caseSensitive: false,
  );

  /// Strict SMS parser — only accepts genuine debit/credit transaction SMS.
  ///
  /// [senderAddress] is the optional sender ID (e.g. "AD-HDFCBK", "BN-SBIIN").
  /// Passing it enables sender-based promotional filtering.
  static SMSParseResult? parseSMS(String message, {String? senderAddress}) {
    if (message.trim().isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Strip the "AvlBal:", "Avl Bal:", "Bal:", "Balance:", "available limit" suffix before
    // amount extraction so the account balance/limit never gets picked up as the
    // transaction amount. Bank SMS format:  Rs.100.00 Dr. … AvlBal:Rs21048.53
    // Utkarsh/SuperCard format: "Your available limit is now INR 13,530.92"
    final balanceStripRegex = RegExp(
      r'(?:avlbal|avl\s*bal|available\s*bal(?:ance)?|available\s*(?:credit\s*)?limit|total\s*bal(?:ance)?|bal(?:ance)?)[:\s]*(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?',
      caseSensitive: false,
    );
    final msgForAmount = message.replaceAll(balanceStripRegex, '');
    final cleanMsg = msgForAmount.replaceAll(',', '').replaceAll('/-', '');

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

    // Apply 'due'-related blocks ONLY when the SMS is not a CC payment
    // confirmation.  Payment confirmation SMS often appends "Next due date:"
    // or "Min due: ₹0" as trailing info and must NOT be rejected.
    final isCcPaymentConfirmed = _ccPaymentConfirmedPattern.hasMatch(lowerMsg);
    if (!isCcPaymentConfirmed) {
      for (final kw in _dueContextBlockKeywords) {
        if (lowerMsg.contains(kw)) return null;
      }
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
    // Also matches passive: "is debited by Rs 500", "has been credited with INR 1000"
    if (amount <= 0) {
      final regexActionPrefix = RegExp(
        r'(?:debited|credited|received|deposited|paid|refunded|transferred|added|payment|refund|amount|cashback|transaction|transfer)'
        r'\s+(?:is\s+|has\s+been\s+)?'
        r'(?:by|with|for|of|to|in|a\/c|ac|rs\.?|inr|₹|\$|\s)*\s*([\d]+(?:\.[\d]{1,2})?)',
        caseSensitive: false,
      );
      final match2 = regexActionPrefix.firstMatch(cleanMsg);
      if (match2 != null && match2.group(1) != null) {
        amount = double.tryParse(match2.group(1)!) ?? 0.0;
      }
    }

    // Pattern 2b: "is Debited by Rs.500" / "is Credited with INR 1000" (BOB/SBI passive style)
    // The verb comes AFTER "is" but before the currency
    if (amount <= 0) {
      final regexPassive = RegExp(
        r'is\s+(?:debited|credited)\s+(?:by|with|for|of)?\s*(?:rs\.?|inr|₹|\$)?\s*([\d]+(?:\.[\d]{1,2})?)',
        caseSensitive: false,
      );
      final matchPassive = regexPassive.firstMatch(cleanMsg);
      if (matchPassive != null && matchPassive.group(1) != null) {
        amount = double.tryParse(matchPassive.group(1)!) ?? 0.0;
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

    // Pattern 4: Amount keyword prefix -> e.g. "Amt: 500", "Amount: Rs 1,200", "Sum: 350"
    if (amount <= 0) {
      final regexAmtKeyword = RegExp(
        r'(?:amt|amount|sum|value|val|price)[:\s]*(?:rs\.?|inr|₹|\$)?\s*([\d]+(?:\.[\d]{1,2})?)',
        caseSensitive: false,
      );
      final matchAmt = regexAmtKeyword.firstMatch(cleanMsg);
      if (matchAmt != null && matchAmt.group(1) != null) {
        amount = double.tryParse(matchAmt.group(1)!) ?? 0.0;
      }
    }

    // Minimum floor — ignore amounts < ₹1
    if (amount < 1.0) return null;

    final lowerSender = senderAddress?.toLowerCase() ?? '';
    // Strip VPA handles (e.g. user@oksbi, merchant@okhdfcbank) from message body copy
    // so receiver VPA domains don't confuse bank detection.
    final msgWithoutVpa = lowerMsg.replaceAll(RegExp(r'\b[\w.]+@\w+\b'), '');

    // ── Detect Payment App / Bank ─────────────────────────────────────────
    String detectedApp = 'Bank Alert';

    // Step 1: Check Sender ID FIRST (authoritative for origin bank)
    if (lowerSender.contains('bob') || lowerSender.contains('baroda')) {
      detectedApp = 'Bank of Baroda';
    } else if (lowerSender.contains('sbi') || lowerSender.contains('sbiin') || lowerSender.contains('sbicrd')) {
      detectedApp = 'SBI Bank';
    } else if (lowerSender.contains('hdfc')) {
      detectedApp = 'HDFC Bank';
    } else if (lowerSender.contains('icici')) {
      detectedApp = 'ICICI Bank';
    } else if (lowerSender.contains('axis')) {
      detectedApp = 'Axis Bank';
    } else if (lowerSender.contains('kotak') || lowerSender.contains('kmbl')) {
      detectedApp = 'Kotak Bank';
    } else if (lowerSender.contains('pnb') || lowerSender.contains('punjab')) {
      detectedApp = 'PNB Bank';
    } else if (lowerSender.contains('indus')) {
      detectedApp = 'IndusInd Bank';
    } else if (lowerSender.contains('yesb') || lowerSender.contains('yesbank')) {
      detectedApp = 'Yes Bank';
    } else if (lowerSender.contains('fed')) {
      detectedApp = 'Federal Bank';
    } else if (lowerSender.contains('rbl')) {
      detectedApp = 'RBL Bank';
    } else if (lowerSender.contains('idfc')) {
      detectedApp = 'IDFC First Bank';
    } else if (lowerSender.contains('utkrs') || lowerSender.contains('utkarsh')) {
      detectedApp = 'Utkarsh Bank';
    } else if (lowerSender.contains('ausf') || lowerSender.contains('aubank') || lowerSender.contains('aubnk')) {
      detectedApp = 'AU Small Finance Bank';
    } else if (lowerSender.contains('cnrb') || lowerSender.contains('canara') || lowerSender.contains('canbnk')) {
      detectedApp = 'Canara Bank';
    } else if (lowerSender.contains('union') || lowerSender.contains('unionb') || lowerSender.contains('ubionline')) {
      detectedApp = 'Union Bank';
    } else if (lowerSender.contains('boi') || lowerSender.contains('boitxn') || lowerSender.contains('boisms')) {
      detectedApp = 'Bank of India';
    } else if (lowerSender.contains('uco') || lowerSender.contains('ucobnk')) {
      detectedApp = 'UCO Bank';
    } else if (lowerSender.contains('iob') || lowerSender.contains('iobtxn')) {
      detectedApp = 'Indian Overseas Bank';
    } else if (lowerSender.contains('maha') || lowerSender.contains('mahabk')) {
      detectedApp = 'Bank of Maharashtra';
    } else if (lowerSender.contains('psb') || lowerSender.contains('psbank')) {
      detectedApp = 'Punjab & Sind Bank';
    } else if (lowerSender.contains('indian') || lowerSender.contains('indbnk') || lowerSender.contains('allbnk')) {
      detectedApp = 'Indian Bank';
    } else if (lowerSender.contains('cbin') || lowerSender.contains('central')) {
      detectedApp = 'Central Bank of India';
    } else if (lowerSender.contains('ippb') || lowerSender.contains('postpay')) {
      detectedApp = 'India Post Payments Bank';
    } else if (lowerSender.contains('fino')) {
      detectedApp = 'Fino Payments Bank';
    } else if (lowerSender.contains('jiopay') || lowerSender.contains('jiopb')) {
      detectedApp = 'Jio Payments Bank';
    } else if (lowerSender.contains('nsdl')) {
      detectedApp = 'NSDL Payments Bank';
    } else if (lowerSender.contains('jana')) {
      detectedApp = 'Jana Small Finance Bank';
    } else if (lowerSender.contains('suryoday')) {
      detectedApp = 'Suryoday Small Finance Bank';
    } else if (lowerSender.contains('esaf')) {
      detectedApp = 'ESAF Small Finance Bank';
    } else if (lowerSender.contains('equitas') || lowerSender.contains('eqsfb')) {
      detectedApp = 'Equitas Bank';
    } else if (lowerSender.contains('ujjivan') || lowerSender.contains('ujsfb')) {
      detectedApp = 'Ujjivan Bank';
    } else if (lowerSender.contains('bandhn') || lowerSender.contains('bandhan')) {
      detectedApp = 'Bandhan Bank';
    } else if (lowerSender.contains('sib') || lowerSender.contains('sibtxn')) {
      detectedApp = 'South Indian Bank';
    } else if (lowerSender.contains('kvb') || lowerSender.contains('kvbbnk')) {
      detectedApp = 'Karur Vysya Bank';
    } else if (lowerSender.contains('cub') || lowerSender.contains('cubbnk')) {
      detectedApp = 'City Union Bank';
    } else if (lowerSender.contains('tmb') || lowerSender.contains('tmbl')) {
      detectedApp = 'Tamilnad Mercantile Bank';
    } else if (lowerSender.contains('jkbank') || lowerSender.contains('jkbnk') || lowerSender.contains('jkb')) {
      detectedApp = 'J&K Bank';
    } else if (lowerSender.contains('ktk') || lowerSender.contains('ktkbnk')) {
      detectedApp = 'Karnataka Bank';
    } else if (lowerSender.contains('dhan')) {
      detectedApp = 'Dhanlaxmi Bank';
    } else if (lowerSender.contains('dcb') || lowerSender.contains('dcbbnk')) {
      detectedApp = 'DCB Bank';
    } else if (lowerSender.contains('csb')) {
      detectedApp = 'CSB Bank';
    } else if (lowerSender.contains('epifi') || lowerSender.contains('-fi-') || lowerSender.endsWith('-fi')) {
      detectedApp = 'Fi Money';
    } else if (lowerSender.contains('jupiter')) {
      detectedApp = 'Jupiter Money';
    } else if (lowerSender.contains('niyo')) {
      detectedApp = 'Niyo Bank';
    }
    // Step 2: Payment Apps in Message Body
    else if (lowerMsg.contains('gpay') || lowerMsg.contains('google pay') || lowerMsg.contains('googlepay') || lowerSender.contains('gpay')) {
      detectedApp = 'Google Pay';
    } else if (lowerMsg.contains('phonepe') || lowerMsg.contains('phone pe') || lowerSender.contains('phonepe')) {
      detectedApp = 'PhonePe';
    } else if (lowerMsg.contains('paytm') || lowerSender.contains('paytm')) {
      detectedApp = 'Paytm';
    } else if (lowerMsg.contains('cred') || lowerSender.contains('cred')) {
      detectedApp = 'CRED';
    } else if (lowerMsg.contains('bhim') || lowerSender.contains('bhim')) {
      detectedApp = 'BHIM UPI';
    } else if (lowerMsg.contains('amazonpay') || lowerMsg.contains('amazon pay')) {
      detectedApp = 'Amazon Pay';
    } else if (lowerMsg.contains('mobikwik')) {
      detectedApp = 'MobiKwik';
    } else if (lowerMsg.contains('freecharge')) {
      detectedApp = 'Freecharge';
    } else if (lowerMsg.contains('airtel')) {
      detectedApp = 'Airtel Payments Bank';
    } else if (lowerMsg.contains('slice')) {
      detectedApp = 'Slice Card';
    } else if (lowerMsg.contains('onecard')) {
      detectedApp = 'OneCard';
    }
    // Step 3: Banks in Message Body (using msgWithoutVpa to ignore target VPA handles)
    else if (msgWithoutVpa.contains('bank of baroda') || msgWithoutVpa.contains(' bob ') || msgWithoutVpa.contains('-bob') || msgWithoutVpa.contains('/bob') || msgWithoutVpa.contains('bob')) {
      detectedApp = 'Bank of Baroda';
    } else if (msgWithoutVpa.contains('hdfc')) {
      detectedApp = 'HDFC Bank';
    } else if (msgWithoutVpa.contains('sbi') || msgWithoutVpa.contains('state bank')) {
      detectedApp = 'SBI Bank';
    } else if (msgWithoutVpa.contains('icici')) {
      detectedApp = 'ICICI Bank';
    } else if (msgWithoutVpa.contains('axis')) {
      detectedApp = 'Axis Bank';
    } else if (msgWithoutVpa.contains('kotak')) {
      detectedApp = 'Kotak Bank';
    } else if (msgWithoutVpa.contains('pnb') || msgWithoutVpa.contains('punjab national')) {
      detectedApp = 'PNB Bank';
    } else if (msgWithoutVpa.contains('indusind')) {
      detectedApp = 'IndusInd Bank';
    } else if (msgWithoutVpa.contains('yes bank') || msgWithoutVpa.contains('yesbank')) {
      detectedApp = 'Yes Bank';
    } else if (msgWithoutVpa.contains('federal bank') || msgWithoutVpa.contains('fedbank')) {
      detectedApp = 'Federal Bank';
    } else if (msgWithoutVpa.contains('rbl bank') || msgWithoutVpa.contains('ratnakar')) {
      detectedApp = 'RBL Bank';
    } else if (msgWithoutVpa.contains('idfc') || msgWithoutVpa.contains('idfcfirst')) {
      detectedApp = 'IDFC First Bank';
    } else if (msgWithoutVpa.contains('bandhan')) {
      detectedApp = 'Bandhan Bank';
    } else if (msgWithoutVpa.contains('utkarsh') || msgWithoutVpa.contains('sfbl')) {
      detectedApp = 'Utkarsh Bank';
    } else if (msgWithoutVpa.contains('au small') || msgWithoutVpa.contains('au bank') || msgWithoutVpa.contains('ausf')) {
      detectedApp = 'AU Small Finance Bank';
    } else if (msgWithoutVpa.contains('equitas')) {
      detectedApp = 'Equitas Bank';
    } else if (msgWithoutVpa.contains('ujjivan')) {
      detectedApp = 'Ujjivan Bank';
    } else if (msgWithoutVpa.contains('canara')) {
      detectedApp = 'Canara Bank';
    } else if (msgWithoutVpa.contains('union bank') || msgWithoutVpa.contains('unionbank')) {
      detectedApp = 'Union Bank';
    } else if (msgWithoutVpa.contains('bank of india') || msgWithoutVpa.contains(' boi ')) {
      detectedApp = 'Bank of India';
    } else if (msgWithoutVpa.contains('central bank')) {
      detectedApp = 'Central Bank of India';
    } else if (msgWithoutVpa.contains('indian bank') || msgWithoutVpa.contains('allahabad bank')) {
      detectedApp = 'Indian Bank';
    } else if (msgWithoutVpa.contains('indian overseas bank') || msgWithoutVpa.contains(' iob ')) {
      detectedApp = 'Indian Overseas Bank';
    } else if (msgWithoutVpa.contains('bank of maharashtra') || msgWithoutVpa.contains('maharashtra bank')) {
      detectedApp = 'Bank of Maharashtra';
    } else if (msgWithoutVpa.contains('punjab & sind') || msgWithoutVpa.contains('punjab and sind')) {
      detectedApp = 'Punjab & Sind Bank';
    } else if (msgWithoutVpa.contains('india post') || msgWithoutVpa.contains('ippb')) {
      detectedApp = 'India Post Payments Bank';
    } else if (msgWithoutVpa.contains('fino')) {
      detectedApp = 'Fino Payments Bank';
    } else if (msgWithoutVpa.contains('fi money') || msgWithoutVpa.contains('epifi')) {
      detectedApp = 'Fi Money';
    } else if (msgWithoutVpa.contains('jupiter')) {
      detectedApp = 'Jupiter Money';
    } else if (msgWithoutVpa.contains('niyo')) {
      detectedApp = 'Niyo Bank';
    } else if (msgWithoutVpa.contains('south indian bank')) {
      detectedApp = 'South Indian Bank';
    } else if (msgWithoutVpa.contains('karur vysya')) {
      detectedApp = 'Karur Vysya Bank';
    } else if (msgWithoutVpa.contains('city union')) {
      detectedApp = 'City Union Bank';
    } else if (msgWithoutVpa.contains('karnataka bank')) {
      detectedApp = 'Karnataka Bank';
    } else if (msgWithoutVpa.contains('jk bank') || msgWithoutVpa.contains('jammu & kashmir')) {
      detectedApp = 'J&K Bank';
    } else if (msgWithoutVpa.contains('uco bank')) {
      detectedApp = 'UCO Bank';
    } else if (msgWithoutVpa.contains('dcb bank') || msgWithoutVpa.contains('development credit')) {
      detectedApp = 'DCB Bank';
    } else if (lowerMsg.contains('upi')) {
      detectedApp = 'UPI Payment';
    }

    // ── Transaction Type ──────────────────────────────────────────────────
    TransactionType type = TransactionType.expense;

    final hasCreditVerb = RegExp(
      r'(?:credited|credited\s+with|credited\s+by|credited\s+to|credited\s+in|credited\s+into|credited\s+for'
      r'|a\/c\s+credited|ac\s+credited|account\s+credited'
      r'|is\s+credited|has\s+been\s+credited'
      r'|received|deposited|salary|refund|refunded|cashback'
      r'|inward|added\s+to|sent\s+you|transfer\s+received'
      r'|money\s+received|fund\s+received|payment\s+received'
      r'|cr\.?\s+to|cr\.?\s+in|cr\.?\s+for|cr\.?\s+by|cr\s+from'
      r'|credit\s+of|credit\s+with|credit:|\bcr\.?\b)',
      caseSensitive: false,
    ).hasMatch(lowerMsg);

    final hasDebitVerb = RegExp(
      r'(?:debited|debited\s+from|debited\s+for|deducted|spent'
      r'|paid\s+to|paid\s+for|purchase|purchased|withdrawn|charged'
      r'|is\s+debited|has\s+been\s+debited'
      r'|a\/c\s+debited|ac\s+debited'
      // ── Credit Card purchase verbs ──────────────────────────────────────
      // HDFC: "has been used for Rs 5000 at AMAZON"
      r'|has\s+been\s+used|been\s+used'
      // ICICI/Axis: "used at SWIGGY", "used for Rs 500", "used on"
      r'|used\s+(?:at|for|on)'
      // SBI Card: "availed for Rs 2000 at FLIPKART"
      r'|availed|has\s+been\s+availed'
      // Generic CC purchase phrases
      r'|purchase\s+(?:made|at|for)'
      r'|transaction\s+made|tran\s+of|txn\s+(?:of|at|for)'
      // Bank abbreviation shorthands
      r'|dr\.?\s+from|dr\.?\s+to\s+vpa|dr\s+from|dr\s+to'
      r'|debit:|upi\s+debit|upi\s+txn|\bdr\.?\b)',
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
    final cardNumberPattern = RegExp(
      r'(?:card|supercard|bobcard|creditcard|credit card|sbicard|hdfccard|icicicard|axiscard|kotakcard|idfccard|onecard|slice card|rupay|visa|mastercard|amex|diners)'
      r'\s*(?:no\.?|number|ending(?:\s+(?:with|in))?|xx+|x+)?\s*(\d{4})',
      caseSensitive: false,
    );
    final cardMatch = cardNumberPattern.firstMatch(message);
    final cardLast4 = cardMatch?.group(1); // e.g. "2235"

    final isDebitCardPattern = RegExp(
      r'(?:debit card|dc card|atm card)',
      caseSensitive: false,
    ).hasMatch(message);

    final isExplicitCcKeyword = RegExp(
      r'(?:credit\s*card|\bcc\b|bobcard|supercard|onecard|sbicard|hdfc\s*card|icici\s*card|axis\s*card|kotak\s*card|idfc\s*card|rbl\s*card|slice\s*card|rupay\s*credit|spent\s+on\s+card|swiped)',
      caseSensitive: false,
    ).hasMatch(message);

    // UPI VPA pattern: word@bankshortcode (e.g. anamikasingh@oksbi, raj@ybl)
    // Comprehensive list of Indian bank UPI handles (NPCI-registered PSP handles).
    final hasUpiVpa = RegExp(
      r'\w[\w.]*@(?:'
      // Google Pay / SBI
      r'oksbi|okaxis|okhdfcbank|okicici|okbizaxis'
      // PhonePe / Yes Bank / Axis / ICICI
      r'|ybl|ibl|axl|nyes|yesbankltd|yesbank|yesb'
      // Paytm / BHIM / WhatsApp
      r'|paytm|upi|waicici|bhim'
      // HDFC / ICICI / Axis / Kotak
      r'|hdfc|hdfcbank|icici|axisbank|kotak|kmbl'
      // SBI / PNB / BOB / BOI / Canara / Union / UCO / Central / Indian / Allahabad / IOB / Maharashtra / PSB
      r'|sbi|pnb|barodampay|boi|cnrb|unionbank|ubi|cbin|uco|centralbank|indianbk|allbank|iob|mahb|psb|dlb'
      // IDFC / IndusInd / Federal / RBL / DCB / Karur / South Indian / CUB / TMB / J&K / Karnataka
      r'|idfcbank|idfc|indus|indusind|federal|fedbank|rbl|dcb|kvb|sib|cub|tmb|jkbank|ktk'
      // Small Finance Banks / Payments Banks
      r'|utkarsh|sfbl|nsdl|apl|timecosmos|rajgovt'
      r'|aubank|au|equitas|ujjivan|jana|suryoday|esaf|bandhan'
      r'|ippb|postbank|fino|jio'
      // Neo Banks & Wallets / Cards
      r'|jupiteraxis|fi|niyo|naviaxis|slice|onecard|postpe|lazypay|simpl|cred'
      // Airtel / Wallet handles
      r'|airtel|freecharge|mobikwik|amazonpay|phonepe'
      // Merged legacy handles
      r'|andb|syndicatebank|vijb'
      // International / foreign handles in India
      r'|sc|hsbc|citibank|dbs'
      r')',
      caseSensitive: false,
    ).hasMatch(message);

    // Broad UPI fallback: any VPA-like pattern (word@word, no dots in handle)
    // combined with a UPI 12-digit reference number reliably identifies UPI.
    // E.g. BOB debit: "8340178859@nyes. Ref:622309396978"
    final hasBroadVpaWithRef = RegExp(
      r'\w+@[a-z]{2,}\b',                        // any word@bankhandle
      caseSensitive: false,
    ).hasMatch(message) && RegExp(
      r'(?:ref(?:erence)?(?:\s+no\.?)?|refno)[:\s]*\d{6,}',
      caseSensitive: false,
    ).hasMatch(message);

    // ── CC Refund detection ───────────────────────────────────────────────
    final isCcPaymentReceivedConfirmation = !lowerMsg.contains('dr. from') &&
        !lowerMsg.contains('debited from') &&
        RegExp(
          r'(?:have\s+)?received\s+payment\s+(?:of\s+)?(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?[^.]{0,60}(?:credit card|cc|supercard|card|creditcard|bobcard)'
          r'|'
          r'(?:available|credit)\s+limit\s+is\s+now'
          r'|'
          r'thank(?:s|\s+you)?\s+for\s+(?:the\s+)?payment[^.]{0,80}(?:credit card|supercard|cc\s+card|creditcard|card ending|bobcard)'
          r'|'
          r'(?:credit card|supercard|bobcard)\s+(?:bill\s+)?payment\s+(?:of\s+)?(?:rs\.?|inr|₹)?\s*[\d,]+\s*(?:has\s+been\s+)?(?:processed|received|successful|credited|accepted)',
          caseSensitive: false,
        ).hasMatch(message);

    final isCcRefundToCard = isCcPaymentReceivedConfirmation ||
        (RegExp(
          r'(?:refund|reversal|cashback|credited)[^.]{0,60}(?:supercard|credit card|creditcard|bobcard|card ending|card no)',
          caseSensitive: false,
        ).hasMatch(message) && (lowerMsg.contains('refund') || lowerMsg.contains('reversal') || lowerMsg.contains('cashback')));

    // ── Bank Account CC Bill Payment Debit detection ──────────────────────
    final isBankCcBillPayment = !isCcRefundToCard && RegExp(
      r'(?:'                                           // open outer group
      r'cr\.?\s+(?:to\s+)?[\w@.-]*?(?:supercard|creditcard|credit\s*card|bobcard|cc@)'
      r'|'
      r'paid\s+(?:rs\.?|inr|₹)?\s*[\d,]+[^.]{0,60}(?:credit card|cc\s+card|supercard|bobcard|card\s+ending|card\s+no)'
      r'|'
      r'payment\s+(?:of\s+)?(?:rs\.?|inr|₹|\$)?\s*[\d,]+(?:\.\d{1,2})?\s*towards?\s*(?:[a-z0-9]+\s+)*(?:credit card|cc|supercard|bobcard|card|creditcard)'
      r')',
      caseSensitive: false,
    ).hasMatch(message);

    String paymentMethod;
    if (isDebitCardPattern) {
      paymentMethod = 'Debit Card';
    } else if (isCcRefundToCard || (cardLast4 != null && !isDebitCardPattern && !isBankCcBillPayment) || (isExplicitCcKeyword && !isBankCcBillPayment)) {
      // CC refund / payment received on CC / purchase on CC → tag as Credit Card
      paymentMethod = 'Credit Card';
    } else if (lowerMsg.contains('upi') || hasUpiVpa || hasBroadVpaWithRef) {
      paymentMethod = 'UPI';
    } else if (isExplicitCcKeyword) {
      paymentMethod = 'Credit Card';
    } else if (lowerMsg.contains('debit card') || lowerMsg.contains(' dc ')) {
      paymentMethod = 'Debit Card';
    } else if (lowerMsg.contains('neft') || lowerMsg.contains('imps')) {
      paymentMethod = 'Bank Transfer';
    } else if (lowerMsg.contains('cash')) {
      paymentMethod = 'Cash';
    } else {
      paymentMethod = 'Bank Transfer';
    }

    // ── Merchant & Category ───────────────────────────────────────────────
    if (isCcRefundToCard) {
      type = TransactionType.income;
    } else if (isBankCcBillPayment) {
      type = TransactionType.expense;
    }

    String category = type == TransactionType.income ? 'Credit Card Payment' : 'Others';

    // Set category for Bank CC bill payment — expense category.
    if (isBankCcBillPayment) {
      category = 'Credit Card Bill';
    }

    String merchant = cardLast4 != null
        ? '$detectedApp Card ••$cardLast4'
        : detectedApp;

    // Primary merchant regex: captures merchant after "at / to / for / vpa / used at / availed at"
    // Covers:
    //   "paid to AMAZON"                       → AMAZON
    //   "used at SWIGGY"                       → SWIGGY   (CC ICICI/Axis)
    //   "availed at FLIPKART"                  → FLIPKART  (CC SBI Card)
    //   "Cr. to 8340178859@nyes"               → 8340178859@nyes (BOB UPI)
    //   "has been used for Rs 5000 at AMAZON"  → AMAZON (CC HDFC)
    final merchantRegex = RegExp(
      r'(?:used\s+at|availed\s+at|purchase\s+at|txn\s+at|cr\.?\s+to|at|to|for|vpa)\s+([\w@][A-Za-z0-9@&\-\.]+?)(?=\s+(?:via|on|ref|using|from|by|link|bal|a\/c|\.|$))',
      caseSensitive: false,
    );
    final mMatch = merchantRegex.firstMatch(message);
    if (mMatch?.group(1) != null) {
      var extracted = mMatch!.group(1)!.trim();
      while (extracted.endsWith('.') || extracted.endsWith(',') || extracted.endsWith(':')) {
        extracted = extracted.substring(0, extracted.length - 1).trim();
      }
      if (extracted.isNotEmpty && extracted.length < 35) {
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
    if (category != 'Credit Card Bill') {
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
