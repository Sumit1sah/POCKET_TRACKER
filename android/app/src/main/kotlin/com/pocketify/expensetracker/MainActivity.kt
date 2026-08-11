package com.pocketify.expensetracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so SmsReceiver can use it when app is open
        FlutterEngineCache.getInstance().put(SmsReceiver.ENGINE_ID, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsReceiver.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Fetches recent SMS from device inbox (used on app resume for missed SMS)
                    "fetchRecentSms" -> {
                        val minutes = call.argument<Int>("minutes") ?: 60
                        val smsList = fetchRecentSmsFromInbox(this, minutes)
                        result.success(smsList)
                    }

                    // Drains the SharedPreferences pending-SMS queue written by SmsReceiver
                    // when the app was closed (called on every app launch)
                    "fetchPendingSms" -> {
                        val pending = SmsReceiver.drainPendingSms(this)
                        // Convert to List<Map<String, Any>> for Flutter (Hive-safe types)
                        val flutterList = pending.map { item ->
                            mapOf(
                                "body" to (item["body"] as? String ?: ""),
                                "address" to (item["address"] as? String ?: ""),
                                "date" to (item["date"] as? Long ?: System.currentTimeMillis())
                            )
                        }
                        result.success(flutterList)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Queries the SMS inbox for messages received in the last [minutes] minutes.
     * Returns a list of {address, body, date} maps.
     * Used for catching SMS that arrived while the app was in the background
     * but the BroadcastReceiver was not triggered (e.g. DND / battery saver mode).
     */
    private fun fetchRecentSmsFromInbox(context: Context, minutes: Int): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            return resultList
        }

        try {
            val cutoffTime = System.currentTimeMillis() - (minutes * 60 * 1000L)
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date")
            val selection = "date >= ?"
            val selectionArgs = arrayOf(cutoffTime.toString())
            val sortOrder = "date DESC"

            val cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx    = it.getColumnIndex("body")
                val dateIdx    = it.getColumnIndex("date")

                while (it.moveToNext()) {
                    val address = if (addressIdx >= 0) it.getString(addressIdx) ?: "" else ""
                    val body    = if (bodyIdx    >= 0) it.getString(bodyIdx)    ?: "" else ""
                    val date    = if (dateIdx    >= 0) it.getLong(dateIdx)       else System.currentTimeMillis()

                    if (body.isNotEmpty()) {
                        resultList.add(mapOf(
                            "address" to address,
                            "body"    to body,
                            "date"    to date
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("PocketifyMainActivity", "fetchRecentSmsFromInbox error: ${e.message}")
        }

        return resultList
    }
}
