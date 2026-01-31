package com.example.signal_notifier

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.signal_notifier/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDailyReset" -> {
                    scheduleDailyReset()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Schedule daily reset on app start
        scheduleDailyReset()
    }

    private fun scheduleDailyReset() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Check if we can schedule exact alarms on Android 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    android.util.Log.w("MainActivity", "Cannot schedule exact alarms - permission not granted")
                    return
                }
            }
            
            val intent = Intent(this, DailyResetReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Set alarm for 9:17 AM
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 9)
                set(Calendar.MINUTE, 17)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                
                // If 9:17 AM has passed today, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            // Schedule exact alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
            
            android.util.Log.d("MainActivity", "Daily reset scheduled successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error scheduling daily reset: ${e.message}")
        }
    }
}
