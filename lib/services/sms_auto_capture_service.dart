import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';
import '../services/sms_parser_service.dart';

/// Handles saving a parsed SMS transaction directly to Hive.
/// This is called from both foreground and background isolates.
class SmsAutoCaptureService {
  /// Parse incoming SMS text and save transaction to Hive if valid.
  /// Returns the saved TransactionModel, or null if SMS is not a payment alert.
  static Future<TransactionModel?> captureFromSms(String smsBody) async {
    final result = SMSParserService.parseSMS(smsBody);
    if (result == null) return null;

    // Ensure Hive is open (needed in background isolate)
    if (!Hive.isBoxOpen(LocalStorageService.settingsBoxName)) {
      await Hive.initFlutter();
      await Hive.openBox(LocalStorageService.transactionsBoxName);
      await Hive.openBox(LocalStorageService.settingsBoxName);
    }

    // Load the logged-in user's uid from persisted session
    final savedUser = LocalStorageService.getCurrentUser();
    final uid = savedUser?.uid ?? 'local_user';

    final transaction = TransactionModel(
      id: 'sms_${DateTime.now().millisecondsSinceEpoch}',
      uid: uid,
      type: result.type,
      amount: result.amount,
      category: result.category,
      paymentMethod: result.paymentMethod,
      description: '${result.detectedApp}: ${result.merchant}',
      date: DateTime.now(),
    );

    await LocalStorageService.saveTransaction(transaction);
    return transaction;
  }
}
