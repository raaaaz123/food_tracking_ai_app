import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/food_nutrition_ai_service.dart';

class GoogleHealthService {
  // Keys for storing connection status
  static const String _isConnectedKey = 'health_connected';
  static const String _lastSyncKey = 'health_last_sync';

  // Flag to track if connected to health services
  static bool _isConnected = false;
  static final Random _random = Random();

  // Check if service is connected
  static Future<bool> isConnected() async {
    try {
      // First check if we have a stored value
      final prefs = await SharedPreferences.getInstance();
      _isConnected = prefs.getBool(_isConnectedKey) ?? false;
      return _isConnected;
    } catch (e) {
      
      return false;
    }
  }

  // Connect to health service
  static Future<bool> connect() async {
    try {
      // Simulate connection process with delay
      await Future.delayed(const Duration(seconds: 1));

      // Store connection status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isConnectedKey, true);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      _isConnected = true;
      return true;
    } catch (e) {
 
      return false;
    }
  }

  // Disconnect from health service
  static Future<bool> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isConnectedKey, false);
      _isConnected = false;
      return true;
    } catch (e) {

      return false;
    }
  }

  // Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync == null) return null;
    return DateTime.parse(lastSync);
  }

  // Get step counts for a date range
  static Future<Map<DateTime, int>> getStepsForDateRange(
      DateTime start, DateTime end) async {
    // Generate mock step data for each day in the range
    final result = <DateTime, int>{};

    // Generate data for each day in the range
    for (var day = start;
        day.isBefore(end.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
      final dayKey = DateTime(day.year, day.month, day.day);

      // Generate more realistic step patterns
      // Weekends typically have fewer steps
      bool isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      int baseSteps = isWeekend ? 3000 : 5000;
      int maxVariation = isWeekend ? 4000 : 6000;

      result[dayKey] = baseSteps + _random.nextInt(maxVariation);
    }

    await Future.delayed(const Duration(milliseconds: 600));
    return result;
  }

  // Get today's health data
  static Future<Map<String, dynamic>> getTodayHealthData() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Create realistic mock data
    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    // Generate steps - lower on weekends
    final steps =
        isWeekend ? 4000 + _random.nextInt(3000) : 6000 + _random.nextInt(4000);

    // Active minutes roughly correlates with steps
    final activeMinutes = (steps / 150).round();

    // Calories burned based on steps and active minutes
    final caloriesBurned = (steps * 0.04 + activeMinutes * 5).round();

    // Distance in km based on steps (average stride length)
    final distanceKm = steps * 0.0007;

    // Heart rate - normal resting range with slight variation
    final heartRate = 65 + _random.nextInt(20);

    return {
      'steps': steps,
      'activeMinutes': activeMinutes,
      'caloriesBurned': caloriesBurned,
      'distanceKm': double.parse(distanceKm.toStringAsFixed(1)),
      'heartRate': heartRate,
    };
  }

  // Analyze activity with AI (mock)
  static Future<Map<String, dynamic>> analyzeActivityWithAI(
      Map<String, dynamic> healthData,
      Map<String, dynamic>? userDetails) async {
    // Mock analysis data with delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Extract data from health data
    final steps = healthData['steps'] as int? ?? 0;
    final activeMin = healthData['activeMinutes'] as int? ?? 0;
    final caloriesBurned = healthData['caloriesBurned'] as int? ?? 0;

    // Determine activity level based on steps and active minutes
    String activityLevel;
    if (steps > 10000 || activeMin > 60) {
      activityLevel = 'High';
    } else if (steps > 5000 || activeMin > 30) {
      activityLevel = 'Moderate';
    } else {
      activityLevel = 'Low';
    }

    // Calculate nutrient estimations based on calories burned
    // These are rough estimates for demonstration
    final double proteinBurned = caloriesBurned * 0.05;
    final double carbsBurned = caloriesBurned * 0.15;
    final double fatBurned = caloriesBurned * 0.08;

    // Calculate hydration needs based on activity and weight if available
    double baseHydration = 2.0;
    if (userDetails != null && userDetails['weight'] != null) {
      // Add 30ml per kg of weight for baseline hydration
      final weight = userDetails['weight'] as double? ?? 70.0;
      final isMetric = userDetails['isMetric'] as bool? ?? true;

      // Convert weight to kg if not metric
      final weightKg = isMetric ? weight : weight * 0.453592;

      // Base hydration in liters (30ml per kg / 1000)
      baseHydration = (weightKg * 30) / 1000;
    }

    // Add extra hydration based on activity
    final activityHydration = steps / 10000 * 0.5;
    final totalHydration = baseHydration + activityHydration;

    return {
      'caloriesBurned': caloriesBurned,
      'proteinBurned': proteinBurned.round(),
      'carbsBurned': carbsBurned.round(),
      'fatBurned': fatBurned.round(),
      'activityLevel': activityLevel,
      'hydrationNeeded': double.parse(totalHydration.toStringAsFixed(1)),
    };
  }
}
