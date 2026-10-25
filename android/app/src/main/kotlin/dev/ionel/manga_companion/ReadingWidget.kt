package dev.ionel.manga_companion

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * "Reading" home screen widget: the titles you are reading, most recent
 * first, each with a + to log a chapter (or a check to mark it read once
 * caught up). Shows as many rows as fit.
 */
class ReadingWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val reading = ShelfStore.load(context)?.let(ShelfStore::reading)
        ids.forEach { render(context, manager, it, reading) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        val reading = ShelfStore.load(context)?.let(ShelfStore::reading)
        render(context, manager, id, reading)
    }

    private class Row(
        val root: Int,
        val open: Int,
        val title: Int,
        val current: Int,
        val total: Int,
        val bump: Int,
        val done: Int,
    )

    companion object {
        private const val HEADER_DP = 37
        private const val ROW_DP = 44

        private val ROWS = listOf(
            Row(R.id.widget_row_0, R.id.widget_row_0_open, R.id.widget_row_0_title,
                R.id.widget_row_0_current, R.id.widget_row_0_total,
                R.id.widget_row_0_bump, R.id.widget_row_0_done),
            Row(R.id.widget_row_1, R.id.widget_row_1_open, R.id.widget_row_1_title,
                R.id.widget_row_1_current, R.id.widget_row_1_total,
                R.id.widget_row_1_bump, R.id.widget_row_1_done),
            Row(R.id.widget_row_2, R.id.widget_row_2_open, R.id.widget_row_2_title,
                R.id.widget_row_2_current, R.id.widget_row_2_total,
                R.id.widget_row_2_bump, R.id.widget_row_2_done),
            Row(R.id.widget_row_3, R.id.widget_row_3_open, R.id.widget_row_3_title,
                R.id.widget_row_3_current, R.id.widget_row_3_total,
                R.id.widget_row_3_bump, R.id.widget_row_3_done),
            Row(R.id.widget_row_4, R.id.widget_row_4_open, R.id.widget_row_4_title,
                R.id.widget_row_4_current, R.id.widget_row_4_total,
                R.id.widget_row_4_bump, R.id.widget_row_4_done),
        )

        /** Redraws every placed widget from the saved shelf. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ReadingWidget::class.java))
            if (ids.isEmpty()) return
            val reading = ShelfStore.load(context)?.let(ShelfStore::reading)
            ids.forEach { render(context, manager, it, reading) }
        }

        /** [reading] is null when the saved shelf could not be read. */
        private fun render(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            reading: List<JSONObject>?,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_reading)
            val openApp = openAppIntent(context)
            views.setOnClickPendingIntent(R.id.widget_header, openApp)
            views.setOnClickPendingIntent(R.id.widget_empty, openApp)

            val titles = reading.orEmpty()
            views.setTextViewText(R.id.widget_count, if (reading == null) "" else "${titles.size}")
            views.setViewVisibility(
                R.id.widget_empty,
                if (titles.isEmpty()) View.VISIBLE else View.GONE,
            )

            // Portrait launchers report the usable height as MAX_HEIGHT.
            val options = manager.getAppWidgetOptions(widgetId)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                .takeIf { it > 0 }
                ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            val fits = ((height - HEADER_DP) / ROW_DP).coerceIn(1, ROWS.size)

            ROWS.forEachIndexed { slot, row ->
                val e = titles.getOrNull(slot)
                if (e == null || slot >= fits) {
                    views.setViewVisibility(row.root, View.GONE)
                    return@forEachIndexed
                }
                val id = e.optString("id")
                val title = e.optString("title")
                val current = e.optInt("currentChapter")
                val total = ShelfStore.total(e)
                val done = ShelfStore.isDone(e)

                views.setViewVisibility(row.root, View.VISIBLE)
                views.setTextViewText(row.title, title)
                views.setTextViewText(row.current, "$current")
                views.setTextViewText(row.total, if (total != null) "/ $total" else "/ —")
                views.setOnClickPendingIntent(row.open, openApp)

                views.setViewVisibility(row.bump, if (done) View.GONE else View.VISIBLE)
                views.setViewVisibility(row.done, if (done) View.VISIBLE else View.GONE)
                views.setContentDescription(row.bump, "Log chapter ${current + 1} of $title")
                views.setContentDescription(row.done, "Mark $title read")
                views.setOnClickPendingIntent(
                    row.bump,
                    actionIntent(context, widgetId, slot, WidgetActionReceiver.ACTION_BUMP, id),
                )
                views.setOnClickPendingIntent(
                    row.done,
                    actionIntent(context, widgetId, slot, WidgetActionReceiver.ACTION_MARK_READ, id),
                )
            }
            manager.updateAppWidget(widgetId, views)
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun actionIntent(
            context: Context,
            widgetId: Int,
            slot: Int,
            action: String,
            entryId: String,
        ): PendingIntent {
            val intent = Intent(context, WidgetActionReceiver::class.java)
                .setAction(action)
                // Extras do not make PendingIntents distinct; the data URI does.
                .setData(Uri.parse("mangacompanion://widget/$widgetId/$slot/$action"))
                .putExtra(WidgetActionReceiver.EXTRA_ENTRY_ID, entryId)
            val code = widgetId * 16 + slot * 2 +
                if (action == WidgetActionReceiver.ACTION_MARK_READ) 1 else 0
            return PendingIntent.getBroadcast(
                context, code, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}
