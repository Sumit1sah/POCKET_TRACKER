import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';
import '../services/sms_parser_service.dart';

const _smsChannel = MethodChannel('com.pocketify.expensetracker/sms');

/// Handles saving a parsed SMS transaction directly to Hive.
/// This is called from both foreground and background isolates.
class SmsAutoCaptureService {
  /// Parse incoming SMS text and save transaction to Hive if valid.
  /// Returns the saved TransactionModel, or null if SMS is not a payment alert.
  static Future<TransactionModel?> captureFromSms(
    String smsBody, {
    DateTime? smsDate,
    String? senderAddress,
  }) async {
    final result = SMSParserService.parseSMS(smsBody, senderAddress: senderAddress);
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
    final txDate = smsDate ?? DateTime.now();

    // Deduplication check: ignore if identical transaction amount & type exists within 5 mins
    final existingTxs = LocalStorageService.getTransactions(uid: uid);
    final isDuplicate = existingTxs.any((t) =>
        t.amount == result.amount &&
        t.type == result.type &&
        (t.date.difference(txDate).inMinutes.abs() < 5 || t.description.contains(result.merchant)));

    if (isDuplicate) return null;

    final transaction = TransactionModel(
      id: 'sms_${txDate.millisecondsSinceEpoch}_${result.amount.toInt()}',
      uid: uid,
      type: result.type,
      amount: result.amount,
      category: result.category,
      paymentMethod: result.paymentMethod,
      description: '${result.detectedApp}: ${result.merchant}',
      date: txDate,
    );

    await LocalStorageService.saveTransaction(transaction);
    return transaction;
  }

  /// Scans recent SMS inbox messages received in the last [minutes] minutes (default: 15 mins)
  /// (e.g., while unlocking the phone or launching the app) and automatically
  /// captures any missed transaction alerts. Returns the count of newly saved transactions.
  static Future<int> scanRecentSms({int minutes = 15}) async {
    try {
      final List<dynamic>? rawList =
          await _smsChannel.invokeMethod('fetchRecentSms', {'minutes': minutes});

      if (rawList == null || rawList.isEmpty) return 0;

      int capturedCount = 0;
      for (final item in rawList) {
        if (item is Map) {
          final body = item['body'] as String?;
          final address = item['address'] as String?;
          final dateMillis = item['date'] as int?;

          if (body != null && body.isNotEmpty) {
            final smsDate = dateMillis != null
                ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
                : DateTime.now();

            final captured = await captureFromSms(body, smsDate: smsDate, senderAddress: address);
            if (captured != null) {
              capturedCount++;
            }
          }
        }
      }
      return capturedCount;
    } catch (e) {
      // Return 0 silently if platform call fails (e.g., non-android platform or permission missing)
      return 0;
    }
  }
}
