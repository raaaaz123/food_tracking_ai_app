import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_details.dart';
import '../models/user_metrics_history.dart';

/// A storage service that uses Hive exclusively for data persistence.
/// This replaces the older PreferencesService which used SharedPreferences.
class StorageService {
  // Box names
  static const String userDetailsBoxName = 'userDetails';
  static const String nutritionPlanBoxName = 'nutritionPlan';
  static const String settingsBoxName = 'appSettings';
  static const String timelineProjectionBoxName = 'timelineProjection';
  static const String userMetricsHistoryBoxName = 'userMetricsHistory';
  
  // Keys
  static const String currentUserKey = 'currentUser';
  static const String currentPlanKey = 'currentPlan';
  static const String timelineProjectionKey = 'timelineProjection';
  static const String startingMetricsKey = 'startingMetrics';
  
  /// Initialize Hive and open required boxes
  static Future<void> initialize() async {
   
    
    try {
      // Open boxes - adapters should be registered in main.dart
      await Hive.openBox<UserDetails>(userDetailsBoxName);
      await Hive.openBox(nutritionPlanBoxName); // Use untyped box
      await Hive.openBox<dynamic>(settingsBoxName);
      await Hive.openBox<dynamic>(timelineProjectionBoxName);
      await Hive.openBox<UserMetricsHistory>(userMetricsHistoryBoxName);
    
      // Check if nutrition plan exists but has wrong format
      final nutritionBox = await Hive.openBox(nutritionPlanBoxName);
      final rawPlan = nutritionBox.get(currentPlanKey);
      
      if (rawPlan != null) {
      
        // Verify data can be converted to expected format
        try {
          if (rawPlan is Map) {
            final converted = {
              'dailyCalories': int.parse(rawPlan['dailyCalories'].toString()),
              'protein': int.parse(rawPlan['protein'].toString()),
              'carbs': int.parse(rawPlan['carbs'].toString()),
              'fats': int.parse(rawPlan['fats'].toString()),
            };
          
          } else {
       
          }
        } catch (e) {
        
        }
      } else {
 
      }
    } catch (e) {

    }
  }
  
  /// Check if required data exists in Hive
  static Future<bool> hasRequiredData() async {
    final userBox = await Hive.openBox<UserDetails>(userDetailsBoxName);
    final nutritionBox = await Hive.openBox<Map<String, dynamic>>(nutritionPlanBoxName);
    
    final hasUserDetails = userBox.get(currentUserKey) != null;
    final hasNutritionPlan = nutritionBox.get(currentPlanKey) != null;
    
    return hasUserDetails && hasNutritionPlan;
  }
  
  /// Save user details to Hive
  static Future<void> saveUserDetails(UserDetails userDetails) async {
    final userBox = await Hive.openBox<UserDetails>(userDetailsBoxName);
    await userBox.put(currentUserKey, userDetails);
  }
  
  /// Get user details from Hive
  static Future<UserDetails?> getUserDetails() async {
    final userBox = await Hive.openBox<UserDetails>(userDetailsBoxName);
    return userBox.get(currentUserKey);
  }
  
  /// Save nutrition plan to Hive
  static Future<void> saveNutritionPlan(Map<String, dynamic> plan) async {
    try {

      
      // Ensure the plan has all required keys with proper types
      final Map<String, dynamic> validatedPlan = {};
      
      for (final key in ['dailyCalories', 'protein', 'carbs', 'fats']) {
        if (plan.containsKey(key)) {
          final value = plan[key];
          
          if (value is int) {
            validatedPlan[key] = value;
          } else if (value is double) {
            validatedPlan[key] = value.round();
          } else if (value is String) {
            // Try to parse string to int
            final parsedValue = int.tryParse(value) ?? double.tryParse(value)?.round();
            validatedPlan[key] = parsedValue ?? 0;
          } else {
         
            validatedPlan[key] = key == 'dailyCalories' ? 2000 : key == 'protein' ? 100 : key == 'carbs' ? 250 : 67;
          }
        } else {
        
          validatedPlan[key] = key == 'dailyCalories' ? 2000 : key == 'protein' ? 100 : key == 'carbs' ? 250 : 67;
        }
      }
      
      final box = await Hive.openBox(nutritionPlanBoxName);
      await box.put(currentPlanKey, validatedPlan);
   
    } catch (e) {
    
      throw Exception('Failed to save nutrition plan: $e');
    }
  }
  
