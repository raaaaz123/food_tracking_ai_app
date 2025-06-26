import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/nutrition_info.dart';

class FoodLogService {
  static const String _foodLogKey = 'food_logs';
  static const int _maxRecentItems = 10;

  Future<void> addFoodLog(NutritionInfo nutritionInfo, String mealType, {DateTime? logDate}) async {
    try {
     
      
      // Get existing logs
      final prefs = await SharedPreferences.getInstance();
      final String? logsJson = prefs.getString(_foodLogKey);

      // Parse existing logs or create empty list
      List<dynamic> logs = [];
      if (logsJson != null) {
        logs = jsonDecode(logsJson);
      }

      // Process additionalInfo to ensure it's serializable
      Map<String, dynamic> processedAdditionalInfo = {};
      nutritionInfo.additionalInfo.forEach((key, value) {
        if (value is List) {
          processedAdditionalInfo[key] = value.join(', ');
        } else {
          processedAdditionalInfo[key] = value;
        }
      });

      // Add mealType and timestamp to additionalInfo
      processedAdditionalInfo['mealType'] = mealType;
      
      // IMPORTANT: Always use the provided logDate if available, never default to current date
      DateTime timestamp;
      
      // Default logDate to current date if not provided (this line is the critical fix)
      logDate = logDate ?? DateTime.now();
      
    
      
      // Set a reasonable time based on meal type
      final now = DateTime.now();
      int hour;
      
      switch (mealType.toLowerCase()) {
        case 'breakfast':
          hour = 8;
          break;
        case 'lunch':
          hour = 13;
          break;
        case 'dinner':
          hour = 19;
          break;
        case 'snack':
          hour = 16;
          break;
        default:
          hour = now.hour;
      }
      
      // Create a new DateTime with the date from logDate and appropriate hour
      timestamp = DateTime(
        logDate.year, 
        logDate.month, 
        logDate.day, 
        hour, 
        0, 
        0
      );
      

      
      processedAdditionalInfo['timestamp'] = timestamp.toIso8601String();

      // Create the food data object
      Map<String, dynamic> foodData = {
        'foodName': nutritionInfo.foodName,
        'brandName': nutritionInfo.brandName,
        'calories': nutritionInfo.calories,
        'protein': nutritionInfo.protein,
        'carbs': nutritionInfo.carbs,
        'fat': nutritionInfo.fat,
        'servingSize': nutritionInfo.servingSize,
        'ingredients': nutritionInfo.ingredients,
        'additionalInfo': processedAdditionalInfo,
      };

      // Add to logs
      logs.add(foodData);

      // Save back to SharedPreferences
      await prefs.setString(_foodLogKey, jsonEncode(logs));
    } catch (e) {
    
      throw Exception('Failed to save food log: $e');
    }
  }

  /// New method for logging food directly from the Food Database
  Future<void> logFood(NutritionInfo foodItem, {DateTime? logDate}) async {
    try {
     
      
      // Default to "Meal" if no mealType is specified
      String mealType = "Meal";

      // If additionalInfo contains mealType, use that instead
      if (foodItem.additionalInfo.containsKey('mealType')) {
        mealType = foodItem.additionalInfo['mealType'] as String;
      }

      // Add the food to the log with the specified date
      await addFoodLog(foodItem, mealType, logDate: logDate);
    } catch (e) {
    
      throw Exception('Failed to log food: $e');
    }
  }

  Future<List<NutritionInfo>> getFoodLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? logsJson = prefs.getString(_foodLogKey);

      if (logsJson == null) {
        return [];
      }

      final List<dynamic> logs = jsonDecode(logsJson);
      List<NutritionInfo> foodLogs = [];

      for (var log in logs) {
        try {
          final nutritionInfo = NutritionInfo(
            foodName: log['foodName'] ?? '',
            brandName: log['brandName'] ?? '',
            calories: log['calories']?.toDouble() ?? 0,
            protein: log['protein']?.toDouble() ?? 0,
            carbs: log['carbs']?.toDouble() ?? 0,
            fat: log['fat']?.toDouble() ?? 0,
            servingSize: log['servingSize'] ?? '',
            ingredients: _parseIngredients(log['ingredients']),
            additionalInfo: log['additionalInfo'] ?? {},
          );
          foodLogs.add(nutritionInfo);
        } catch (e) {
          // Skip invalid entries
 
        }
      }

