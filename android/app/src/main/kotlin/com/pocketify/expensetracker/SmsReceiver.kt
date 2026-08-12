package com.pocketify.expensetracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.PowerManager
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * SMS BroadcastReceiver that intercepts incoming bank/payment SMS messages.
 *
 * Strategy:
 *   1. If the Flutter engine is already running (app is open / in background),
 *      forward the SMS directly via MethodChannel — zero latency.
 *   2. If the app is fully closed, persist the SMS body + metadata in
 *      SharedPreferences as a pending queue. The next time the app opens,
 *      MainActivity drains the queue via `fetchPendingSms` and processes
 *      all missed messages. This is the ONLY reliable cross-process approach
 *      on Android; spinning up a headless FlutterEngine in a BroadcastReceiver
 *      is unreliable because Dart may not be ready before the receiver finishes.
 *
 * A WakeLock is briefly acquired to ensure the queue write completes even if
 * the device is about to sleep.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL = "com.pocketify.expensetracker/sms"
        const val ENGINE_ID = "sms_engine"
        const val PREFS_NAME = "pocketify_sms_prefs"
        const val KEY_PENDING_SMS = "pending_sms_queue"

        /** Enqueue an SMS for later processing (called from this receiver). */
        fun enqueuePendingSms(context: Context, body: String, address: String, dateMillis: Long) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY_PENDING_SMS, "[]") ?: "[]"
            val arr = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }

            val obj = JSONObject().apply {
                put("body", body)
                put("address", address)
                put("date", dateMillis)
                put("enqueuedAt", System.currentTimeMillis())
            }
            arr.put(obj)
            prefs.edit().putString(KEY_PENDING_SMS, arr.toString()).apply()
            Log.d("PocketifySMS", "Enqueued pending SMS (queue size=${arr.length()}): $body")
        }

        /** Drain and return all pending SMS entries, clearing the queue. */
        fun drainPendingSms(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING_SMS, "[]") ?: "[]"
            prefs.edit().putString(KEY_PENDING_SMS, "[]").apply()

            val arr = try { JSONArray(raw) } catch (_: Exception) { return emptyList() }
            val result = mutableListOf<Map<String, Any>>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                result.add(
                    mapOf(
                        "body" to (obj.optString("body", "")),
                        "address" to (obj.optString("address", "")),
                        "date" to (obj.optLong("date", System.currentTimeMillis()))
                    )
                )
            }
            Log.d("PocketifySMS", "Drained ${result.size} pending SMS entries")
            return result
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        // Acquire a brief WakeLock so we don't get suspended mid-queue-write
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Pocketify:SmsWakeLock")
        wakeLock?.acquire(10_000L) // max 10 seconds

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val body = sms.messageBody ?: continue
                val address = sms.originatingAddress ?: ""
                val dateMillis = sms.timestampMillis

                Log.d("PocketifySMS", "Received SMS from=$address body=$body")

                // Path A: App is open — send directly via live MethodChannel
                val cachedEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)
                if (cachedEngine != null) {
                    val messenger = cachedEngine.dartExecutor.binaryMessenger
                    // Must run channel calls on the main thread
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        try {
                            MethodChannel(messenger, CHANNEL)
                                .invokeMethod("onSmsReceived", mapOf(
                                    "body" to body,
                                    "address" to address,
                                    "date" to dateMillis
                                ))
                            Log.d("PocketifySMS", "Dispatched SMS to live Flutter engine")
                        } catch (e: Exception) {
                            Log.e("PocketifySMS", "Live dispatch failed, enqueueing: ${e.message}")
                            // Fallback: enqueue in case dispatch fails
                            enqueuePendingSms(context, body, address, dateMillis)
                        }
                    }
                } else {
                    // Path B: App is closed — persist to queue, processed on next app open
                    enqueuePendingSms(context, body, address, dateMillis)
                }
            }
        } finally {
            if (wakeLock?.isHeld == true) wakeLock.release()
        }
    }
}