  /// Get nutrition plan from Hive
  static Future<Map<String, dynamic>?> getNutritionPlan() async {
    try {
   
      final box = await Hive.openBox(nutritionPlanBoxName);
      final data = box.get(currentPlanKey);
      
      if (data == null) {
       
        return null;
      }
      
 
      
      // Handle different data formats
      if (data is Map) {
        // Convert to proper format ensuring correct types
        try {
          final Map<String, dynamic> result = {};
          
          // Process each key to ensure proper types
          for (final key in ['dailyCalories', 'protein', 'carbs', 'fats']) {
            if (data.containsKey(key)) {
              final value = data[key];
              if (value is int) {
                result[key] = value;
              } else if (value is double) {
                result[key] = value.round(); // Convert to int if it's a double
              } else if (value is String) {
                // Try to parse the string to a number
                final parsedValue = int.tryParse(value) ?? double.tryParse(value)?.round();
                if (parsedValue != null) {
                  result[key] = parsedValue;
                } else {
                 
                  result[key] = 0; // Default value
                }
              } else {
              
                result[key] = 0; // Default value
              }
            } else {
            
              result[key] = 0; // Default value
            }
          }
          
         
          return result;
        } catch (e) {
         
          
          // If all else fails, try to manually recreate the plan with sensible defaults
          final Map<String, dynamic> fallbackPlan = {
            'dailyCalories': 2000,
            'protein': 100,
            'carbs': 250,
            'fats': 67,
          };
          
          // Try to save this fallback plan
          try {
         
            await saveNutritionPlan(fallbackPlan);
          
            return fallbackPlan;
          } catch (saveError) {
          
            return null;
          }
        }
      } else {
      
        return null;
      }
    } catch (e) {
      print('StorageService: Error getting nutrition plan: $e');
      return null;
    }
  }
  
  /// Clear all user data
  static Future<void> clearAllData() async {
    final userBox = await Hive.openBox<UserDetails>(userDetailsBoxName);
    final nutritionBox = await Hive.openBox<Map<String, dynamic>>(nutritionPlanBoxName);
    final settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    
    await userBox.clear();
    await nutritionBox.clear();
    await settingsBox.clear();
  }
  
  /// Clear only user details
  static Future<void> clearUserDetails() async {
    final userBox = await Hive.openBox<UserDetails>(userDetailsBoxName);
    await userBox.delete(currentUserKey);
  }
  
  /// Set whether this is the first time using the app
  static Future<void> setFirstTime(bool isFirstTime) async {
    await saveSetting('isFirstTime', isFirstTime);
  }
  
  /// Check if this is the first time using the app
  static Future<bool> isFirstTime() async {
    return await getSetting('isFirstTime', defaultValue: true);
  }
  
  /// Save a setting value
  static Future<void> saveSetting(String key, dynamic value) async {
    final settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    await settingsBox.put(key, value);
  }
  
  /// Get a setting value
  static Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    final settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    return settingsBox.get(key, defaultValue: defaultValue);
  }
  
  /// Save AI timeline projection data
  static Future<void> saveTimelineProjection(Map<String, dynamic> projection) async {
    final timelineBox = await Hive.openBox<dynamic>(timelineProjectionBoxName);
    await timelineBox.put(timelineProjectionKey, projection);
  }
  
  /// Get AI timeline projection data
  static Future<Map<String, dynamic>?> getTimelineProjection() async {
    try {
      final timelineBox = await Hive.openBox<dynamic>(timelineProjectionBoxName);
      final data = timelineBox.get(timelineProjectionKey);
      
      if (data == null) {
        return null;
      }
      
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      
      return null;
    } catch (e) {
      print('StorageService: Error getting timeline projection: $e');
      return null;
    }
  }
  
  /// Save starting metrics (weight and height) to permanent storage
  static Future<void> saveStartingMetrics(UserMetricsHistory metrics) async {
    try {
      final metricsBox = await Hive.openBox<UserMetricsHistory>(userMetricsHistoryBoxName);
      
      // Only save if no starting metrics exist yet
      if (!metricsBox.containsKey(startingMetricsKey)) {
        await metricsBox.put(startingMetricsKey, metrics);
      }
    } catch (e) {
      print('StorageService: Error saving starting metrics: $e');
    }
  }
  
  /// Get starting metrics from storage
  static Future<UserMetricsHistory?> getStartingMetrics() async {
    try {
      final metricsBox = await Hive.openBox<UserMetricsHistory>(userMetricsHistoryBoxName);
      return metricsBox.get(startingMetricsKey);
    } catch (e) {
      print('StorageService: Error getting starting metrics: $e');
      return null;
    }
  }
  
  /// Check if starting metrics exist
  static Future<bool> hasStartingMetrics() async {
    try {
      final metricsBox = await Hive.openBox<UserMetricsHistory>(userMetricsHistoryBoxName);
      return metricsBox.containsKey(startingMetricsKey);
    } catch (e) {
      print('StorageService: Error checking starting metrics: $e');
      return false;
    }
  }
} 