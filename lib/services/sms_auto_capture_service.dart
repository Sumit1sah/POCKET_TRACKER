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
  ///   • The EXACT same SMS body was already captured (true duplicate re-delivery)
  static Future<TransactionModel?> captureFromSms(
    String smsBody, {
    DateTime? smsDate,
    String? senderAddress,
    bool forceCapture = false,
  }) async {
    // ── Check User Preference Setting ───────────────────────────────────────
    if (!forceCapture && !LocalStorageService.getSmsAutoCaptureEnabled()) {
      debugPrint('[SmsCapture] Suppressed: SMS auto capture disabled in Settings');
      return null;
    }

    final result = SMSParserService.parseSMS(smsBody, senderAddress: senderAddress);
    if (result == null) {
      // Log promo / non-financial SMS if sender was provided
      if (senderAddress != null && senderAddress.isNotEmpty) {
        await LocalStorageService.addSmsCaptureLog({
          'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
          'body': smsBody,
          'sender': senderAddress,
          'date': (smsDate ?? DateTime.now()).toIso8601String(),
          'status': 'promo_blocked',
          'amount': 0.0,
          'reason': 'Non-financial or promo SMS',
        });
      }
      return null;
    }

    // Ensure Hive boxes are open (needed in case we're called early in app lifecycle)
    if (!Hive.isBoxOpen(LocalStorageService.settingsBoxName)) {
      await Hive.initFlutter();
      await Hive.openBox(LocalStorageService.transactionsBoxName);
      await Hive.openBox(LocalStorageService.settingsBoxName);
    }

    final savedUser = LocalStorageService.getCurrentUser();
    final uid = savedUser?.uid ?? 'local_user';
    final txDate = smsDate ?? DateTime.now();

    // ── SMS Body Fingerprint ─────────────────────────────────────────────────
    // Normalize: lowercase + collapse all whitespace → single space + trim.
    // This makes the fingerprint resilient to minor encoding differences
    // (e.g. extra spaces, CRLF vs LF) while still being exact.
    final normalizedBody = smsBody.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final smsFp = '${(senderAddress ?? '').toLowerCase().trim()}|$normalizedBody';

    // ── Duplicate Mode Check ──────────────────────────────────────────────────
    final dupMode = LocalStorageService.getDuplicateMode(); // 'smart', 'allow_all', 'flag_review'
    final existingTxs = LocalStorageService.getTransactions(uid: uid);

    bool isDuplicate = false;
    if (!forceCapture && dupMode != 'allow_all') {
      // A transaction is ONLY a duplicate when the SMS body itself is identical.
      // Same amount / merchant but different SMS text = a real separate transaction.
      isDuplicate = existingTxs.any((t) => t.smsHash != null && t.smsHash == smsFp);
    }

    // Handle duplicate suppression in 'smart' mode
    if (isDuplicate && dupMode == 'smart' && !forceCapture) {
      debugPrint('[SmsCapture] Duplicate suppressed: identical SMS body already captured');
      await LocalStorageService.addSmsCaptureLog({
        'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
        'body': smsBody,
        'sender': senderAddress ?? result.detectedApp,
        'date': txDate.toIso8601String(),
        'status': 'duplicate_suppressed',
        'amount': result.amount,
        'reason': 'Identical SMS body already captured',
      });
      return null;
    }

    // Description text (add [Duplicate ⚠️] prefix if flag_review mode)
    String descText = '${result.detectedApp}: ${result.merchant}';
    if (isDuplicate && dupMode == 'flag_review') {
      descText = '[Possible Duplicate ⚠️] $descText';
    }

    // Find matching existing transaction for smart linking
    TransactionModel? matchingTx;
    try {
      matchingTx = existingTxs.firstWhere((t) =>
          t.amount == result.amount &&
          t.date.difference(txDate).inSeconds.abs() < 300);
    } catch (_) {}

    final transaction = TransactionModel(
      id: 'sms_${txDate.millisecondsSinceEpoch}_${result.amount.toInt()}_${result.paymentMethod.hashCode.abs()}',
      uid: uid,
      type: result.type,
      amount: result.amount,
      category: result.category,
      paymentMethod: result.paymentMethod,
      description: descText,
      date: txDate,
      linkedTransactionId: matchingTx?.id,
      isDuplicate: isDuplicate,
      smsHash: smsFp,
    );

    await LocalStorageService.saveTransaction(transaction);
    await LocalStorageService.addSmsCaptureLog({
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
      'body': smsBody,
      'sender': senderAddress ?? result.detectedApp,
      'date': txDate.toIso8601String(),
      'status': isDuplicate ? 'flagged_duplicate' : 'captured',
      'amount': result.amount,
      'reason': 'Saved to transactions as ${result.type.name}',
    });

    debugPrint('[SmsCapture] Saved: ${transaction.type.name} ₹${transaction.amount} via ${transaction.paymentMethod}');
    return transaction;
  }

  /// Drains the SharedPreferences pending-SMS queue that was written by
  /// the native SmsReceiver when the app was closed.
  /// Returns the count of newly saved transactions.
  /// Call this on every app launch to recover pending SMS queued while app was closed.
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
