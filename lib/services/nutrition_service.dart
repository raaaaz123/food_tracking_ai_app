import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../services/preferences_service.dart';
import '../models/nutrition_info.dart';
import '../models/user_details.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart'; // Import the new storage service
import '../services/api_key_service.dart'; // Import the API key service

// Model class for nutrition information
class NutritionInfo {
  final String foodName;
  final String brandName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final List<String> ingredients;
  final Map<String, dynamic> additionalInfo;

  NutritionInfo({
    required this.foodName,
    required this.brandName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.ingredients = const [],
    this.additionalInfo = const {},
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      foodName: json['food_name'] ?? 'Unknown Food',
      brandName: json['brand_name'] ?? 'Generic',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbohydrates_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
      servingSize: json['serving_size'] ?? '100g',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      additionalInfo: json['additional_info'] ?? {},
    );
  }
}

class NutritionService {
  static final NutritionService _instance = NutritionService._internal();

  // Singleton pattern
  factory NutritionService() => _instance;

  NutritionService._internal();

  // API URLs
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const String _openAiApiUrl =
      'https://api.openai.com/v1/chat/completions';
      
  // Get API keys dynamically from API key service
  static String _getGeminiApiKey() => ApiKeyService.getGeminiApiKey();
  static String _getGptApiKey() => ApiKeyService.getGptApiKey();

  static Future<Map<String, dynamic>> calculateNutrition({
    required double height,
    required double weight,
    required DateTime birthDate,
    required bool isMetric,
    required int workoutsPerWeek,
    required String weightGoal,
    required double targetWeight,
    String? gender,
    String? motivationGoal,
    String? dietType,
    double? weightChangeSpeed,
  }) async {
    try {
      // Calculate age from birth date
      final now = DateTime.now();
      final age = now.year -
          birthDate.year -
          (now.month > birthDate.month ||
                  (now.month == birthDate.month && now.day >= birthDate.day)
              ? 0
              : 1);

      // Create prompt for Gemini API
      final prompt = '''
      Calculate daily nutrition requirements for a person with the following details:
      - Age: $age years
      - Height: ${height.toStringAsFixed(1)} ${isMetric ? 'cm' : 'inches'}
      - Current Weight: ${weight.toStringAsFixed(1)} ${isMetric ? 'kg' : 'lbs'}
      - Target Weight: ${targetWeight.toStringAsFixed(1)} ${isMetric ? 'kg' : 'lbs'}
      - Goal: ${weightGoal.toUpperCase()}
      - Workouts per week: $workoutsPerWeek
      - Gender: ${gender?.toUpperCase() ?? 'NOT_SPECIFIED'}

      Return only a JSON object with the following fields:
      - dailyCalories: The recommended daily calorie intake (integer)
      - protein: Daily protein intake in grams (integer)
      - carbs: Daily carbohydrate intake in grams (integer)
      - fats: Daily fat intake in grams (integer)

      Format: {"dailyCalories": X, "protein": X, "carbs": X, "fats": X}
      ''';

      try {
        // Call Gemini API
        final response = await http.post(
          Uri.parse('$_geminiApiUrl?key=$_getGeminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt}
                ]
              }
            ]
          }),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final text = responseData['candidates'][0]['content']['parts'][0]['text'];

