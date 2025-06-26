package com.rexa.nutrizenai

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.content.Intent
import android.util.Log
import android.appwidget.AppWidgetManager

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        
        // Trigger widget update to ensure fresh data
        try {
            // Broadcast to update widget
            val intent = Intent(this, CaloriesWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            
            // Use existing appWidgetIds
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(this, CaloriesWidgetProvider::class.java)
            )
            
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            sendBroadcast(intent)
            
          
        } catch (e: Exception) {
           
        }
    }
} 