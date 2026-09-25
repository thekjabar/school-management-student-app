package com.kurdistanstudentprotection.ksp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class BusWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, widgetData))
        }
    }

    private fun render(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.bus_widget)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("ksp://track")),
        )

        val title = data.getString("ksp_title", null) ?: context.getString(R.string.app_name)
        views.setTextViewText(R.id.widget_title, title)

        val state = data.getString("ksp_state", null)
        if (state == null) {
            views.setTextViewText(R.id.widget_updated, "")
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_message, context.getString(R.string.widget_description))
            hideRows(views, 0)
            return views
        }

        val updatedAt = data.getString("ksp_updated_ms", null)?.toLongOrNull() ?: 0L
        val stale = System.currentTimeMillis() - updatedAt > STALE_AFTER_MS
        views.setTextViewText(R.id.widget_updated, data.getString("ksp_updated", "") ?: "")

        if (state != "ok") {
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_message, data.getString("ksp_message", "") ?: "")
            hideRows(views, 0)
            return views
        }

        views.setViewVisibility(R.id.widget_message, View.GONE)
        val notLive = data.getString("ksp_not_live", "") ?: ""
        val count = (data.getString("ksp_count", "0")?.toIntOrNull() ?: 0).coerceIn(0, ROWS.size)
        for (i in 0 until count) {
            val (row, name, line) = ROWS[i]
            val live = data.getString("ksp_live_$i", "0") == "1"
            views.setViewVisibility(row, View.VISIBLE)
            val child = data.getString("ksp_id_$i", "") ?: ""
            if (child.isNotEmpty()) {
                views.setOnClickPendingIntent(
                    row,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("ksp://track?child=" + Uri.encode(child)),
                    ),
                )
            }
            views.setTextViewText(name, data.getString("ksp_name_$i", "") ?: "")
            views.setTextViewText(line, if (live && stale) notLive else data.getString("ksp_line_$i", "") ?: "")
        }
        hideRows(views, count)
        return views
    }

    private fun hideRows(views: RemoteViews, from: Int) {
        for (i in from until ROWS.size) views.setViewVisibility(ROWS[i].first, View.GONE)
    }

    private companion object {
        const val STALE_AFTER_MS = 10 * 60 * 1000L
        val ROWS = listOf(
            Triple(R.id.widget_row_0, R.id.widget_name_0, R.id.widget_line_0),
            Triple(R.id.widget_row_1, R.id.widget_name_1, R.id.widget_line_1),
            Triple(R.id.widget_row_2, R.id.widget_name_2, R.id.widget_line_2),
        )
    }
}
