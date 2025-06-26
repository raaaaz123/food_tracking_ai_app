import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/food_hive_service.dart';

/// Utility class to manage and calculate user's food logging streak
class StreakUtil {
  static const String _streakKey = 'food_logging_streak';
  static const String _lastLoggedDateKey = 'last_logged_date';

  /// Get the current streak data including streak count and weekly logging history
  static Future<Map<String, dynamic>> getStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the weekly logging history (last 7 days)
      final weeklyLogging = await _getWeeklyLoggingHistory();
      
      // Calculate the updated streak
      final updatedStreak = await _calculateCurrentStreak();
      
      // Save the updated streak
      await prefs.setInt(_streakKey, updatedStreak);
      
      return {
        'currentStreak': updatedStreak,
        'weeklyLogging': weeklyLogging,
      };
    } catch (e) {

      return {
        'currentStreak': 0,
        'weeklyLogging': List.filled(7, false),
      };
    }
  }
  
  /// Calculate the user's current streak based on food logging history
  static Future<int> _calculateCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Check if today has any food logs
      final todayLogs = await FoodHiveService.getFoodsForDate(today);
      final hasTodayLogs = todayLogs.isNotEmpty;
      
      // If no food has been logged today, check if we had a streak yesterday
      if (!hasTodayLogs) {
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayLogs = await FoodHiveService.getFoodsForDate(yesterday);
        
        // If there were no logs yesterday either, there's no current streak
        if (yesterdayLogs.isEmpty) {
          return 0;
        }
        
        // Get last streak count
        final lastStreak = prefs.getInt(_streakKey) ?? 0;
        
        // If we had a streak yesterday but no logs today, the streak is still
        // valid but doesn't include today
        return lastStreak;
      }
      
      // If food was logged today, update the last logged date
      await prefs.setString(_lastLoggedDateKey, today.toIso8601String());
      
      // Start counting streak from today
      int streak = 1;
      
      // Check previous consecutive days
      DateTime checkDate = today.subtract(const Duration(days: 1));
      
      while (true) {
        final logsForDate = await FoodHiveService.getFoodsForDate(checkDate);
        if (logsForDate.isEmpty) {
          // No food logged on this date, streak ends
          break;
        }
        
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      
      return streak;
    } catch (e) {

      return 0;
    }
  }
  
  /// Get the food logging history for the last 7 days
  static Future<List<bool>> _getWeeklyLoggingHistory() async {
    try {
      final now = DateTime.now();
      final List<bool> weeklyHistory = [];
      
      // Check the last 7 days
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final logs = await FoodHiveService.getFoodsForDate(dateOnly);
        
        // Day is only counted as logged if at least one food item was added
        weeklyHistory.add(logs.isNotEmpty);
      }
      
      return weeklyHistory;
    } catch (e) {

      return List.filled(7, false);
    }
  }
  
  /// Update the streak data when a new food is logged
  static Future<void> updateStreakOnFoodLogged(DateTime logDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);
      
      // Update the last logged date if food is logged today
      if (logDay.isAtSameMomentAs(today)) {
        await prefs.setString(_lastLoggedDateKey, today.toIso8601String());
      }
      
      // Recalculate and save the streak
      final currentStreak = await _calculateCurrentStreak();
      await prefs.setInt(_streakKey, currentStreak);
      

    } catch (e) {

    }
  }
} 