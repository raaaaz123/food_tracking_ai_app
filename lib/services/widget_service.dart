import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/food_hive_service.dart';
import '../utils/date_utils.dart';
import 'package:flutter/foundation.dart';
import '../services/nutrition_service.dart';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WidgetService {
  // Constants for widget IDs
  static const String _appWidgetProvider = 'CaloriesWidgetProvider';
  static const String _widgetCalories = 'nutrition_calories';
  static const String _widgetProtein = 'nutrition_protein';
  static const String _widgetCarbs = 'nutrition_carbs';
  static const String _widgetFat = 'nutrition_fat';
  static const String _widgetCaloriesGoal = 'nutrition_calories_goal';
  static const String _widgetProteinGoal = 'nutrition_protein_goal';
  static const String _widgetCarbsGoal = 'nutrition_carbs_goal';
  static const String _widgetFatGoal = 'nutrition_fat_goal';
  static const String _widgetDate = 'nutrition_date';
  static const String _widgetChartData = 'nutrition_chart_data';
  static const String _widgetRemainingCalories = 'nutrition_remaining_calories';
  static const String _widgetCaloriesBurned = 'nutrition_calories_burned';

  // Keys for the widget data - THESE MUST MATCH EXACTLY what's used in the Kotlin code
  static const String appWidgetCaloriesPercent = 'appWidgetCaloriesPercent';
  static const String appWidgetCaloriesGoal = 'appWidgetCaloriesGoal';
  static const String appWidgetCaloriesConsumed = 'appWidgetCaloriesConsumed';
  static const String appWidgetLastUpdated = 'appWidgetLastUpdated';

  // Flag to track if widgets are supported/available
  static bool _widgetsAvailable = false;

  // Initialize the home widget package
  static Future<void> initWidget() async {
    try {
      debugPrint('🚀 Initializing Widget Service...');
      
      // Initialize communication with the widget
      await HomeWidget.setAppGroupId('com.rexa.nutrizenai');
      
      // Register for widget clicks
      HomeWidget.widgetClicked.listen(_handleWidgetClick);
      
      _widgetsAvailable = true;
      debugPrint('✅ Widget initialization successful, proceeding to update widget data');
      
      // Update widget with current data
      await updateNutritionWidget();
    } catch (e) {
      debugPrint('❌ Error initializing widget: $e');
      _widgetsAvailable = false;
    }
  }

  // Handle when the widget is clicked
  static void _handleWidgetClick(Uri? uri) {
    debugPrint('🔔 Widget was clicked: $uri');
  }

  /// Updates the widget with the latest nutrition data
  static Future<void> updateNutritionWidget() async {
    try {
      debugPrint('🔄 Starting widget data update process...');
      
      // Get the nutrition plan to retrieve the calorie goal
      final nutritionPlan = await NutritionService.getNutritionPlan();
      if (nutritionPlan == null) {
        debugPrint('❌ No nutrition plan available for widget update');
        return;
      }

      // Get today's food logs to calculate consumed calories
      final todayFoods = await FoodHiveService.getTodayFoods();
      
      // Calculate raw consumed values (same way as in home_screen.dart)
      final consumedCalories = todayFoods.fold(0.0, (sum, food) => sum + food.calories);
      
      // Get the calorie goal (same way as in home_screen.dart)
      final calorieGoal = (nutritionPlan['dailyCalories'] as num).toDouble();
      
      // Calculate percentage
      final caloriePercent = ((consumedCalories / calorieGoal) * 100).clamp(0.0, 100.0).round();
      
      debugPrint('📊 WIDGET UPDATE: Data prepared - calories=$consumedCalories/$calorieGoal ($caloriePercent%)');
      
      // Save to SharedPreferences DIRECTLY - IMPORTANT: Do NOT use "flutter." prefix here
      // as SharedPreferences in Flutter already adds the "flutter." prefix automatically
      final prefs = await SharedPreferences.getInstance();
      
      // IMPORTANT: Save with BOTH formats to guarantee compatibility
      // 1. Save without prefix (SharedPreferences will add "flutter." automatically)
      await prefs.setInt(appWidgetCaloriesPercent, caloriePercent);
      await prefs.setInt(appWidgetCaloriesGoal, calorieGoal.round());
      await prefs.setInt(appWidgetCaloriesConsumed, consumedCalories.round());
      await prefs.setString(appWidgetLastUpdated, DateFormat('HH:mm').format(DateTime.now()));
      
      // 2. Also save with explicit "flutter." prefix for backward compatibility
      // (This will result in "flutter.flutter." keys)
      await prefs.setInt('flutter.$appWidgetCaloriesPercent', caloriePercent);
      await prefs.setInt('flutter.$appWidgetCaloriesGoal', calorieGoal.round());
      await prefs.setInt('flutter.$appWidgetCaloriesConsumed', consumedCalories.round());
      await prefs.setString('flutter.$appWidgetLastUpdated', DateFormat('HH:mm').format(DateTime.now()));
      
      // Method 2: Using HomeWidget package - provides a third way to save data
      bool? success1 = await HomeWidget.saveWidgetData<int>(appWidgetCaloriesPercent, caloriePercent);
      bool? success2 = await HomeWidget.saveWidgetData<int>(appWidgetCaloriesGoal, calorieGoal.round());
      bool? success3 = await HomeWidget.saveWidgetData<int>(appWidgetCaloriesConsumed, consumedCalories.round());
      bool? success4 = await HomeWidget.saveWidgetData<String>(appWidgetLastUpdated, DateFormat('HH:mm').format(DateTime.now()));
      
      debugPrint('🔄 HomeWidget save results: $success1, $success2, $success3, $success4');
      
      // Log what we saved
      debugPrint('📝 WIDGET DATA SAVED with multiple prefixes for compatibility:');
      debugPrint('  • appWidgetCaloriesPercent = $caloriePercent');
      debugPrint('  • appWidgetCaloriesGoal = ${calorieGoal.round()}');
      debugPrint('  • appWidgetCaloriesConsumed = ${consumedCalories.round()}');
      debugPrint('  • appWidgetLastUpdated = ${DateFormat('HH:mm').format(DateTime.now())}');
      
      // Update the widget on both platforms
      await HomeWidget.updateWidget(
        name: _appWidgetProvider,
        androidName: 'com.rexa.nutrizenai.CaloriesWidgetProvider',
        iOSName: 'CaloriesWidget',
        qualifiedAndroidName: 'com.rexa.nutrizenai.CaloriesWidgetProvider',
      );
      
      debugPrint('🎯 Widget update request sent!');
    } catch (e) {
      debugPrint('❌ Error updating nutrition widget: $e');
    }
  }
  
  // Helper method to retrieve widget data
  static Future<dynamic> _getWidgetData(String key, dynamic defaultValue) async {
    try {
      return await HomeWidget.getWidgetData(key) ?? defaultValue;
    } catch (e) {
      debugPrint('Error getting widget data for $key: $e');
      return defaultValue;
    }
  }

  // Prepare chart data for the widget visualization
  static List<Map<String, dynamic>> _prepareChartData(
    Map<String, dynamic> nutrition,
    Map<String, dynamic> goals,
  ) {
    return [
      {
        'name': 'Calories',
        'value': nutrition['calories'],
        'goal': goals['calories'],
        'percentage': (nutrition['calories'] / goals['calories'] * 100).clamp(0, 100).round(),
        'color': '#6C63FF',
      },
      {
        'name': 'Protein',
        'value': nutrition['protein'],
        'goal': goals['protein'],
        'percentage': (nutrition['protein'] / goals['protein'] * 100).clamp(0, 100).round(),
        'color': '#FF5555',
      },
      {
        'name': 'Carbs',
        'value': nutrition['carbs'],
        'goal': goals['carbs'],
        'percentage': (nutrition['carbs'] / goals['carbs'] * 100).clamp(0, 100).round(),
        'color': '#FFA726',
      },
      {
        'name': 'Fat',
        'value': nutrition['fat'],
        'goal': goals['fat'],
        'percentage': (nutrition['fat'] / goals['fat'] * 100).clamp(0, 100).round(),
        'color': '#4FC3F7',
      },
    ];
  }
  
  // Update widget with current nutrition data
  static Future<bool> updateWidgetData(Map<String, double> nutritionData, Map<String, dynamic>? nutritionPlan) async {
    if (!_widgetsAvailable) {
      debugPrint('⚠️ Widgets not available, attempting to initialize...');
      await initWidget();
      if (!_widgetsAvailable) {
        debugPrint('❌ Widget initialization failed, cannot update widget data');
      return false;
      }
    }
    
    try {
      // Call the existing method to update the widget
      await updateNutritionWidget();
      return true;
    } catch (e) {
      debugPrint('Error updating widget data: $e');
      return false;
    }
  }
  
  // Check if we should show the widget promo dialog
  static Future<bool> shouldShowWidgetPromo() async {
    try {
      // Check if widget is available but hasn't been promoted yet
      if (!_widgetsAvailable) {
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final hasShownWidgetPromo = prefs.getBool('has_shown_widget_promo') ?? false;
      
      // Only show if we haven't shown it before
      if (!hasShownWidgetPromo) {
        // Mark as shown
        await prefs.setBool('has_shown_widget_promo', true);
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Force update the widget - can be called from anywhere in the app
  static Future<void> forceUpdateWidget() async {
    debugPrint('🔄 Force updating widget...');
    await initWidget();
    await updateNutritionWidget();
  }

  // Method to explicitly send test data to the widget for testing
  static Future<void> sendTestDataToWidget() async {
    try {
      debugPrint('🧪 Sending test data to widget');
      
      // Method 1: Save to SharedPreferences with all possible prefix combinations
      final prefs = await SharedPreferences.getInstance();
      
      // Save with no explicit prefix (will become "flutter.key" automatically)
      await prefs.setInt(appWidgetCaloriesPercent, 80);
      await prefs.setInt(appWidgetCaloriesConsumed, 1600);
      await prefs.setInt(appWidgetCaloriesGoal, 2000);
      await prefs.setString(appWidgetLastUpdated, DateFormat('HH:mm').format(DateTime.now()));
      
      // Save with explicit "flutter." prefix (will become "flutter.flutter.key")
      await prefs.setInt('flutter.$appWidgetCaloriesPercent', 80);
      await prefs.setInt('flutter.$appWidgetCaloriesConsumed', 1600);
      await prefs.setInt('flutter.$appWidgetCaloriesGoal', 2000);
      await prefs.setString('flutter.$appWidgetLastUpdated', DateFormat('HH:mm').format(DateTime.now()));
      
      // Method 2: Using HomeWidget package
      await HomeWidget.saveWidgetData<int>(appWidgetCaloriesPercent, 80);
      await HomeWidget.saveWidgetData<int>(appWidgetCaloriesConsumed, 1600);
      await HomeWidget.saveWidgetData<int>(appWidgetCaloriesGoal, 2000);
      await HomeWidget.saveWidgetData<String>(appWidgetLastUpdated, DateFormat('HH:mm').format(DateTime.now()));
      
      debugPrint('📝 TEST DATA SAVED with multiple approaches for maximum compatibility');
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: _appWidgetProvider,
        androidName: 'com.rexa.nutrizenai.CaloriesWidgetProvider',
        iOSName: 'CaloriesWidget',
        qualifiedAndroidName: 'com.rexa.nutrizenai.CaloriesWidgetProvider',
      );
      
      debugPrint('🎯 Widget update request sent!');
    } catch (e) {
      debugPrint('❌ Error sending test data to widget: $e');
    }
  }

  // Method to be called from a button in the UI to test widget updating
  static Future<bool> forceRefreshWidget() async {
    try {
      debugPrint('🔄 Force refreshing widget from UI action...');
      
      // Make sure widgets are initialized
      if (!_widgetsAvailable) {
        await initWidget();
      }
      
      // Send test data to verify widget works
      await sendTestDataToWidget();
      
      // Then update with real data
      await updateNutritionWidget();
      
      // Return success
      return true;
    } catch (e) {
      debugPrint('❌ Error in force refresh widget: $e');
      return false;
    }
  }
} 