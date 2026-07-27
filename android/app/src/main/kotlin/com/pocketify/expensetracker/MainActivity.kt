package com.pocketify.expensetracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so SmsReceiver can use it when app is open
        FlutterEngineCache.getInstance().put(SmsReceiver.ENGINE_ID, flutterEngine)

        // Set up the MethodChannel to handle requests from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsReceiver.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "fetchRecentSms") {
                    val minutes = call.argument<Int>("minutes") ?: 15
                    val smsList = fetchRecentSmsFromInbox(context, minutes)
                    result.success(smsList)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun fetchRecentSmsFromInbox(context: Context, minutes: Int): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()

        // Check READ_SMS permission
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            return resultList
        }

        try {
            // Cutoff time: only scan SMS from the last [minutes] (default: 15 mins for maximum privacy & security)
            val cutoffTime = System.currentTimeMillis() - (minutes * 60 * 1000L)
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date")
            val selection = "date >= ?"
            val selectionArgs = arrayOf(cutoffTime.toString())
            val sortOrder = "date DESC"

            val cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")

                while (it.moveToNext()) {
                    val address = if (addressIdx >= 0) it.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()

                    resultList.add(
                        mapOf(
                            "address" to address,
                            "body" to body,
                            "date" to date
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return resultList
    }
}
