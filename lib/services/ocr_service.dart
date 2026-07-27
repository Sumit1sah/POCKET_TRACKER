class OCRParsedResult {
  final double? amount;
  final String? merchant;
  final DateTime? date;

  OCRParsedResult({this.amount, this.merchant, this.date});
}

class OCRService {
  static Future<OCRParsedResult> parseReceiptImage(dynamic imageInput) async {
    // Simple heuristic parser for receipt demo
    return OCRParsedResult(
      amount: 450.0,
      merchant: 'Supermarket Grocery',
      date: DateTime.now(),
    );
  }
}
