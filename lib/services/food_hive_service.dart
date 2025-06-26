import 'package:hive_flutter/hive_flutter.dart';
import '../models/food_hive_model.dart';
import '../models/nutrition_info.dart';
import 'package:flutter/foundation.dart';
import '../services/widget_service.dart';

class FoodHiveService {
  static const String _boxName = 'foodBox';
  static Box<FoodHiveModel>? _foodBox;

  // Initialize Hive and open the food box
  static Future<void> init() async {
    try {

      
      // Verify adapter is registered before opening the box
      if (!Hive.isAdapterRegistered(1)) {
      
        try {
      
          Hive.registerAdapter(FoodHiveModelAdapter());
        
        } catch (adapterError) {
         
          // Try with override as last resort
          try {
         
            Hive.registerAdapter(FoodHiveModelAdapter(), override: true);
          
          } catch (forceError) {
         
          }
        }
      } else {
     
      }
      
      // Open the box with correct type
     
      _foodBox = await Hive.openBox<FoodHiveModel>(_boxName);
    
    } catch (e) {
    
      
      try {
        // Try to recover - use untyped box as fallback
     
        final box = await Hive.openBox(_boxName);
    
        
        // Check if items can be cast to FoodHiveModel
        if (box.isNotEmpty) {
       
          try {
            // Attempt to read an item to verify type
            final testItem = box.getAt(0);
        
            
            if (testItem is FoodHiveModel) {
            
              _foodBox = box as Box<FoodHiveModel>;
            } else {
          
              // Keep a reference to the untyped box for now
              _foodBox = null;
            }
          } catch (e) {
         
            _foodBox = null;
          }
        } else {
       
          // For an empty box, it's safe to cast
          _foodBox = box as Box<FoodHiveModel>;
        }
        
        if (_foodBox != null) {
      
        } else {
    
        }
      } catch (fallbackError) {
      
        // Create an empty food box as last resort to prevent null errors
        _foodBox = null;
      }
    }
  }

