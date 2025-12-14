package com.ledgerzero.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import android.view.View
import android.app.PendingIntent
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class LedgerZeroWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Open App on Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_header, pendingIntent)

                // 1. Update TBB
                // Use formatted string from Dart if available, fallback to double
                val tbbStr = widgetData.getString("tbb_amount_str", null)
                if (tbbStr != null) {
                    setTextViewText(R.id.widget_tbb_amount, tbbStr)
                } else {
                    val tbb = widgetData.getFloat("tbb_amount", 0.0f).toDouble()
                    setTextViewText(R.id.widget_tbb_amount, "%.2f".format(tbb))
                }

                // 2. Update Categories (Assuming 4 slots: category_1 to category_4)
                val categoriesJson = widgetData.getString("categories_json", "[]")
                val categories = JSONArray(categoriesJson)

                for (i in 0 until 4) {
                    val viewIdName = "widget_category_container_$i"
                    val resId = context.resources.getIdentifier(viewIdName, "id", context.packageName)

                    if (resId != 0) {
                        if (i < categories.length()) {
                            val cat = categories.getJSONObject(i)
                            val name = cat.getString("name")

                            // Use formatted string if available
                            val amountStr = if (cat.has("formattedAvailable")) {
                                cat.getString("formattedAvailable")
                            } else {
                                "%.2f".format(cat.getDouble("available"))
                            }

                            setViewVisibility(resId, View.VISIBLE)

                            val nameId = context.resources.getIdentifier("widget_category_name_$i", "id", context.packageName)
                            val amountId = context.resources.getIdentifier("widget_category_amount_$i", "id", context.packageName)

                            setTextViewText(nameId, name)
                            setTextViewText(amountId, amountStr)
                        } else {
                            setViewVisibility(resId, View.GONE)
                        }
                    }
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
