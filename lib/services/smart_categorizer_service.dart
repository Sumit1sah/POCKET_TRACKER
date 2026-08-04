class SmartCategorizerService {
  static const Map<String, List<String>> _expenseKeywordMap = {
    'Food': [
      'swiggy', 'zomato', 'starbucks', 'mcdonald', 'mcdonalds', 'kfc',
      'domino', 'dominos', 'pizza', 'burger', 'subway', 'cafe', 'coffee',
      'restaurant', 'dhaba', 'bakery', 'dineout', 'food', 'tea', 'chai',
      'eatery', 'bar', 'pub', 'swiggy gourmet', 'faasos', 'behrouz'
    ],
    'Groceries': [
      'blinkit', 'zepto', 'bigbasket', 'instamart', 'supermarket', 'grocery',
      'groceries', 'kirana', 'mart', 'dmart', 'milk', 'dairy', 'vegetables',
      'fruits', 'meat', 'nature basket', 'licious', 'country delight'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'zara', 'h&m',
      'nykaa', 'trends', 'clothes', 'clothing', 'footwear', 'shoes',
      'mall', 'electronics', 'croma', 'reliance digital', 'decathlon',
      'ikea', 'shopping', 'uniqlo', 'tata cliq', 'lenskart'
    ],
    'Fuel': [
      'petrol', 'diesel', 'hpcl', 'bpcl', 'iocl', 'shell', 'fuel', 'cng',
      'petrol pump', 'gas station', 'indian oil', 'bharat petroleum', 'hindustan petroleum'
    ],
    'Transport': [
      'uber', 'ola', 'rapido', 'cab', 'auto', 'metro', 'parking', 'toll',
      'fastag', 'bus', 'namma metro', 'dMRC', 'taxi', 'ride'
    ],
    'Bills': [
      'electricity', 'electric', 'bill', 'water bill', 'gas bill', 'recharge',
      'jio', 'airtel', 'vi', 'vodafone', 'broadband', 'wifi', 'wi-fi',
      'dth', 'tata play', 'dish tv', 'maintenance', 'utility', 'piped gas'
    ],
    'Rent': [
      'rent', 'house rent', 'flat rent', 'nobroker', 'magicbricks', 'pg fee',
      'pg rent', 'room rent'
    ],
    'Entertainment': [
      'netflix', 'spotify', 'prime video', 'amazon prime', 'hotstar',
      'jiosaavn', 'gaana', 'bookmyshow', 'movie', 'cinema', 'youtube',
      'gaming', 'steam', 'playstation', 'xbox', 'pvr', 'inox'
    ],
    'Health': [
      'medical', 'pharmacy', 'hospital', 'doctor', 'apollo', 'practo',
      'medicine', 'chemist', 'lab', 'pharmeasy', '1mg', 'tata 1mg',
      'gym', 'fitness', 'cult.fit', 'cultfit', 'dental', 'clinic'
    ],
    'Travel': [
      'flight', 'train', 'irctc', 'bus', 'redbus', 'makemytrip', 'goibibo',
      'cleartrip', 'hotel', 'airbnb', 'stay', 'resort', 'yatra', 'indigo',
      'air india', 'akasa'
    ],
    'Education': [
      'school', 'college', 'university', 'fees', 'tuition', 'udemy',
      'coursera', 'books', 'stationery', 'coaching', 'byjus', 'unacademy'
    ],
    'Money Given / Lent': [
      'money given', 'given money', 'gave money', 'lent', 'borrowed by', 'asked money',
      'loan given', 'friend loan', 'emi', 'loan', 'repayment', 'repay', 'debt'
    ],
    'Credit Card Bill': [
      'credit card bill', 'cc bill', 'credit card payment', 'card bill', 'card due',
      'card outstanding', 'credit card due', 'cc payment', 'credit card emi',
      'cc emi', 'hdfc card', 'sbi card', 'icici card', 'axis card', 'kotak card',
      'amex', 'indusind card', 'yes card', 'idfc card', 'au card'
    ],
  };

  static const Map<String, List<String>> _incomeKeywordMap = {
    'Salary': ['salary', 'payroll', 'monthly salary', 'wages', 'company credit'],
    'Pocket Money': ['pocket money', 'pocketmoney', 'monthly pocket money', 'stipend', 'allowance', 'parents', 'dad', 'mom'],
    'Money Returned': ['money returned', 'returned', 'sent back', 'paid back', 'returned money', 'borrowed back', 'repaid', 'repayment'],
    'Investment Returns': ['dividend', 'interest', 'mutual fund', 'stocks', 'returns', 'profit', 'fd interest'],
    'Gift / Bonus': ['gift', 'birthday', 'festival', 'bonus', 'rewards', 'prize'],
    'Credit Card Payment': [
      'credit card payment', 'cc payment', 'card payment', 'paid cc bill', 'paid card bill',
      'credit card bill paid', 'card bill paid', 'cc bill paid', 'credit limit restored',
      'card limit restored', 'cc limit', 'paid outstanding', 'cleared card',
    ],
    'CC Cashback / Refund': [
      'cashback', 'cash back', 'cc cashback', 'credit card cashback', 'card cashback',
      'card refund', 'credit card refund', 'cc refund', 'card reversal', 'cc reversal',
      'reward credit', 'reward points', 'hdfc cashback', 'sbi cashback', 'icici cashback',
      'axis cashback', 'amex credit', 'card credit', 'refund to card', 'refunded to card',
      'credited to card', 'merchant refund'
    ],
  };

  /// Smartly predicts the category from user-typed description, merchant, or notes.
  /// Returns null if no strong match is found.
  static String? predictCategory(String input, {required bool isExpense}) {
    if (input.trim().isEmpty) return null;
    final lower = input.toLowerCase().trim();

    final map = isExpense ? _expenseKeywordMap : _incomeKeywordMap;

    for (final entry in map.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (lower.contains(kw)) {
          return category;
        }
      }
    }

    return null;
  }

  /// Returns top 3-4 recommended categories matching the input text,
  /// or top default categories if input is empty.
  static List<String> getSuggestedCategories(String input, {required bool isExpense}) {
    final Map<String, List<String>> map = isExpense ? _expenseKeywordMap : _incomeKeywordMap;
    final defaultList = isExpense
        ? ['Food', 'Shopping', 'Bills', 'Groceries']
        : ['Salary', 'Pocket Money', 'Money Returned', 'Investment Returns'];

    if (input.trim().isEmpty) return defaultList;

    final lower = input.toLowerCase().trim();
    final matches = <String>[];

    for (final entry in map.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          matches.add(entry.key);
          break;
        }
      }
    }

    if (matches.isEmpty) return defaultList;

    // Add remaining defaults to fill top 4 choices
    for (final def in defaultList) {
      if (!matches.contains(def)) {
        matches.add(def);
      }
    }

    return matches.take(4).toList();
  }
}