      return foodLogs;
    } catch (e) {

      return [];
    }
  }

  List<String> _parseIngredients(dynamic ingredients) {
    if (ingredients is List) {
      return ingredients.map((item) => item.toString()).toList();
    } else if (ingredients is String) {
      return ingredients.split(',').map((item) => item.trim()).toList();
    }
    return [];
  }

  Future<List<NutritionInfo>> getRecentlyEaten() async {
    try {
      final logs = await getFoodLogs();

      // Sort by timestamp (most recent first)
      logs.sort((a, b) {
        final aTimestamp = a.additionalInfo['timestamp'] as String?;
        final bTimestamp = b.additionalInfo['timestamp'] as String?;

        if (aTimestamp == null || bTimestamp == null) return 0;

        return DateTime.parse(bTimestamp).compareTo(DateTime.parse(aTimestamp));
      });

      // Return only the most recent items
      if (logs.length > _maxRecentItems) {
        return logs.sublist(0, _maxRecentItems);
      }

      return logs;
    } catch (e) {
    
      return [];
    }
  }

  /// Gets recent food items with a specific count limit
  Future<List<NutritionInfo>> getRecentFoods({int limit = 5}) async {
    final logs = await getRecentlyEaten();
    return logs.take(limit).toList();
  }

  Future<Map<String, double>> getDailyNutritionTotals(
      {required DateTime date}) async {
    try {
      final logs = await getFoodLogs();
      final dateString = DateFormat('yyyy-MM-dd').format(date);

      // Filter logs for the specified date
      final logsForDate = logs.where((log) {
        if (!log.additionalInfo.containsKey('timestamp')) return false;

        final timestamp = log.additionalInfo['timestamp'] as String?;
        if (timestamp == null) return false;

        final logDate = DateTime.parse(timestamp);
        return DateFormat('yyyy-MM-dd').format(logDate) == dateString;
      }).toList();

      // Calculate totals
      Map<String, double> totals = {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };

      for (var log in logsForDate) {
        totals['calories'] = (totals['calories'] ?? 0) + log.calories;
        totals['protein'] = (totals['protein'] ?? 0) + log.protein;
        totals['carbs'] = (totals['carbs'] ?? 0) + log.carbs;
        totals['fat'] = (totals['fat'] ?? 0) + log.fat;
      }

      return totals;
    } catch (e) {

      return {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };
    }
  }

  /// Clears the entire food log
  Future<void> clearFoodLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_foodLogKey);
    } catch (e) {
      throw Exception('Failed to clear food log: $e');
    }
  }

  /// Removes a specific food item from the log by matching its timestamp
  Future<void> removeFoodItem(NutritionInfo foodItem) async {
    try {
      if (!foodItem.additionalInfo.containsKey('timestamp')) {
        throw Exception('Food item does not have a timestamp');
      }

      // Get all logs
      final logs = await getFoodLogs();
      final timestamp = foodItem.additionalInfo['timestamp'];

      // Filter out the item to remove
      final filteredLogs = logs
          .where((item) =>
              !item.additionalInfo.containsKey('timestamp') ||
              item.additionalInfo['timestamp'] != timestamp)
          .toList();

      // Convert back to JSON format
      final List<Map<String, dynamic>> jsonLogs = filteredLogs
          .map((item) => {
                'foodName': item.foodName,
                'brandName': item.brandName,
                'calories': item.calories,
                'protein': item.protein,
                'carbs': item.carbs,
                'fat': item.fat,
                'servingSize': item.servingSize,
                'ingredients': item.ingredients,
                'additionalInfo': item.additionalInfo,
              })
          .toList();

      // Save back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_foodLogKey, jsonEncode(jsonLogs));
    } catch (e) {
      throw Exception('Failed to remove food item: $e');
    }
  }

  Future<List<NutritionInfo>> getFoodLogsForDate(DateTime date) async {
    try {
      final logs = await getFoodLogs();
      final dateString = DateFormat('yyyy-MM-dd').format(date);

      // Filter logs for the specified date
      return logs.where((log) {
        if (!log.additionalInfo.containsKey('timestamp')) return false;

        final timestamp = log.additionalInfo['timestamp'] as String?;
        if (timestamp == null) return false;

        final logDate = DateTime.parse(timestamp);
        return DateFormat('yyyy-MM-dd').format(logDate) == dateString;
      }).toList();
    } catch (e) {

      return [];
    }
  }
}
