package com.example.todo_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var reminderChannel: MethodChannel? = null
    private var pendingTodoId: Int? = null
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        reminderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> {
                        dartReady = true
                        dispatchPendingTodo()
                        result.success(null)
                    }
                    "scheduleRecurringReminder" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val taskId = (arguments?.get("taskId") as? Number)?.toInt()
                        val title = arguments?.get("title") as? String
                        val body = arguments?.get("body") as? String
                        val tone = arguments?.get("tone") as? String
                            ?: "assets/sounds/alarm.wav"
                        val firstAt = (arguments?.get("firstAtMillis") as? Number)?.toLong()
                        val intervalHours =
                            (arguments?.get("intervalHours") as? Number)?.toInt() ?: 2

                        if (taskId == null || title == null || body == null || firstAt == null) {
                            result.error("invalid_arguments", "Missing reminder arguments", null)
                        } else {
                            RecurringReminderReceiver.schedule(
                                context = applicationContext,
                                taskId = taskId,
                                title = title,
                                body = body,
                                tone = tone,
                                firstAtMillis = firstAt,
                                intervalHours = intervalHours,
                            )
                            result.success(null)
                        }
                    }
                    "cancelRecurringReminder" -> {
                        val taskId = (call.arguments as? Number)?.toInt()
                        if (taskId == null) {
                            result.error("invalid_arguments", "Missing task id", null)
                        } else {
                            RecurringReminderReceiver.cancel(applicationContext, taskId)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        rememberTodoFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        rememberTodoFromIntent(intent)
    }

    private fun rememberTodoFromIntent(intent: Intent?) {
        val todoId = intent?.getIntExtra(EXTRA_OPEN_TODO_ID, -1) ?: -1
        if (todoId > 0) {
            pendingTodoId = todoId
            dispatchPendingTodo()
        }
    }

    private fun dispatchPendingTodo() {
        if (!dartReady) return
        val todoId = pendingTodoId ?: return
        reminderChannel?.invokeMethod("openTodo", todoId)
        pendingTodoId = null
    }

    companion object {
        const val CHANNEL_NAME = "todo_app/notification"
        const val EXTRA_OPEN_TODO_ID = "open_todo_id"
    }
}
