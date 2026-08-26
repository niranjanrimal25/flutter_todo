package com.example.todo_app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.NotificationSettings
import com.gdelataillade.alarm.models.VolumeSettings
import com.gdelataillade.alarm.services.AlarmScheduler
import com.gdelataillade.alarm.services.AlarmStorage
import java.util.Date

/**
 * Native Android recurrence companion for task reminders.
 *
 * The alarm plugin owns each actual ringing alarm: its AlarmReceiver starts
 * the plugin foreground service, which plays the looping alarm asset,
 * vibrates, shows the full-screen UI, and exposes Stop/Snooze. This receiver
 * only wakes at the same time to arm the next occurrence with the plugin's
 * own AlarmScheduler. Each occurrence uses a different plugin id so stopping
 * the currently ringing alarm never deletes the next one.
 */
class RecurringReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        when (intent.action) {
            ACTION_CHAIN -> {
                val taskId = intent.getIntExtra(EXTRA_TASK_ID, INVALID_ID)
                if (taskId != INVALID_ID) fireAndScheduleNext(appContext, taskId)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> rescheduleAll(appContext)
        }
    }

    companion object {
        const val ACTION_CHAIN = "com.example.todo_app.action.RECURRING_REMINDER"
        const val EXTRA_TASK_ID = "extra_task_id"

        private const val PREFS_NAME = "recurring_task_reminders"
        private const val KEY_TASK_IDS = "task_ids"
        private const val KEY_ENABLED_PREFIX = "enabled_"
        private const val KEY_NEXT_AT_PREFIX = "next_at_"
        private const val KEY_INTERVAL_PREFIX = "interval_"
        private const val KEY_TITLE_PREFIX = "title_"
        private const val KEY_BODY_PREFIX = "body_"
        private const val KEY_ACTIVE_PLUGIN_PREFIX = "active_plugin_"
        private const val KEY_PREVIOUS_PLUGIN_PREFIX = "previous_plugin_"
        private const val KEY_SEQUENCE_PREFIX = "sequence_"
        private const val INVALID_ID = -1
        private const val DEFAULT_INTERVAL_HOURS = 2
        // AlarmScheduler.requireDurable rejects delays <= 5 seconds because
        // it would otherwise fall back to an in-process Handler. Keep the
        // first native plugin alarm just beyond that threshold.
        private const val MINIMUM_DELAY_MILLIS = 6000L
        private const val PLUGIN_ALARM_ID_BASE = 600000
        private const val PLUGIN_ID_STRIDE = 100
        private const val COMPANION_REQUEST_CODE_BASE = 2100000
        private const val LEGACY_NOTIFICATION_ID_BASE = 1000000
        private const val LEGACY_COMPANION_REQUEST_CODE_BASE = 1400000
        private const val NO_PLUGIN_ID = -1

        fun pluginAlarmId(taskId: Int): Int = PLUGIN_ALARM_ID_BASE + taskId

        private fun occurrencePluginId(taskId: Int, sequence: Int): Int {
            return PLUGIN_ALARM_ID_BASE + taskId * PLUGIN_ID_STRIDE +
                sequence % PLUGIN_ID_STRIDE
        }

        fun schedule(
            context: Context,
            taskId: Int,
            title: String,
            body: String,
            firstAtMillis: Long,
            intervalHours: Int,
        ) {
            val appContext = context.applicationContext
            val safeInterval = intervalHours.coerceIn(1, 24)
            val firstAt = firstAtMillis.coerceAtLeast(
                System.currentTimeMillis() + MINIMUM_DELAY_MILLIS,
            )
            val prefs = preferences(appContext)

            cancelStoredAlarms(appContext, taskId, prefs)

            val ids = taskIds(prefs)
            ids.add(taskId.toString())
            val firstPluginId = occurrencePluginId(taskId, 0)
            prefs.edit()
                .putStringSet(KEY_TASK_IDS, ids)
                .putBoolean(enabledKey(taskId), true)
                .putLong(nextAtKey(taskId), firstAt)
                .putInt(intervalKey(taskId), safeInterval)
                .putString(titleKey(taskId), title)
                .putString(bodyKey(taskId), body)
                .putInt(activePluginKey(taskId), firstPluginId)
                .putInt(previousPluginKey(taskId), NO_PLUGIN_ID)
                .putInt(sequenceKey(taskId), 0)
                .commit()

            schedulePluginAlarm(
                appContext,
                taskId,
                title,
                body,
                firstAt,
                safeInterval,
                firstPluginId,
            )
            scheduleCompanionAlarm(appContext, taskId, firstAt)
        }

        fun cancel(context: Context, taskId: Int) {
            val appContext = context.applicationContext
            val prefs = preferences(appContext)
            cancelStoredAlarms(appContext, taskId, prefs)

            val ids = taskIds(prefs)
            ids.remove(taskId.toString())
            prefs.edit()
                .putStringSet(KEY_TASK_IDS, ids)
                .remove(enabledKey(taskId))
                .remove(nextAtKey(taskId))
                .remove(intervalKey(taskId))
                .remove(titleKey(taskId))
                .remove(bodyKey(taskId))
                .remove(activePluginKey(taskId))
                .remove(previousPluginKey(taskId))
                .remove(sequenceKey(taskId))
                .commit()
        }

        fun rescheduleAll(context: Context) {
            val appContext = context.applicationContext
            val prefs = preferences(appContext)
            val now = System.currentTimeMillis()

            for (taskIdString in taskIds(prefs)) {
                val taskId = taskIdString.toIntOrNull() ?: continue
                if (!prefs.getBoolean(enabledKey(taskId), false)) continue

                val intervalHours = prefs.getInt(
                    intervalKey(taskId),
                    DEFAULT_INTERVAL_HOURS,
                ).coerceIn(1, 24)
                var nextAt = prefs.getLong(
                    nextAtKey(taskId),
                    now + intervalHours * HOUR_MILLIS,
                )
                while (nextAt <= now) nextAt += intervalHours * HOUR_MILLIS

                val activePluginId = prefs.getInt(
                    activePluginKey(taskId),
                    occurrencePluginId(taskId, 0),
                )
                prefs.edit().putLong(nextAtKey(taskId), nextAt).commit()

                val title = prefs.getString(titleKey(taskId), "Task reminder")
                    ?: "Task reminder"
                val body = prefs.getString(bodyKey(taskId), "Time to work on this task.")
                    ?: "Time to work on this task."
                schedulePluginAlarm(
                    appContext,
                    taskId,
                    title,
                    body,
                    nextAt,
                    intervalHours,
                    activePluginId,
                )
                scheduleCompanionAlarm(appContext, taskId, nextAt)
            }
        }

        private fun fireAndScheduleNext(context: Context, taskId: Int) {
            val prefs = preferences(context)
            if (!prefs.getBoolean(enabledKey(taskId), false)) return

            val intervalHours = prefs.getInt(
                intervalKey(taskId),
                DEFAULT_INTERVAL_HOURS,
            ).coerceIn(1, 24)
            val intervalMillis = intervalHours * HOUR_MILLIS
            val now = System.currentTimeMillis()
            var nextAt = prefs.getLong(nextAtKey(taskId), now)
            do {
                nextAt += intervalMillis
            } while (nextAt <= now)

            val currentPluginId = prefs.getInt(
                activePluginKey(taskId),
                occurrencePluginId(taskId, 0),
            )
            val sequence = prefs.getInt(sequenceKey(taskId), 0) + 1
            val nextPluginId = occurrencePluginId(taskId, sequence)
            if (!prefs.getBoolean(enabledKey(taskId), false)) return

            prefs.edit()
                .putLong(nextAtKey(taskId), nextAt)
                .putInt(previousPluginKey(taskId), currentPluginId)
                .putInt(activePluginKey(taskId), nextPluginId)
                .putInt(sequenceKey(taskId), sequence)
                .commit()

            val title = prefs.getString(titleKey(taskId), "Task reminder")
                ?: "Task reminder"
            val body = prefs.getString(bodyKey(taskId), "Time to work on this task.")
                ?: "Time to work on this task."
            schedulePluginAlarm(
                context,
                taskId,
                title,
                body,
                nextAt,
                intervalHours,
                nextPluginId,
            )
            scheduleCompanionAlarm(context, taskId, nextAt)
        }

        private fun schedulePluginAlarm(
            context: Context,
            taskId: Int,
            title: String,
            body: String,
            atMillis: Long,
            intervalHours: Int,
            pluginId: Int,
        ) {
            val settings = AlarmSettings(
                id = pluginId,
                dateTime = Date(atMillis),
                assetAudioPath = "assets/sounds/alarm.wav",
                volumeSettings = VolumeSettings(
                    volume = 0.9,
                    fadeDuration = null,
                    fadeSteps = emptyList(),
                    volumeEnforced = false,
                ),
                notificationSettings = NotificationSettings(
                    title = "Task reminder: $title",
                    body = body,
                    stopButton = "Stop",
                    icon = "ic_alarm_notification",
                    androidSnoozeButton = "Snooze",
                    androidStopAlarmOnDismiss = false,
                ),
                loopAudio = true,
                vibrate = true,
                warningNotificationOnKill = false,
                androidFullScreenIntent = true,
                allowAlarmOverlap = true,
                allowSameSecondScheduling = true,
                iOSBackgroundAudio = true,
                androidStopAlarmOnTermination = false,
                preferConnectedAudioDevice = false,
                androidSnoozeDurationMillis = 5L * 60L * 1000L,
                payload = "{\"t\":\"r\",\"id\":$taskId,\"intervalHours\":$intervalHours,\"label\":${jsonString(title)},\"body\":${jsonString(body)},\"ring\":\"assets/sounds/alarm.wav\"}",
            )
            AlarmScheduler.schedule(context, settings, requireDurable = true)
        }

        private fun scheduleCompanionAlarm(
            context: Context,
            taskId: Int,
            atMillis: Long,
        ) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            val pendingIntent = companionPendingIntent(context, taskId)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    !alarmManager.canScheduleExactAlarms()
                ) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        atMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        atMillis,
                        pendingIntent,
                    )
                }
            } catch (_: SecurityException) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    atMillis,
                    pendingIntent,
                )
            }
        }

        private fun cancelStoredAlarms(
            context: Context,
            taskId: Int,
            prefs: android.content.SharedPreferences,
        ) {
            cancelCompanionAlarm(context, taskId)
            cancelLegacyCompanionAlarm(context, taskId)

            val active = prefs.getInt(activePluginKey(taskId), NO_PLUGIN_ID)
            val previous = prefs.getInt(previousPluginKey(taskId), NO_PLUGIN_ID)
            cancelPluginId(context, active)
            if (previous != NO_PLUGIN_ID && previous != active) {
                cancelPluginId(context, previous)
            }

            // Clean up the fixed id used by the Dart-only implementation and
            // the old soft notification implementation.
            cancelPluginId(context, pluginAlarmId(taskId))
            context.getSystemService(NotificationManager::class.java)
                ?.cancel(LEGACY_NOTIFICATION_ID_BASE + taskId)
        }

        private fun cancelPluginId(context: Context, pluginId: Int) {
            if (pluginId == NO_PLUGIN_ID) return
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            if (alarmManager != null) {
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    pluginId,
                    Intent(context, AlarmReceiver::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                alarmManager.cancel(pendingIntent)
            }

            // Stop a live foreground-service ring as well as its future alarm.
            context.sendBroadcast(
                Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_ALARM_STOP
                    putExtra("id", pluginId)
                },
            )
            AlarmStorage(context).unsaveAlarm(pluginId)
            context.getSystemService(NotificationManager::class.java)?.cancel(pluginId)
        }

        private fun cancelCompanionAlarm(context: Context, taskId: Int) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            alarmManager.cancel(companionPendingIntent(context, taskId))
        }

        private fun cancelLegacyCompanionAlarm(context: Context, taskId: Int) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            val intent = Intent(context, RecurringReminderReceiver::class.java).apply {
                action = ACTION_CHAIN
                putExtra(EXTRA_TASK_ID, taskId)
                data = android.net.Uri.parse("todo-reminder://$taskId")
            }
            alarmManager.cancel(
                PendingIntent.getBroadcast(
                    context,
                    LEGACY_COMPANION_REQUEST_CODE_BASE + taskId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }

        private fun companionPendingIntent(context: Context, taskId: Int): PendingIntent {
            val intent = Intent(context, RecurringReminderReceiver::class.java).apply {
                action = ACTION_CHAIN
                putExtra(EXTRA_TASK_ID, taskId)
                data = android.net.Uri.parse("todo-reminder://companion/$taskId")
            }
            return PendingIntent.getBroadcast(
                context,
                COMPANION_REQUEST_CODE_BASE + taskId,
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
        private fun intervalKey(taskId: Int) = "$KEY_INTERVAL_PREFIX$taskId"
        private fun titleKey(taskId: Int) = "$KEY_TITLE_PREFIX$taskId"
        private fun bodyKey(taskId: Int) = "$KEY_BODY_PREFIX$taskId"
        private fun activePluginKey(taskId: Int) = "$KEY_ACTIVE_PLUGIN_PREFIX$taskId"
        private fun previousPluginKey(taskId: Int) = "$KEY_PREVIOUS_PLUGIN_PREFIX$taskId"
        private fun sequenceKey(taskId: Int) = "$KEY_SEQUENCE_PREFIX$taskId"

        private fun jsonString(value: String): String {
            return "\"" + value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r") + "\""
        }

        private const val HOUR_MILLIS = 60L * 60L * 1000L
    }
}
