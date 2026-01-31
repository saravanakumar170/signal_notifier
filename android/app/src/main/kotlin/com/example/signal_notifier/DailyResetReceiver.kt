package com.example.signal_notifier

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import android.util.Log
import java.util.Calendar

class DailyResetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DailyResetReceiver", "Daily reset triggered at ${System.currentTimeMillis()}")
        
        // Clear SharedPreferences data
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            remove("flutter.last_signal_type")
            val today = java.time.LocalDate.now().toString()
            putString("flutter.last_reset_date", today)
            apply()
        }
        
        Log.d("DailyResetReceiver", "Daily reset completed, last signal cleared")
        
        // Schedule next day's reset
        scheduleNextReset(context)
    }

    private fun scheduleNextReset(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Check if we can schedule exact alarms on Android 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.w("DailyResetReceiver", "Cannot schedule exact alarms - permission not granted")
                    return
                }
            }
            
            val intent = Intent(context, DailyResetReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Set alarm for tomorrow at 9:17 AM
            val calendar = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 9)
                set(Calendar.MINUTE, 17)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
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
            
            Log.d("DailyResetReceiver", "Next reset scheduled for ${calendar.time}")
        } catch (e: Exception) {
            Log.e("DailyResetReceiver", "Error scheduling next reset: ${e.message}")
        }
    }
}
