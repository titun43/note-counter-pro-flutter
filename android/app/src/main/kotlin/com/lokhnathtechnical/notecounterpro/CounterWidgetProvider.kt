package com.lokhnathtechnical.notecounterpro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import java.text.DecimalFormat

/**
 * Home Screen Widget Provider for Note Counter Pro
 *
 * Widget features:
 * - Quick counter display (₹2000, ₹500, ₹200, ₹100 denominations)
 * - Today's cash in/out summary
 * - Quick action buttons: Count, Smart Pay, Khata, Bill
 *
 * Data is synced from Flutter app via SharedPreferences:
 * - "widget_qty_2000", "widget_qty_500", "widget_qty_200", "widget_qty_100"
 * - "widget_today_in", "widget_today_out"
 *
 * Buttons use deep links to open specific screens in the app:
 * - notecounterpro://counter
 * - notecounterpro://smartpay
 * - notecounterpro://khata
 * - notecounterpro://bill
 */
class CounterWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "NoteCounterWidgetPrefs"
        private const val KEY_QTY_2000 = "widget_qty_2000"
        private const val KEY_QTY_500 = "widget_qty_500"
        private const val KEY_QTY_200 = "widget_qty_200"
        private const val KEY_QTY_100 = "widget_qty_100"
        private const val KEY_TODAY_IN = "widget_today_in"
        private const val KEY_TODAY_OUT = "widget_today_out"

        private const val DEEP_LINK_COUNTER = "notecounterpro://counter"
        private const val DEEP_LINK_SMARTPAY = "notecounterpro://smartpay"
        private const val DEEP_LINK_KHATA = "notecounterpro://khata"
        private const val DEEP_LINK_BILL = "notecounterpro://bill"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Handle manual update broadcasts from Flutter app
        if (intent.action == "com.lokhnathtechnical.notecounterpro.UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, CounterWidgetProvider::class.java)
            )
            for (appWidgetId in appWidgetIds) {
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Read denomination quantities from SharedPreferences
        val qty2000 = prefs.getInt(KEY_QTY_2000, 0)
        val qty500 = prefs.getInt(KEY_QTY_500, 0)
        val qty200 = prefs.getInt(KEY_QTY_200, 0)
        val qty100 = prefs.getInt(KEY_QTY_100, 0)

        // Calculate total
        val total = (qty2000 * 2000) + (qty500 * 500) + (qty200 * 200) + (qty100 * 100)

        // Read today's summary
        val todayIn = prefs.getInt(KEY_TODAY_IN, 0)
        val todayOut = prefs.getInt(KEY_TODAY_OUT, 0)

        // Build RemoteViews
        val views = RemoteViews(context.packageName, R.layout.widget_counter_layout)

        // Set denomination quantities
        views.setTextViewText(R.id.qty_2000, qty2000.toString())
        views.setTextViewText(R.id.qty_500, qty500.toString())
        views.setTextViewText(R.id.qty_200, qty200.toString())
        views.setTextViewText(R.id.qty_100, qty100.toString())

        // Set total
        views.setTextViewText(R.id.widget_total_label, "₹${formatNumber(total)}")

        // Set today's summary
        views.setTextViewText(R.id.widget_today_in, "In ₹${formatNumber(todayIn)}")
        views.setTextViewText(R.id.widget_today_out, "Out ₹${formatNumber(todayOut)}")

        // Set click listeners for quick action buttons
        views.setOnClickPendingIntent(R.id.btn_open_counter, createDeepLinkIntent(context, DEEP_LINK_COUNTER))
        views.setOnClickPendingIntent(R.id.btn_smart_pay, createDeepLinkIntent(context, DEEP_LINK_SMARTPAY))
        views.setOnClickPendingIntent(R.id.btn_khata, createDeepLinkIntent(context, DEEP_LINK_KHATA))
        views.setOnClickPendingIntent(R.id.btn_bill, createDeepLinkIntent(context, DEEP_LINK_BILL))

        // Also make the header area clickable to open app
        views.setOnClickPendingIntent(R.id.widget_root, createDeepLinkIntent(context, DEEP_LINK_COUNTER))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Create a PendingIntent that opens the app with a deep link.
     * The deep link is handled by MainActivity's intent-filter.
     */
    private fun createDeepLinkIntent(context: Context, deepLink: String): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            deepLink.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Format a number with Indian comma style (e.g., 12500 → "12,500").
     * Uses DecimalFormat with Indian grouping pattern.
     */
    private fun formatNumber(value: Int): String {
        if (value == 0) return "0"
        return try {
            val formatter = DecimalFormat("#,##,##0")
            formatter.format(value)
        } catch (e: Exception) {
            value.toString()
        }
    }
}
