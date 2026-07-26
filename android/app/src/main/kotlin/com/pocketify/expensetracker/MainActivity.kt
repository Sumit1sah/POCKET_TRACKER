package com.pocketify.expensetracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so SmsReceiver can use it when app is open
        FlutterEngineCache.getInstance().put(SmsReceiver.ENGINE_ID, flutterEngine)

        // Set up the MethodChannel on the Flutter side
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsReceiver.CHANNEL)
            .setMethodCallHandler { call, result ->
                // Flutter calls back to Kotlin here if needed
                result.notImplemented()
            }
    }
}
