package com.example.todo_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Native Android scheduler for recurring task reminders.
 *
 * A repeating AlarmManager alarm is tempting, but Android may batch repeating
 * alarms and there is no Dart isolate involved when the process is dead. This
 * receiver instead schedules one exact alarm at a time. When it fires it posts
 * the notification and schedules the next occurrence. The small preference
 * record is enough for the receiver to continue without Flutter and to rebuild
 * the alarms after BOOT_COMPLETED.
 */
class RecurringReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        when (intent.action) {
            ACTION_FIRE -> {
                val taskId = intent.getIntExtra(EXTRA_TASK_ID, INVALID_TASK_ID)
                if (taskId != INVALID_TASK_ID) {
                    fireReminder(appContext, taskId)
                }
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> rescheduleAll(appContext)
        }
    }

    companion object {
        const val CHANNEL_ID = "todo_recurring_reminders"
        const val ACTION_FIRE = "com.example.todo_app.action.RECURRING_REMINDER"
        const val EXTRA_TASK_ID = "extra_task_id"

        private const val PREFS_NAME = "recurring_task_reminders"
        private const val KEY_TASK_IDS = "task_ids"
        private const val KEY_ENABLED_PREFIX = "enabled_"
        private const val KEY_NEXT_AT_PREFIX = "next_at_"
        private const val KEY_TITLE_PREFIX = "title_"
        private const val KEY_BODY_PREFIX = "body_"
        private const val INVALID_TASK_ID = -1
        private const val TWO_HOURS_MILLIS = 2L * 60L * 60L * 1000L
        private const val NOTIFICATION_ID_BASE = 1000000
        private const val PENDING_INTENT_BASE = 2000000

        /** Stable namespace, separate from alarms, timers, and legacy IDs. */
        fun notificationId(taskId: Int): Int = NOTIFICATION_ID_BASE + taskId

        fun schedule(
            context: Context,
            taskId: Int,
            title: String,
            body: String,
            firstAtMillis: Long,
        ) {
            val appContext = context.applicationContext
            val prefs = preferences(appContext)
            cancelAlarm(appContext, taskId)

            val firstAt = firstAtMillis.coerceAtLeast(
                System.currentTimeMillis() + MINIMUM_DELAY_MILLIS,
            )
            val ids = taskIds(prefs)
            ids.add(taskId.toString())
            prefs.edit()
                .putStringSet(KEY_TASK_IDS, ids)
                .putBoolean(enabledKey(taskId), true)
                .putLong(nextAtKey(taskId), firstAt)
                .putString(titleKey(taskId), title)
                .putString(bodyKey(taskId), body)
                .commit()

            createChannel(appContext)
            scheduleAlarm(appContext, taskId, firstAt)
        }

        fun cancel(context: Context, taskId: Int) {
            val appContext = context.applicationContext
            val prefs = preferences(appContext)
            cancelAlarm(appContext, taskId)
            appContext.getSystemService(NotificationManager::class.java)
                ?.cancel(notificationId(taskId))

            val ids = taskIds(prefs)
            ids.remove(taskId.toString())
            prefs.edit()
                .putStringSet(KEY_TASK_IDS, ids)
                .remove(enabledKey(taskId))
                .remove(nextAtKey(taskId))
                .remove(titleKey(taskId))
                .remove(bodyKey(taskId))
                .commit()
        }

        fun rescheduleAll(context: Context) {
            val appContext = context.applicationContext
            val prefs = preferences(appContext)
            val now = System.currentTimeMillis()

            for (taskIdString in taskIds(prefs)) {
                val taskId = taskIdString.toIntOrNull() ?: continue
                if (!prefs.getBoolean(enabledKey(taskId), false)) continue

                var nextAt = prefs.getLong(nextAtKey(taskId), now + TWO_HOURS_MILLIS)
                // If the device was off when one or more occurrences passed,
                // skip missed alerts but retain the two-hour cadence.
                while (nextAt <= now) nextAt += TWO_HOURS_MILLIS
                prefs.edit().putLong(nextAtKey(taskId), nextAt).commit()
                scheduleAlarm(appContext, taskId, nextAt)
            }
        }

        private fun fireReminder(context: Context, taskId: Int) {
            val prefs = preferences(context)
            if (!prefs.getBoolean(enabledKey(taskId), false)) return

            val title = prefs.getString(titleKey(taskId), "Task reminder")
                ?: "Task reminder"
            val body = prefs.getString(bodyKey(taskId), "Time to work on this task.")
                ?: "Time to work on this task."

            showNotification(context, taskId, title, body)

            val now = System.currentTimeMillis()
            var nextAt = prefs.getLong(nextAtKey(taskId), now)
            do {
                nextAt += TWO_HOURS_MILLIS
            } while (nextAt <= now)
            prefs.edit().putLong(nextAtKey(taskId), nextAt).commit()
            scheduleAlarm(context, taskId, nextAt)
        }

        private fun showNotification(
            context: Context,
            taskId: Int,
            title: String,
            body: String,
        ) {
            createChannel(context)
            val openIntent = Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.EXTRA_OPEN_TODO_ID, taskId)
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                PENDING_INTENT_BASE + taskId,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context).setPriority(Notification.PRIORITY_DEFAULT)
            }
                .setSmallIcon(R.drawable.ic_alarm_notification)
                .setContentTitle("Task reminder")
                .setContentText(title)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_REMINDER)
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())

            try {
                context.getSystemService(NotificationManager::class.java)
                    ?.notify(notificationId(taskId), builder.build())
            } catch (_: SecurityException) {
                // POST_NOTIFICATIONS was denied. The next alarm remains
                // scheduled; granting permission later restores visibility.
            }
        }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Recurring Task Reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Reminds you about enabled tasks every two hours"
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }

        private fun scheduleAlarm(context: Context, taskId: Int, atMillis: Long) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            val pendingIntent = alarmPendingIntent(context, taskId)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                // Exact access is requested from Flutter. Keep the reminder
                // functional when the user has not granted special access.
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    atMillis,
                    pendingIntent,
                )
                return
            }

            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    atMillis,
                    pendingIntent,
                )
            } catch (_: SecurityException) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    atMillis,
                    pendingIntent,
                )
            }
        }

        private fun cancelAlarm(context: Context, taskId: Int) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            alarmManager.cancel(alarmPendingIntent(context, taskId))
        }

        private fun alarmPendingIntent(context: Context, taskId: Int): PendingIntent {
            val intent = Intent(context, RecurringReminderReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra(EXTRA_TASK_ID, taskId)
                data = android.net.Uri.parse("todo-reminder://$taskId")
            }
            return PendingIntent.getBroadcast(
                context,
                PENDING_INTENT_BASE + taskId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun preferences(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private fun taskIds(prefs: android.content.SharedPreferences): MutableSet<String> =
            (prefs.getStringSet(KEY_TASK_IDS, emptySet()) ?: emptySet()).toMutableSet()

        private fun enabledKey(taskId: Int) = "$KEY_ENABLED_PREFIX$taskId"
        private fun nextAtKey(taskId: Int) = "$KEY_NEXT_AT_PREFIX$taskId"
        private fun titleKey(taskId: Int) = "$KEY_TITLE_PREFIX$taskId"
        private fun bodyKey(taskId: Int) = "$KEY_BODY_PREFIX$taskId"

        private const val MINIMUM_DELAY_MILLIS = 1000L
    }
}