          // Extract JSON from response (API might return additional text)
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(text);
          if (jsonMatch != null) {
            final jsonString = jsonMatch.group(0);

            try {
              // Parse and validate JSON
              final nutritionData = jsonDecode(jsonString!);

              // Ensure all values are integers
              return {
                'dailyCalories': (nutritionData['dailyCalories'] as num).toInt(),
                'protein': (nutritionData['protein'] as num).toInt(),
                'carbs': (nutritionData['carbs'] as num).toInt(),
                'fats': (nutritionData['fats'] as num).toInt(),
              };
            } catch (e) {
             
            }
          }
        }
      } catch (e) {
       
      }

      // Fallback to estimated values if API fails
      final fallbackPlan = _getFallbackNutrition(weight, workoutsPerWeek, weightGoal);
      return {
        'dailyCalories': fallbackPlan['dailyCalories'] as int,
        'protein': fallbackPlan['protein'] as int,
        'carbs': fallbackPlan['carbs'] as int,
        'fats': fallbackPlan['fats'] as int,
      };
    } catch (e) {
    
      final fallbackPlan = _getFallbackNutrition(weight, workoutsPerWeek, weightGoal);
      return {
        'dailyCalories': fallbackPlan['dailyCalories'] as int,
        'protein': fallbackPlan['protein'] as int,
        'carbs': fallbackPlan['carbs'] as int,
        'fats': fallbackPlan['fats'] as int,
      };
    }
  }

  static Map<String, int> _getFallbackNutrition(
      double weight, int workoutsPerWeek, String weightGoal) {
    // Simple fallback calculation
    double baseCals = weight * 24; // ~24 calories per kg of body weight
    double activityMultiplier = 1.2 + (workoutsPerWeek * 0.1); // Activity factor

    double calories = baseCals * activityMultiplier;

    // Adjust calories based on goal
    if (weightGoal == 'gain') {
      calories += 500; // Surplus for gaining
    } else if (weightGoal == 'lose') {
      calories -= 500; // Deficit for losing
    }

    // Macronutrient distribution
    double protein = weight * 2.0; // ~2g per kg body weight
    double fats = (calories * 0.25) / 9; // 25% of calories from fat (9 cals per gram)
    double carbs = (calories - (protein * 4) - (fats * 9)) / 4; // Remaining calories from carbs (4 cals per gram)

    return {
      'dailyCalories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fats': fats.round(),
    };
  }

  // Made public for direct access
  static Future<void> saveNutritionPlan(Map<String, int> nutritionData) async {
    try {
     
      
      // Ensure all values exist and are valid integers
      if (!nutritionData.containsKey('dailyCalories') ||
          !nutritionData.containsKey('protein') ||
          !nutritionData.containsKey('carbs') ||
          !nutritionData.containsKey('fats')) {
       
        throw Exception('Nutrition data is missing required fields');
      }
      
      await StorageService.saveNutritionPlan(nutritionData);
      
      // Verify if save was successful
      final savedData = await StorageService.getNutritionPlan();
      if (savedData != null) {
       
      } else {
       
        // Try one more time if verification failed
        await StorageService.saveNutritionPlan(nutritionData);
      }
    } catch (e) {
    
      // Try direct Hive save as fallback
      try {
       
        final nutritionBox = await Hive.openBox<Map<String, dynamic>>('nutritionPlan');
        await nutritionBox.put('currentPlan', nutritionData);
       
      } catch (fallbackError) {
       
        throw Exception('Failed to save nutrition plan: $e / $fallbackError');
      }
    }
  }

  static Future<Map<String, dynamic>?> getNutritionPlan() async {
    try {
      return await StorageService.getNutritionPlan();
    } catch (e) {
    
      return null;
    }
  }

  // For debugging purposes only
  static Future<void> clearNutritionPlan() async {
    try {
      final nutritionBox = await Hive.openBox<Map<String, dynamic>>('nutritionPlan');
      await nutritionBox.clear();
    } catch (e) {
     
    }
  }

  static Future<Map<String, dynamic>?> recalculateNutrition() async {
    try {
      // Get user details from storage
      final userDetails = await StorageService.getUserDetails();
      
      if (userDetails == null) {
      
        return null;
      }

    

      // Calculate new nutrition plan using existing user details
      return await calculateNutrition(
        height: userDetails.height,
        weight: userDetails.weight,
        birthDate: userDetails.birthDate,
        isMetric: userDetails.isMetric,
        workoutsPerWeek: userDetails.workoutsPerWeek,
        weightGoal: userDetails.weightGoal,
        targetWeight: userDetails.targetWeight,
        gender: userDetails.gender,
        motivationGoal: userDetails.motivationGoal,
        dietType: userDetails.dietType,
        weightChangeSpeed: userDetails.weightChangeSpeed,
      );
    } catch (e) {
      
      return null;
    }
  }

  // Analyze food image using OpenAI Vision
  static Future<NutritionInfo> analyzeImage(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare the API request
      final response = await http.post(
        Uri.parse('$_openAiApiUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getGptApiKey()}',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      'Analyze this food image and provide detailed nutritional information in JSON format. Include: food name, brand name (if visible), calories, protein (g), carbs (g), fat (g), serving size, additional info (cuisine type, preparation method, health benefits, allergens, storage, shelf life), and ingredients list.'
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 1000
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0);
          final nutritionData = jsonDecode(jsonStr!);

          return NutritionInfo(
            foodName: nutritionData['food_name'] ?? 'Unknown Food',
            brandName: nutritionData['brand_name'] ?? 'Generic',
            calories: (nutritionData['calories'] ?? 0).toDouble(),
            protein: (nutritionData['protein'] ?? 0).toDouble(),
            carbs: (nutritionData['carbs'] ?? 0).toDouble(),
            fat: (nutritionData['fat'] ?? 0).toDouble(),
            servingSize: nutritionData['serving_size'] ?? '100g',
            additionalInfo: nutritionData['additional_info'] ?? {},
            ingredients: List<String>.from(nutritionData['ingredients'] ?? []),
          );
        }
      }

      throw Exception('Failed to analyze image: ${response.statusCode}');
    } catch (e) {

      rethrow;
    }
  }

  static NutritionInfo _getMockNutritionData(File imageFile) {
    // List of common foods with realistic nutrition values
    final foods = [
      NutritionInfo(
        foodName: 'Apple',
        brandName: 'Fresh Produce',
        calories: 95,
        protein: 0.5,
        carbs: 25,
        fat: 0.3,
        servingSize: '182g (1 medium)',
        additionalInfo: {
          'cuisine_type': 'Fresh Produce',
          'preparation_method': 'Raw',
          'health_benefits': [
            'High in fiber',
            'Rich in antioxidants',
            'Low in calories'
          ],
          'allergens': ['None'],
          'seasonality': 'Year-round',
          'storage': 'Room temperature or refrigerated',
          'shelf_life': '2-4 weeks'
        },
        ingredients: ['Apple'],
      ),
      NutritionInfo(
        foodName: 'Banana',
        brandName: 'Fresh Produce',
        calories: 105,
        protein: 1.3,
        carbs: 27,
        fat: 0.4,
        servingSize: '118g (1 medium)',
        additionalInfo: {
          'cuisine_type': 'Fresh Produce',
          'preparation_method': 'Raw',
          'health_benefits': [
            'High in potassium',
            'Good source of vitamin B6',
            'Natural energy boost'
          ],
          'allergens': ['None'],
          'seasonality': 'Year-round',
          'storage': 'Room temperature until ripe, then refrigerated',
          'shelf_life': '5-7 days'
        },
        ingredients: ['Banana'],
      ),
      // Add more mock foods as needed
    ];

    // For demo purposes, select a random food
    final random = DateTime.now().millisecondsSinceEpoch % foods.length;
    return foods[random];
  }

  static Future<Map<String, dynamic>> calculateNutritionPlan(UserDetails userDetails) async {
    try {

      
      // Safe conversions with fallback values
      final double weight = userDetails.weight ?? 70.0;
      final double height = userDetails.height ?? 170.0;
      
      // Get age from birthDate or use default
      int age = 30;
      if (userDetails.birthDate != null) {
        final now = DateTime.now();
        age = now.year - userDetails.birthDate!.year;
        if (now.month < userDetails.birthDate!.month || 
            (now.month == userDetails.birthDate!.month && now.day < userDetails.birthDate!.day)) {
          age--;
        }
      }
      
      final String gender = userDetails.gender.toLowerCase();
      
      // Activity level based on workouts per week
      String activityLevel;
      switch (userDetails.workoutsPerWeek) {
        case 0:
          activityLevel = 'sedentary';
          break;
        case 1:
        case 2:
          activityLevel = 'light';
          break;
        case 3:
        case 4:
          activityLevel = 'moderate';
          break;
        case 5:
        case 6:
          activityLevel = 'active';
          break;
        case 7:
          activityLevel = 'very active';
          break;
        default:
          activityLevel = 'moderate';
      }
      
      final String weightGoal = userDetails.weightGoal.toLowerCase();
      
  
      
      // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
      double bmr;
      if (gender == 'male') {
        bmr = 10 * weight + 6.25 * height - 5 * age + 5;
      } else {
        bmr = 10 * weight + 6.25 * height - 5 * age - 161;
      }
      
      // Activity multiplier
      double activityMultiplier;
      switch (activityLevel) {
        case 'sedentary':
          activityMultiplier = 1.2;
          break;
        case 'light':
          activityMultiplier = 1.375;
          break;
        case 'moderate':
          activityMultiplier = 1.55;
          break;
        case 'active':
          activityMultiplier = 1.725;
          break;
        case 'very active':
          activityMultiplier = 1.9;
          break;
        default:
          activityMultiplier = 1.55; // Default to moderate
      }
      
      // Total Daily Energy Expenditure (TDEE)
      double tdee = bmr * activityMultiplier;
      
      // Adjust calories based on weight goal
      int dailyCalories;
      switch (weightGoal) {
        case 'lose':
          dailyCalories = (tdee - 500).round(); // 500 calorie deficit
          break;
        case 'gain':
          dailyCalories = (tdee + 500).round(); // 500 calorie surplus
          break;
        default:
          dailyCalories = tdee.round(); // Maintain weight
      }
      
      // Ensure minimum healthy calories
      if (dailyCalories < 1200 && gender == 'female') {
        dailyCalories = 1200; // Minimum for females
      } else if (dailyCalories < 1500 && gender == 'male') {
        dailyCalories = 1500; // Minimum for males
      }
      
      // Calculate macronutrients (protein, carbs, fats)
      // For weight loss: higher protein, moderate fat, lower carbs
      // For weight gain: moderate protein, higher carbs, moderate fat
      // For maintenance: balanced macros
      
      int protein, carbs, fats;
      
      switch (weightGoal) {
        case 'lose':
          protein = ((weight * 2.2) * 1.2).round(); // Higher protein (g)
          fats = (dailyCalories * 0.30 / 9).round(); // 30% from fat
          carbs = ((dailyCalories - (protein * 4) - (fats * 9)) / 4).round(); // Remaining from carbs
          break;
        case 'gain':
          protein = ((weight * 2.2) * 1.0).round(); // Moderate protein (g)
          fats = (dailyCalories * 0.25 / 9).round(); // 25% from fat
          carbs = ((dailyCalories - (protein * 4) - (fats * 9)) / 4).round(); // Remaining from carbs
          break;
        default: // maintain
          protein = ((weight * 2.2) * 1.0).round(); // Moderate protein (g)
          fats = (dailyCalories * 0.30 / 9).round(); // 30% from fat
          carbs = ((dailyCalories - (protein * 4) - (fats * 9)) / 4).round(); // Remaining from carbs
      }
      
      // Ensure all values are positive
      protein = protein <= 0 ? 100 : protein;
      carbs = carbs <= 0 ? 150 : carbs;
      fats = fats <= 0 ? 50 : fats;
      
      // Calculate actual calories based on macros to ensure they match
      int recalculatedCalories = (protein * 4) + (carbs * 4) + (fats * 9);
      
      // Create nutrition plan
      final nutritionPlan = {
        'dailyCalories': dailyCalories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
      };
      

      
      return nutritionPlan;
    } catch (e) {

      // Return a sensible default plan if calculation fails
      return {
        'dailyCalories': 2000,
        'protein': 100,
        'carbs': 250,
        'fats': 67,
      };
    }
  }
}
