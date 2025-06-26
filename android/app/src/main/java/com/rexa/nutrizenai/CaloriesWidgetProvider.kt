package com.rexa.nutrizenai

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.widget.RemoteViews
import android.util.Log

/**
 * Implementation of App Widget functionality for displaying calories.
 */
class CaloriesWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "CaloriesWidget"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        
        // Method to manually save test data to SharedPreferences
        // This can be called from anywhere to test widget functionality
        fun saveTestData(context: Context) {
            try {
                Log.d(TAG, "🧪 Saving test data to SharedPreferences")
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                
                // Clear existing widget values to avoid confusion
                editor.remove("flutter.flutter.appWidgetCaloriesPercent")
                editor.remove("flutter.flutter.appWidgetCaloriesConsumed")
                editor.remove("flutter.flutter.appWidgetCaloriesGoal")
                editor.remove("flutter.flutter.appWidgetLastUpdated")
                
                // Save test values with the correct flutter. prefix
                // (The Flutter SharedPreferences adds one "flutter." prefix automatically)
                // Use putLong instead of putInt to match Flutter's storage type
                editor.putLong("flutter.appWidgetCaloriesPercent", 75L)
                editor.putLong("flutter.appWidgetCaloriesConsumed", 1500L)
                editor.putLong("flutter.appWidgetCaloriesGoal", 2000L)
                editor.putString("flutter.appWidgetLastUpdated", "12:34")
                editor.apply()
                
                // Log all SharedPreferences for debugging
                Log.d(TAG, "✅ Test data saved successfully with the following values:")
                Log.d(TAG, "  • flutter.appWidgetCaloriesPercent = 75")
                Log.d(TAG, "  • flutter.appWidgetCaloriesConsumed = 1500")
                Log.d(TAG, "  • flutter.appWidgetCaloriesGoal = 2000")
                Log.d(TAG, "  • flutter.appWidgetLastUpdated = 12:34")
                
                Log.d(TAG, "✅ Test data saved successfully")
                
                // Trigger widget update
                val intent = Intent(context, CaloriesWidgetProvider::class.java)
                intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                
                // Use existing appWidgetIds
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, CaloriesWidgetProvider::class.java)
                )
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                context.sendBroadcast(intent)
                
                Log.d(TAG, "📣 Widget update broadcast sent for ${appWidgetIds.size} widgets")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error saving test data", e)
            }
        }
        
        // Debug method to dump all preferences (accessible from companion object)
        fun dumpAllSharedPreferences(preferences: SharedPreferences) {
            try {
                Log.d(TAG, "===== SHARED PREFERENCES DUMP =====")
                val allEntries = preferences.all
                
                if (allEntries.isEmpty()) {
                    Log.d(TAG, "⚠️ NO SHARED PREFERENCES FOUND!")
                } else {
                    for (key in allEntries.keys.sorted()) {
                        val value = allEntries[key]
                        Log.d(TAG, "  • $key = ${value?.toString() ?: "null"}")
                    }
                }
                
                // Specifically check for our expected keys with all possible prefixes
                val keySuffixes = listOf(
                    "appWidgetCaloriesPercent",
                    "appWidgetCaloriesConsumed",
                    "appWidgetCaloriesGoal",
                    "appWidgetLastUpdated"
                )
                
                val prefixes = listOf("", "flutter.", "flutter.flutter.")
                
                Log.d(TAG, "🔎 CHECKING EXPECTED KEYS:")
                for (prefix in prefixes) {
                    Log.d(TAG, "  PREFIX: '$prefix'")
                    for (suffix in keySuffixes) {
                        val key = prefix + suffix
                        val exists = allEntries.containsKey(key)
                        val value = if (exists) allEntries[key]?.toString() ?: "null" else "NOT FOUND"
                        Log.d(TAG, "    • $key: ${if (exists) "✅" else "❌"} $value")
                    }
                }
                
                Log.d(TAG, "===== END OF SHARED PREFERENCES DUMP =====")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error dumping preferences", e)
            }
        }
    }
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "🔄 onUpdate called for ${appWidgetIds.size} widgets")
        
        try {
            // Get the shared preferences where Flutter stores the data
            val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Dump all preferences to log for debugging
            dumpAllSharedPreferences(preferences)
            
            // Initialize default values
            var percentage = 0
            var caloriesConsumed = 0
            var caloriesGoal = 2000
            var lastUpdated = ""
            
            // Try all possible prefixes for the keys and use the first valid value found
            val prefixes = listOf("flutter.", "", "flutter.flutter.")
            
            // Try to find valid data for each value using different prefixes
            for (prefix in prefixes) {
                // Skip if we already found valid values
                if (percentage > 0 && caloriesConsumed > 0 && caloriesGoal > 0 && lastUpdated.isNotEmpty()) {
                    break
                }
                
                try {
                    // Try to get percentage
                    if (percentage <= 0) {
                        val key = prefix + "appWidgetCaloriesPercent"
                        if (preferences.contains(key)) {
                            // Try as Long first (Flutter stores numbers as Long in SharedPreferences)
                            try {
                                percentage = preferences.getLong(key, 0L).toInt()
                                Log.d(TAG, "✅ Found percentage with prefix '$prefix': $percentage")
                            } catch (e: ClassCastException) {
                                // If that fails, try as Int
                                percentage = preferences.getInt(key, 0)
                                Log.d(TAG, "✅ Found percentage (as Int) with prefix '$prefix': $percentage")
                            }
                        }
                    }
                    
                    // Try to get calories consumed
                    if (caloriesConsumed <= 0) {
                        val key = prefix + "appWidgetCaloriesConsumed"
                        if (preferences.contains(key)) {
                            try {
                                caloriesConsumed = preferences.getLong(key, 0L).toInt()
                                Log.d(TAG, "✅ Found caloriesConsumed with prefix '$prefix': $caloriesConsumed")
                            } catch (e: ClassCastException) {
                                caloriesConsumed = preferences.getInt(key, 0)
                                Log.d(TAG, "✅ Found caloriesConsumed (as Int) with prefix '$prefix': $caloriesConsumed")
                            }
                        }
                    }
                    
                    // Try to get calories goal
                    if (caloriesGoal <= 0) {
                        val key = prefix + "appWidgetCaloriesGoal"
                        if (preferences.contains(key)) {
                            try {
                                caloriesGoal = preferences.getLong(key, 2000L).toInt()
                                Log.d(TAG, "✅ Found caloriesGoal with prefix '$prefix': $caloriesGoal")
                            } catch (e: ClassCastException) {
                                caloriesGoal = preferences.getInt(key, 2000)
                                Log.d(TAG, "✅ Found caloriesGoal (as Int) with prefix '$prefix': $caloriesGoal")
                            }
                        }
                    }
                    
                    // Try to get last updated
                    if (lastUpdated.isEmpty()) {
                        val key = prefix + "appWidgetLastUpdated"
                        if (preferences.contains(key)) {
                            lastUpdated = preferences.getString(key, "") ?: ""
                            if (lastUpdated.isNotEmpty()) {
                                Log.d(TAG, "✅ Found lastUpdated with prefix '$prefix': $lastUpdated")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error reading values with prefix '$prefix': ${e.message}")
                }
            }
            
            // Use default values if we still have invalid values
            if (percentage < 0 || percentage > 100) percentage = 0
            if (caloriesConsumed < 0) caloriesConsumed = 0
            if (caloriesGoal <= 0) caloriesGoal = 2000
            if (lastUpdated.isEmpty()) lastUpdated = "--:--"
            
            Log.d(TAG, "📊 FINAL WIDGET DATA VALUES:")
            Log.d(TAG, "  • Percentage: $percentage%")
            Log.d(TAG, "  • Calories: $caloriesConsumed/$caloriesGoal kcal")
            Log.d(TAG, "  • Last Updated: $lastUpdated")
            
            // For each widget that belongs to this provider
            for (appWidgetId in appWidgetIds) {
                // Create a RemoteViews object for the widget layout
                val views = RemoteViews(context.packageName, R.layout.calories_widget)
                
                // Update the widget views with the actual values
                views.setTextViewText(R.id.percentage_text, "$percentage%")
                views.setTextViewText(R.id.calories_text, "$caloriesConsumed / $caloriesGoal kcal")
                views.setTextViewText(R.id.last_updated, "Updated: $lastUpdated")
                views.setProgressBar(R.id.calories_progress, 100, percentage, false)
                
                // Set up the refresh button to open the app
                val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (intent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, 
                        0, 
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.refresh_button, pendingIntent)
                    // Also make the whole widget clickable to open the app
                    views.setOnClickPendingIntent(R.id.calories_text, pendingIntent)
                }
                
                // Tell the AppWidgetManager to update the widget
                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "✅ Widget $appWidgetId updated successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating widget", e)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Log all received intents for debugging
        Log.d(TAG, "📩 onReceive: action=${intent.action}")
        
        // Handle custom actions
        if (intent.action == "com.rexa.nutrizenai.ACTION_TEST_WIDGET") {
            Log.d(TAG, "🧪 Received test widget action")
            saveTestData(context)
        }
    }
} 