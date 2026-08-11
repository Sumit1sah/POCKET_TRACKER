import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../services/local_storage_service.dart';
import '../services/sms_parser_service.dart';

const _smsChannel = MethodChannel('com.pocketify.expensetracker/sms');

/// Handles saving a parsed SMS transaction directly to Hive.
/// Called from both foreground (live MethodChannel) and on app-open
/// (draining the SharedPreferences pending queue via fetchPendingSms).
class SmsAutoCaptureService {
  /// Parse incoming SMS text and save transaction to Hive if valid.
  /// Returns the saved [TransactionModel], or null if:
  ///   • SMS is not a payment alert (parser returns null)
  ///   • Transaction is a duplicate of one already saved
  static Future<TransactionModel?> captureFromSms(
    String smsBody, {
    DateTime? smsDate,
    String? senderAddress,
  }) async {
    final result = SMSParserService.parseSMS(smsBody, senderAddress: senderAddress);
    if (result == null) return null;

    // Ensure Hive boxes are open (needed in case we're called early in app lifecycle)
    if (!Hive.isBoxOpen(LocalStorageService.settingsBoxName)) {
      await Hive.initFlutter();
      await Hive.openBox(LocalStorageService.transactionsBoxName);
      await Hive.openBox(LocalStorageService.settingsBoxName);
    }

    final savedUser = LocalStorageService.getCurrentUser();
    final uid = savedUser?.uid ?? 'local_user';
    final txDate = smsDate ?? DateTime.now();

    // ── Deduplication ────────────────────────────────────────────────────────
    // A transaction is a duplicate only if ALL of these match:
    //   • Same amount
    //   • Same type (expense / income)
    //   • Same payment method
    //   • Within a 2-minute window (real duplicate) not 5-minute (too aggressive)
    //
    // We intentionally do NOT compare merchant/category because SMS description
    // wording varies slightly between retries/resends.
    final existingTxs = LocalStorageService.getTransactions(uid: uid);
    final isDuplicate = existingTxs.any((t) =>
        t.amount == result.amount &&
        t.type == result.type &&
        t.paymentMethod == result.paymentMethod &&
        t.date.difference(txDate).inSeconds.abs() < 120); // 2-minute window

    if (isDuplicate) {
      debugPrint('[SmsCapture] Duplicate suppressed: ${result.amount} via ${result.paymentMethod}');
      return null;
    }

    final transaction = TransactionModel(
      id: 'sms_${txDate.millisecondsSinceEpoch}_${result.amount.toInt()}_${result.paymentMethod.hashCode.abs()}',
      uid: uid,
      type: result.type,
      amount: result.amount,
      category: result.category,
      paymentMethod: result.paymentMethod,
      description: '${result.detectedApp}: ${result.merchant}',
      date: txDate,
    );

    await LocalStorageService.saveTransaction(transaction);
    debugPrint('[SmsCapture] Saved: ${transaction.type.name} ₹${transaction.amount} via ${transaction.paymentMethod}');
    return transaction;
  }

  /// Drains the SharedPreferences pending-SMS queue that was written by
  /// the native SmsReceiver when the app was closed.
  /// Returns the count of newly saved transactions.
  /// Call this on every app launch (before or alongside [scanRecentSms]).
  static Future<int> drainPendingQueue() async {
    if (kIsWeb) return 0;
    try {
      final List<dynamic>? rawList =
          await _smsChannel.invokeMethod('fetchPendingSms');

      if (rawList == null || rawList.isEmpty) return 0;

      int capturedCount = 0;
      for (final item in rawList) {
        if (item is Map) {
          final body    = item['body']    as String?;
          final address = item['address'] as String?;
          final dateMs  = item['date'];

          if (body != null && body.isNotEmpty) {
            final smsDate = (dateMs is int && dateMs > 0)
                ? DateTime.fromMillisecondsSinceEpoch(dateMs)
                : DateTime.now();

            final captured = await captureFromSms(
              body,
              smsDate: smsDate,
              senderAddress: address,
            );
            if (captured != null) capturedCount++;
          }
        }
      }
      debugPrint('[SmsCapture] Drained pending queue: $capturedCount new transaction(s)');
      return capturedCount;
    } catch (e) {
      debugPrint('[SmsCapture] drainPendingQueue error: $e');
      return 0;
    }
  }

  /// Scans recent SMS inbox messages received in the last [minutes] minutes.
  /// Used as a safety net to catch SMS that the BroadcastReceiver may have
  /// missed (DND mode, battery optimisation, app force-stop, OEM restrictions).
  /// Returns the count of newly saved transactions.
  static Future<int> scanRecentSms({int minutes = 240}) async {
    if (kIsWeb) return 0;
    try {
      final List<dynamic>? rawList =
          await _smsChannel.invokeMethod('fetchRecentSms', {'minutes': minutes});

      if (rawList == null || rawList.isEmpty) return 0;

      int capturedCount = 0;
      for (final item in rawList) {
        if (item is Map) {
          final body    = item['body']    as String?;
          final address = item['address'] as String?;
          final dateMs  = item['date'];

          if (body != null && body.isNotEmpty) {
            final smsDate = (dateMs is int && dateMs > 0)
                ? DateTime.fromMillisecondsSinceEpoch(dateMs)
                : DateTime.now();

            final captured = await captureFromSms(
              body,
              smsDate: smsDate,
              senderAddress: address,
            );
            if (captured != null) capturedCount++;
          }
        }
      }
      return capturedCount;
    } catch (e) {
      debugPrint('[SmsCapture] scanRecentSms error: $e');
      return 0;
    }
  }
}
