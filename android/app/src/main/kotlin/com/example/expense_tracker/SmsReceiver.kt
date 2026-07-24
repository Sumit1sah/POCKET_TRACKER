package com.example.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.loader.FlutterLoader

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL = "com.example.expense_tracker/sms"
        const val ENGINE_ID = "sms_engine"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val body = sms.messageBody ?: continue
            Log.d("PocketifySMS", "Received SMS: $body")
            dispatchToFlutter(context, body)
        }
    }

    private fun dispatchToFlutter(context: Context, smsBody: String) {
        // Try using cached engine (app is open / recently used)
        val cachedEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (cachedEngine != null) {
            MethodChannel(cachedEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onSmsReceived", smsBody)
            return
        }

        // App is closed: spin up a headless FlutterEngine to process in background
        try {
            val flutterLoader = FlutterLoader()
            flutterLoader.startInitialization(context)
            flutterLoader.ensureInitializationComplete(context, null)

            val engine = FlutterEngine(context)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onSmsReceived", smsBody)
            Log.d("PocketifySMS", "Dispatched to background Flutter engine: $smsBody")
        } catch (e: Exception) {
            Log.e("PocketifySMS", "Failed to dispatch SMS to Flutter: ${e.message}")
        }
    }
}
