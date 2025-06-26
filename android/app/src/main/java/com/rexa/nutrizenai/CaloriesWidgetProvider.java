package com.rexa.nutrizenai;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.util.Log;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Implementation of App Widget functionality for displaying calories.
 */
public class CaloriesWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "CaloriesWidget";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    public static final String ACTION_WIDGET_UPDATE = "com.rexa.nutrizenai.ACTION_WIDGET_UPDATE";
    
    /**
     * Static method to force update all widgets
     */
    public static void updateWidgets(Context context) {
        Intent intent = new Intent(context, CaloriesWidgetProvider.class);
        intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        int[] ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(new ComponentName(context, CaloriesWidgetProvider.class));
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
        context.sendBroadcast(intent);
    }
    
    // Create a broadcast receiver to handle direct updates
    private static final BroadcastReceiver sUpdateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (ACTION_WIDGET_UPDATE.equals(intent.getAction())) {
                updateWidgets(context);
            }
        }
    };
    
    @Override
    public void onEnabled(Context context) {
        // Called when the first widget is created
        Log.d(TAG, "onEnabled called - first widget created");
        
        // Register for broadcast updates
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_WIDGET_UPDATE);
        context.getApplicationContext().registerReceiver(sUpdateReceiver, filter);
    }

    @Override
    public void onDisabled(Context context) {
        // Called when the last widget is disabled
        Log.d(TAG, "onDisabled called - last widget removed");
        
        // Unregister broadcast receiver
        try {
            context.getApplicationContext().unregisterReceiver(sUpdateReceiver);
        } catch (Exception e) {
            Log.e(TAG, "Error unregistering receiver", e);
        }
    }
    
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate called for " + appWidgetIds.length + " widgets");
        
        try {
            // Get the shared preferences where Flutter stores the data
            SharedPreferences preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            
            // Dump all preferences for debugging
            dumpAllPreferences(preferences);
            
            // Initialize default values
            int percentage = 0;
            int caloriesConsumed = 0;
            int caloriesGoal = 2000;
            String lastUpdated = "";
            
            // Try all possible prefixes for the keys and use the first valid value found
            List<String> prefixes = Arrays.asList("flutter.", "", "flutter.flutter.");
            List<String> keySuffixes = Arrays.asList(
                "appWidgetCaloriesPercent",
                "appWidgetCaloriesConsumed",
                "appWidgetCaloriesGoal",
                "appWidgetLastUpdated"
            );
            
            // Try to find valid data using different prefixes
            for (String prefix : prefixes) {
                // Skip if we already found all valid values
                if (percentage > 0 && caloriesConsumed > 0 && caloriesGoal > 0 && !lastUpdated.isEmpty()) {
                    break;
                }
                
                try {
                    // Try to get percentage
                    if (percentage <= 0) {
                        String key = prefix + "appWidgetCaloriesPercent";
                        if (preferences.contains(key)) {
                            try {
                                // Try as Long first (Flutter stores numbers as Long)
                                percentage = (int)preferences.getLong(key, 0);
                                Log.d(TAG, "Found percentage with prefix '" + prefix + "': " + percentage);
                            } catch (ClassCastException e) {
                                // Try as Int
                                percentage = preferences.getInt(key, 0);
                                Log.d(TAG, "Found percentage (as Int) with prefix '" + prefix + "': " + percentage);
                            }
                        }
                    }
                    
                    // Try to get calories consumed
                    if (caloriesConsumed <= 0) {
                        String key = prefix + "appWidgetCaloriesConsumed";
                        if (preferences.contains(key)) {
                            try {
                                caloriesConsumed = (int)preferences.getLong(key, 0);
                                Log.d(TAG, "Found caloriesConsumed with prefix '" + prefix + "': " + caloriesConsumed);
                            } catch (ClassCastException e) {
                                caloriesConsumed = preferences.getInt(key, 0);
                                Log.d(TAG, "Found caloriesConsumed (as Int) with prefix '" + prefix + "': " + caloriesConsumed);
                            }
                        }
                    }
                    
                    // Try to get calories goal
                    if (caloriesGoal <= 0) {
                        String key = prefix + "appWidgetCaloriesGoal";
                        if (preferences.contains(key)) {
                            try {
                                caloriesGoal = (int)preferences.getLong(key, 2000);
                                Log.d(TAG, "Found caloriesGoal with prefix '" + prefix + "': " + caloriesGoal);
                            } catch (ClassCastException e) {
                                caloriesGoal = preferences.getInt(key, 2000);
                                Log.d(TAG, "Found caloriesGoal (as Int) with prefix '" + prefix + "': " + caloriesGoal);
                            }
                        }
                    }
                    
                    // Try to get last updated
                    if (lastUpdated.isEmpty()) {
                        String key = prefix + "appWidgetLastUpdated";
                        if (preferences.contains(key)) {
                            lastUpdated = preferences.getString(key, "");
                            if (lastUpdated != null && !lastUpdated.isEmpty()) {
                                Log.d(TAG, "Found lastUpdated with prefix '" + prefix + "': " + lastUpdated);
                            }
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error reading values with prefix '" + prefix + "': " + e.getMessage());
                }
            }
            
            // Use default values if we still have invalid values
            if (percentage < 0 || percentage > 100) percentage = 0;
            if (caloriesConsumed < 0) caloriesConsumed = 0;
            if (caloriesGoal <= 0) caloriesGoal = 2000;
            if (lastUpdated == null || lastUpdated.isEmpty()) lastUpdated = "--:--";
            
            Log.d(TAG, "FINAL WIDGET DATA VALUES:");
            Log.d(TAG, "  • Percentage: " + percentage + "%");
            Log.d(TAG, "  • Calories: " + caloriesConsumed + "/" + caloriesGoal + " kcal");
            Log.d(TAG, "  • Last Updated: " + lastUpdated);
            
            // For each widget that belongs to this provider
            for (int appWidgetId : appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId, percentage, caloriesConsumed, caloriesGoal, lastUpdated);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }
    
    // Debug method to dump all preferences
    private void dumpAllPreferences(SharedPreferences preferences) {
        try {
            Log.d(TAG, "===== SHARED PREFERENCES DUMP =====");
            Map<String, ?> allEntries = preferences.getAll();
            
            if (allEntries.isEmpty()) {
                Log.d(TAG, "⚠️ NO SHARED PREFERENCES FOUND!");
            } else {
                // Sort keys for easier reading
                List<String> keys = new ArrayList<>(allEntries.keySet());
                java.util.Collections.sort(keys);
                
                for (String key : keys) {
                    Object value = allEntries.get(key);
                    Log.d(TAG, "  • " + key + " = " + (value != null ? value.toString() : "null"));
                }
            }
            
            // Specifically check for our expected keys with all possible prefixes
            List<String> keySuffixes = Arrays.asList(
                "appWidgetCaloriesPercent",
                "appWidgetCaloriesConsumed",
                "appWidgetCaloriesGoal",
                "appWidgetLastUpdated"
            );
            
            List<String> prefixes = Arrays.asList("", "flutter.", "flutter.flutter.");
            
            Log.d(TAG, "🔎 CHECKING EXPECTED KEYS:");
            for (String prefix : prefixes) {
                Log.d(TAG, "  PREFIX: '" + prefix + "'");
                for (String suffix : keySuffixes) {
                    String key = prefix + suffix;
                    boolean exists = allEntries.containsKey(key);
                    String value = exists ? (allEntries.get(key) != null ? allEntries.get(key).toString() : "null") : "NOT FOUND";
                    Log.d(TAG, "    • " + key + ": " + (exists ? "✓" : "✗") + " " + value);
                }
            }
            
            Log.d(TAG, "===== END OF SHARED PREFERENCES DUMP =====");
        } catch (Exception e) {
            Log.e(TAG, "Error dumping preferences", e);
        }
    }
    
    private void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId, 
                                int percentage, int caloriesConsumed, int caloriesGoal, String lastUpdated) {
        try {
            // Get the layout for the widget
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.calories_widget);
            
            // Update the views with data
            views.setTextViewText(R.id.percentage_text, percentage + "%");
            views.setTextViewText(R.id.calories_text, caloriesConsumed + " / " + caloriesGoal + " kcal");
            views.setTextViewText(R.id.last_updated, "Updated: " + lastUpdated);
            views.setProgressBar(R.id.calories_progress, 100, percentage, false);
            
            // Create an Intent to launch the main app when widget is clicked
            Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (intent != null) {
                PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, 
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                
                // Set click behavior for buttons and text
                views.setOnClickPendingIntent(R.id.refresh_button, pendingIntent);
                views.setOnClickPendingIntent(R.id.calories_text, pendingIntent);
            }
            
            // Tell the AppWidgetManager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views);
            Log.d(TAG, "Widget " + appWidgetId + " updated successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget ID " + appWidgetId, e);
        }
    }
} 