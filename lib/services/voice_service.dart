class VoiceParsedResult {
  final double? amount;
  final String? category;
  final String? description;

  VoiceParsedResult({this.amount, this.category, this.description});
}

class VoiceService {
  static VoiceParsedResult parseVoiceInput(String speechText) => parseVoiceText(speechText);

  static VoiceParsedResult parseVoiceText(String speechText) {
    // Example: "Spent 500 on groceries" or "Paid 1200 for fuel"
    final text = speechText.toLowerCase();
    
    double? amount;
    final amountRegExp = RegExp(r'(\d+(\.\d+)?)');
    final match = amountRegExp.firstMatch(text);
    if (match != null) {
      amount = double.tryParse(match.group(1) ?? '');
    }

    String? category;
    if (text.contains('food') || text.contains('dinner') || text.contains('lunch')) {
      category = 'Food';
    } else if (text.contains('grocery') || text.contains('groceries')) {
      category = 'Grocery';
    } else if (text.contains('fuel') || text.contains('petrol')) {
      category = 'Fuel';
    } else if (text.contains('shopping') || text.contains('clothes')) {
      category = 'Shopping';
    } else if (text.contains('travel') || text.contains('cab') || text.contains('flight')) {
      category = 'Travel';
    }

    return VoiceParsedResult(
      amount: amount,
      category: category,
      description: speechText,
    );
  }
}
