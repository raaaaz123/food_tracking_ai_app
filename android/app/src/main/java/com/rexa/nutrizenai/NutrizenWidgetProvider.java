package com.rexa.nutrizenai;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.content.Intent;
import android.app.PendingIntent;
import android.os.Build;
import android.util.Log;

public class NutrizenWidgetProvider extends AppWidgetProvider {
    private static final String NUTRIZEN_PREFS = "nutrizen_widget_prefs";
    private static final String TAG = "NutrizenWidget";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate called for " + appWidgetIds.length + " widgets");
        
        // Update each widget
        for (int appWidgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        try {
        // Load the layout resource
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.nutrition_widget_layout);

        // Get SharedPreferences
        SharedPreferences prefs = context.getSharedPreferences(NUTRIZEN_PREFS, Context.MODE_PRIVATE);

            // Get nutrition data
            int calories = prefs.getInt("nutrition_calories", 0);
            int caloriesGoal = prefs.getInt("nutrition_calories_goal", 2000);
            
            // Calculate percentage
            int percentage = 0;
            if (caloriesGoal > 0) {
                percentage = (int) Math.min(100, Math.round((calories * 100.0) / caloriesGoal));
            }
            
            // Set percentage text and progress
            views.setTextViewText(R.id.percentage_text, percentage + "%");
            views.setProgressBar(R.id.nutrition_progress, 100, percentage, false);
            
            // Set nutrition text
            views.setTextViewText(R.id.nutrition_text, calories + " / " + caloriesGoal + " kcal");

            // Set last updated time
            String lastUpdated = prefs.getString("nutrition_last_updated", "--:--");
            views.setTextViewText(R.id.last_updated, "Updated: " + lastUpdated);

        // Create an Intent to launch the app when the widget is clicked
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent != null) {
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags |= PendingIntent.FLAG_IMMUTABLE;
            }
            PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, flags);
                
                // Set click listeners for the whole widget
                views.setOnClickPendingIntent(R.id.refresh_button, pendingIntent);
        }

        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views);
            
            Log.d(TAG, "Widget updated successfully with: " + calories + "/" + caloriesGoal + " kcal");
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }
} 