  // Add food to Hive
  static Future<void> addFood(NutritionInfo food, {DateTime? logDate}) async {
    try {
   
      
      // Ensure box is initialized
      if (_foodBox == null) {
      
        await init();
        
        // Check if initialization was successful
        if (_foodBox == null) {
          throw Exception('Failed to initialize food box');
        }
      }

      // Create a clean date without time components
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final effectiveDate = logDate ?? today;
      final cleanDate = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);

      // Ensure we're not using a future date
      final finalDate = cleanDate.isAfter(today) ? today : cleanDate;
  

      // Add timestamp to additionalInfo
      final additionalInfo = Map<String, dynamic>.from(food.additionalInfo);
      additionalInfo['timestamp'] = finalDate.toIso8601String();
      
      // Add required mealType if missing
      if (!additionalInfo.containsKey('mealType')) {
        additionalInfo['mealType'] = 'Lunch';
      
      }

      // Create Hive model
    
      final hiveFood = FoodHiveModel(
        foodName: food.foodName,
        brandName: food.brandName ?? '',
        calories: food.calories,
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
        servingSize: food.servingSize,
        ingredients: food.ingredients,
        additionalInfo: additionalInfo,
      );

      // Add to Hive
   
      await _foodBox!.add(hiveFood);
      
      // Add code to update the widget
      try {
        await WidgetService.updateNutritionWidget();
      } catch (e) {
        debugPrint('Error updating widget after adding food: $e');
      }
    } catch (e) {
    
      
      // Try to reinitialize and add again with a simpler approach
      try {
       
        
        // Force initialize with untyped box
        final untypedBox = await Hive.openBox(_boxName);
      
        
        // Create a simple Map instead of typed object
        final Map<String, dynamic> simpleFoodMap = {
          'foodName': food.foodName,
          'brandName': food.brandName ?? '',
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'servingSize': food.servingSize ?? '1 serving',
          'ingredients': food.ingredients,
          'additionalInfo': {
            'timestamp': DateTime.now().toIso8601String(),
            'mealType': 'Lunch'
          }
        };
        
        // Save as regular Map
      
        await untypedBox.add(simpleFoodMap);
       
      } catch (retryError) {
      
        throw Exception('Failed to add food to log after retry: $retryError');
      }
    }
  }

  // Get all food items
  static List<NutritionInfo> getAllFoods() {
    if (_foodBox == null) return [];
    return _foodBox!.values.map((food) => food.toNutritionInfo()).toList();
  }

  // Get food items for a specific date
  static Future<List<NutritionInfo>> getFoodsForDate(DateTime date) async {
    List<NutritionInfo> results = [];
    
    try {
   
      
      // Initialize food box if needed
      if (_foodBox == null) {
       
        await init();
      }
      
      // Get box handle - either use existing _foodBox or open the box safely
      Box box;
      try {
        if (_foodBox != null) {

          box = _foodBox!;
        } else if (Hive.isBoxOpen(_boxName)) {
        
          box = Hive.box(_boxName);
        } else {
       
          box = await Hive.openBox(_boxName);
        }
      } catch (boxError) {
      
        // Last resort - try with dynamic type
     
        box = await Hive.openBox(_boxName);
      }
      
      // Normalize date for comparison (strip time)
      final cleanDate = DateTime(date.year, date.month, date.day);
    
      
      // Loop through all items in the box
      for (int i = 0; i < box.length; i++) {
        try {
          final item = box.getAt(i);
          
          if (item is FoodHiveModel) {
            // Handle FoodHiveModel type
            if (item.additionalInfo.containsKey('timestamp')) {
              final timestamp = item.additionalInfo['timestamp'];
              if (timestamp != null) {
                final foodDate = DateTime.parse(timestamp);
                final cleanFoodDate = DateTime(foodDate.year, foodDate.month, foodDate.day);
                
              
                
                if (cleanFoodDate.isAtSameMomentAs(cleanDate)) {
                  results.add(item.toNutritionInfo());

                }
              }
            }
          } else if (item is Map) {
            // Handle Map type
            final additionalInfo = item['additionalInfo'];
            if (additionalInfo is Map && additionalInfo.containsKey('timestamp')) {
              try {
                final timestamp = additionalInfo['timestamp'];
                if (timestamp != null) {
                  final foodDate = DateTime.parse(timestamp.toString());
                  final cleanFoodDate = DateTime(foodDate.year, foodDate.month, foodDate.day);
                  
                  if (cleanFoodDate.isAtSameMomentAs(cleanDate)) {
                    // Convert Map to NutritionInfo
                    final nutritionInfo = NutritionInfo(
                      foodName: (item['foodName'] as String?) ?? 'Unknown Food',
                      brandName: (item['brandName'] as String?) ?? '',
                      calories: _parseDouble(item['calories']) ?? 0,
                      protein: _parseDouble(item['protein']) ?? 0,
                      carbs: _parseDouble(item['carbs']) ?? 0,
                      fat: _parseDouble(item['fat']) ?? 0,
                      servingSize: (item['servingSize'] as String?) ?? '1 serving',
                      ingredients: _parseStringList(item['ingredients']),
                      additionalInfo: _parseMap(additionalInfo)
                    );
                    
                    results.add(nutritionInfo);
                 
                  }
                }
              } catch (dateError) {
            
              }
            }
          }
        } catch (e) {
        
        }
      }
      
     
      return results;
      
    } catch (e) {

      return [];
    }
  }
  
  // Helper methods for data conversion
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    return [];
  }
  
  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  // Get today's food items
  static Future<List<NutritionInfo>> getTodayFoods() async {
    final today = DateTime.now();
    return await getFoodsForDate(today);
  }

  // Delete a food item
  static Future<void> deleteFood(String timestamp) async {
    if (_foodBox == null) return;

    final foodToDelete = _foodBox!.values
        .firstWhere((food) => food.additionalInfo['timestamp'] == timestamp);
    await foodToDelete.delete();

    // Update the widget after deleting food
    try {
      await WidgetService.updateNutritionWidget();
    } catch (e) {
      debugPrint('Error updating widget after deleting food: $e');
    }
  }

  // Clear all food items
  static Future<void> clearAllFoods() async {
    if (_foodBox == null) return;
    await _foodBox!.clear();
  }

  // Get total calories for a specific date
  static Future<double> getTotalCaloriesForDate(DateTime date) async {
    final foods = await getFoodsForDate(date);
    return foods.fold<double>(0.0, (sum, food) => sum + food.calories);
  }

  // Get total calories for today
  static Future<double> getTodayCalories() async {
    return await getTotalCaloriesForDate(DateTime.now());
  }

  // Get recent food items (last 7 days)
  static List<NutritionInfo> getRecentFoods({int limit = 5}) {
    if (_foodBox == null) return [];

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return _foodBox!.values
        .where((food) {
          final foodDate = DateTime.parse(food.additionalInfo['timestamp']);
          return foodDate.isAfter(sevenDaysAgo);
        })
        .map((food) => food.toNutritionInfo())
        .take(limit)
        .toList();
  }

  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  static Future<void> updateFood(DateTime date, NutritionInfo oldFood, NutritionInfo newFood) async {
    try {
      if (_foodBox == null) {
        await init();
        if (_foodBox == null) {
          throw Exception('Failed to initialize food box');
        }
      }

      // Find the food item to update
      final foodToUpdate = _foodBox!.values.firstWhere(
        (food) => 
          food.foodName == oldFood.foodName && 
          food.additionalInfo['timestamp'] == oldFood.additionalInfo['timestamp'],
        orElse: () => throw Exception('Food item not found'),
      );

      // Update the food item
      final updatedFood = FoodHiveModel.fromNutritionInfo(newFood);
      await foodToUpdate.delete();
      await _foodBox!.add(updatedFood);

      // Update the widget after modifying food
      try {
        await WidgetService.updateNutritionWidget();
      } catch (e) {
        debugPrint('Error updating widget after updating food: $e');
      }
    } catch (e) {
     
      rethrow;
    }
  }
} 