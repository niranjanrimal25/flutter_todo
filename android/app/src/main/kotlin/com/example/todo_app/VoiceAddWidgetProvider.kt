package com.example.todo_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Small 2x1 launcher widget that opens the in-app voice command flow. */
class VoiceAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(
                context.packageName,
                R.layout.voice_add_widget,
            ).apply {
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("todo_app://voice"),
                )
                setOnClickPendingIntent(R.id.voice_widget_root, launchIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
