import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_key_service.dart';
import '../services/storage_service.dart';
import '../services/nutrition_service.dart';
import '../models/meal_suggestion.dart';

class CuisineRegion {
  final String continent;
  final List<String> regions;
  final Map<String, List<String>> subRegions;

  CuisineRegion({
    required this.continent,
    required this.regions,
    required this.subRegions,
  });
}

class MealPlanService {
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const String _openAiApiUrl =
      'https://api.openai.com/v1/chat/completions';
  
  static const String _mealSuggestionsBoxName = 'mealSuggestions';

  // Get API keys dynamically from API key service
  static String _getGeminiApiKey() => ApiKeyService.getGeminiApiKey();
  static String _getGptApiKey() => ApiKeyService.getGptApiKey();

  // Initialize Hive box for meal suggestions
  static Future<void> initialize() async {
    try {
      // Ensure the box is properly closed before opening it again
      if (Hive.isBoxOpen(_mealSuggestionsBoxName)) {
        await Hive.box(_mealSuggestionsBoxName).close();
      }
      
      // Open the box with a clear name and compaction strategy
      final box = await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName,
          compactionStrategy: (entries, deletedEntries) => deletedEntries > 50);
      
      // Check if the box is properly opened
      if (box.isOpen) {
        print('✅ MealPlanService: Box $_mealSuggestionsBoxName opened successfully');
        
        // Check if there are any existing suggestions
        final suggestions = box.values.toList();
        print('📊 MealPlanService: Found ${suggestions.length} existing meal suggestions');
        
        // Verify data structure
        if (suggestions.isNotEmpty) {
          print('🔍 First suggestion sample: ${suggestions.first.name}');
        }
      } else {
        print('❌ MealPlanService: Box $_mealSuggestionsBoxName is not open');
        // Try to open the box again with a different approach
        await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName);
      }
    } catch (e) {
      print('❌ Error initializing MealPlanService: $e');
      // Try to recover by forcing the box open
      try {
        await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName, 
            compactionStrategy: (entries, deletedEntries) => deletedEntries > 50);
      } catch (e) {
        print('❌ Failed to recover MealPlanService initialization: $e');
      }
    }
  }

  // Get list of available cuisines by continent and region
  static List<CuisineRegion> getCuisinesByRegion() {
    return [
      CuisineRegion(
        continent: 'Asian',
        regions: [
          'Chinese',
          'Japanese',
          'Korean',
          'Thai',
          'Vietnamese',
          'Indian',
          'Middle Eastern',
        ],
        subRegions: {
          'Chinese': ['Cantonese', 'Sichuan', 'Hunan', 'Shanghainese', 'Dim Sum'],
          'Japanese': ['Sushi', 'Ramen', 'Tempura', 'Kaiseki', 'Yakitori', 'Izakaya'],
          'Korean': ['Kimchi', 'Bibimbap', 'Korean BBQ', 'Temple Food', 'Street Food'],
          'Thai': ['Northern Thai', 'Southern Thai', 'Isaan', 'Bangkok Style', 'Royal Thai'],
          'Vietnamese': ['Northern', 'Central', 'Southern', 'Pho', 'Banh Mi'],
          'Indian': ['North Indian', 'South Indian', 'Bengali', 'Gujarati', 'Punjabi', 'Kerala', 'Tamil', 'Andhra', 'Goan'],
          'Middle Eastern': ['Lebanese', 'Turkish', 'Persian', 'Israeli', 'Moroccan', 'Egyptian'],
        },
      ),
      CuisineRegion(
        continent: 'European',
        regions: [
          'Italian',
          'French',
          'Mediterranean',
          'Greek',
          'Spanish',
          'German',
          'British',
          'Scandinavian',
        ],
        subRegions: {
          'Italian': ['Tuscan', 'Sicilian', 'Roman', 'Venetian', 'Neapolitan', 'Northern Italian'],
          'French': ['Provençal', 'Parisian', 'Lyonnaise', 'Normandy', 'Alsatian', 'Bordeaux'],
          'Mediterranean': ['Coastal', 'Island', 'Rustic', 'Modern', 'Fusion'],
          'Greek': ['Mainland', 'Island', 'Cretan', 'Cypriot', 'Aegean'],
          'Spanish': ['Basque', 'Catalan', 'Andalusian', 'Galician', 'Valencian', 'Tapas'],
          'German': ['Bavarian', 'Saxon', 'Berlin', 'Hamburg', 'Black Forest'],
          'British': ['English', 'Scottish', 'Welsh', 'Irish', 'Modern British'],
          'Scandinavian': ['Swedish', 'Danish', 'Norwegian', 'Finnish', 'Nordic'],
        },
      ),
      CuisineRegion(
        continent: 'American',
        regions: [
          'North American',
          'Mexican',
          'Caribbean',
          'South American',
          'Brazilian',
          'Peruvian',
        ],
        subRegions: {
          'North American': ['Southern', 'Tex-Mex', 'Cajun', 'Creole', 'New England', 'Midwest', 'Pacific Northwest'],
          'Mexican': ['Oaxacan', 'Yucatan', 'Northern Mexican', 'Mexico City', 'Baja', 'Puebla'],
          'Caribbean': ['Cuban', 'Jamaican', 'Puerto Rican', 'Dominican', 'Trinidadian', 'Haitian'],
          'South American': ['Argentine', 'Colombian', 'Venezuelan', 'Chilean', 'Ecuadorian'],
          'Brazilian': ['Bahian', 'Amazonian', 'Gaucho', 'Minas Gerais', 'Northeastern'],
          'Peruvian': ['Coastal', 'Andean', 'Amazonian', 'Nikkei', 'Chifa'],
        },
      ),
      CuisineRegion(
        continent: 'African',
        regions: [
          'North African',
          'West African',
          'East African',
          'South African',
          'Ethiopian',
          'Moroccan',
        ],
        subRegions: {
          'North African': ['Tunisian', 'Algerian', 'Libyan', 'Egyptian'],
          'West African': ['Nigerian', 'Ghanaian', 'Senegalese', 'Ivorian', 'Malian'],
          'East African': ['Kenyan', 'Tanzanian', 'Ugandan', 'Rwandan', 'Somali'],
          'South African': ['Cape Malay', 'Zulu', 'Xhosa', 'Afrikaner', 'Durban'],
          'Ethiopian': ['Amhara', 'Oromo', 'Tigray', 'Gurage', 'Vegetarian'],
          'Moroccan': ['Marrakech', 'Fez', 'Casablanca', 'Berber', 'Coastal'],
        },
      ),
      CuisineRegion(
        continent: 'Oceanic',
        regions: [
          'Australian',
          'New Zealand',
          'Pacific Islands',
        ],
        subRegions: {
          'Australian': ['Modern Australian', 'Bush Tucker', 'Coastal', 'Outback', 'Fusion'],
          'New Zealand': ['Maori', 'Kiwi', 'Pacific Rim', 'South Island', 'North Island'],
          'Pacific Islands': ['Hawaiian', 'Fijian', 'Samoan', 'Tahitian', 'Tongan'],
        },
      ),
      CuisineRegion(
        continent: 'Dietary',
        regions: [
          'Vegetarian',
          'Vegan',
          'Keto',
          'Low Carb',
          'High Protein',
          'Gluten Free',
          'Dairy Free',
        ],
        subRegions: {
          'Vegetarian': ['Lacto-Ovo', 'Lacto', 'Ovo', 'Plant-Based', 'Mediterranean Vegetarian'],
          'Vegan': ['Raw Vegan', 'Whole Food Plant-Based', 'Comfort Food', 'High Protein', 'Macrobiotic'],
          'Keto': ['Standard', 'Cyclical', 'Targeted', 'High-Protein', 'Mediterranean Keto'],
          'Low Carb': ['Moderate', 'Strict', 'Atkins', 'Paleo-Inspired', 'Grain-Free'],
          'High Protein': ['Lean', 'Bodybuilding', 'Athletic', 'Balanced', 'Pescatarian'],
          'Gluten Free': ['Celiac-Friendly', 'Grain-Free', 'Paleo', 'Traditional', 'Baking'],
          'Dairy Free': ['Nut-Based', 'Coconut', 'Soy-Based', 'Oat-Based', 'Traditional'],
        },
      ),
    ];
  }

  // Generate meal suggestions based on user's nutrition goals and preferences
  static Future<List<MealSuggestion>> generateMealSuggestions({
    required String mealType,
    required String cuisine,
    required String region,
    String subRegion = '',
    int count = 2,
  }) async {
    try {
      // Get user's nutrition plan
      final nutritionPlan = await StorageService.getNutritionPlan();
      if (nutritionPlan == null) {
        throw Exception('No nutrition plan found');
      }

      // Calculate approximate nutrition values for this meal
      // Assuming 3 main meals (breakfast, lunch, dinner) and 2 snacks
      final int mealCalorieTarget;
      final int mealProteinTarget;
      final int mealCarbsTarget;
      final int mealFatsTarget;
      
      if (mealType.toLowerCase() == 'breakfast') {
        mealCalorieTarget = (nutritionPlan['dailyCalories'] * 0.25).round();
        mealProteinTarget = (nutritionPlan['protein'] * 0.25).round();
        mealCarbsTarget = (nutritionPlan['carbs'] * 0.25).round();
        mealFatsTarget = (nutritionPlan['fats'] * 0.25).round();
      } else if (mealType.toLowerCase() == 'lunch') {
        mealCalorieTarget = (nutritionPlan['dailyCalories'] * 0.3).round();
        mealProteinTarget = (nutritionPlan['protein'] * 0.3).round();
        mealCarbsTarget = (nutritionPlan['carbs'] * 0.3).round();
        mealFatsTarget = (nutritionPlan['fats'] * 0.3).round();
      } else if (mealType.toLowerCase() == 'dinner') {
        mealCalorieTarget = (nutritionPlan['dailyCalories'] * 0.3).round();
        mealProteinTarget = (nutritionPlan['protein'] * 0.3).round();
        mealCarbsTarget = (nutritionPlan['carbs'] * 0.3).round();
        mealFatsTarget = (nutritionPlan['fats'] * 0.3).round();
      } else {
        // Snack
        mealCalorieTarget = (nutritionPlan['dailyCalories'] * 0.15).round();
        mealProteinTarget = (nutritionPlan['protein'] * 0.15).round();
        mealCarbsTarget = (nutritionPlan['carbs'] * 0.15).round();
        mealFatsTarget = (nutritionPlan['fats'] * 0.15).round();
      }

      // Prepare cuisine specification with region if provided
      final String cuisineSpec = region.isNotEmpty ? "$cuisine ($region)" : cuisine;

      // Create prompt for Gemini API
      final prompt = '''
      Generate $count healthy $cuisineSpec $mealType recipes that match these nutritional targets:
      - Calories: approximately $mealCalorieTarget kcal
      - Protein: approximately $mealProteinTarget g
      - Carbs: approximately $mealCarbsTarget g
      - Fat: approximately $mealFatsTarget g

      For each recipe, provide:
      1. Name
      2. Brief description
      3. Ingredients list
      4. Step-by-step instructions
      5. Nutritional information (calories, protein, carbs, fat)

      Return the response as a valid JSON array with this format:
      [
        {
          "name": "Recipe Name",
          "description": "Brief description",
          "nutritionInfo": {
            "calories": 123,
            "protein": 12,
            "carbs": 34,
            "fat": 5
          },
          "ingredients": ["ingredient 1", "ingredient 2", ...],
          "instructions": "Step-by-step instructions"
        },
        ...
      ]
      ''';

      // Call Gemini API
      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=${_getGeminiApiKey()}'),
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

        // Extract JSON from response
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0);
          final List<dynamic> recipesJson = jsonDecode(jsonString!);
          
          // Convert to MealSuggestion objects
          final List<MealSuggestion> suggestions = recipesJson.map((recipeJson) {
            return MealSuggestion(
              name: recipeJson['name'] ?? 'Unnamed Recipe',
              description: recipeJson['description'] ?? '',
              nutritionInfo: recipeJson['nutritionInfo'] ?? {},
              ingredients: List<String>.from(recipeJson['ingredients'] ?? []),
              instructions: recipeJson['instructions'] ?? '',
              mealType: mealType,
              cuisine: cuisine,
              region: region,
              createdAt: DateTime.now(),
            );
          }).toList();
          
          // Automatically save all suggestions
          await _saveMealSuggestions(suggestions);
          
          return suggestions;
        }
      }
      
      // If API call fails, return empty list
      return [];
    } catch (e) {
      print('Error generating meal suggestions: $e');
      return [];
    }
  }
  
  // Generate meal suggestions based on available ingredients
  static Future<List<MealSuggestion>> generateMealsFromIngredients({
    required List<String> ingredients,
    String mealType = 'Any',
    String cuisine = 'Any',
    String region = '',
    String subRegion = '',
    int count = 2,
  }) async {
    try {
      // Prepare cuisine specification with region if provided
      final String cuisineSpec = cuisine != 'Any' 
          ? (region.isNotEmpty ? "$cuisine ($region)" : cuisine)
          : "any cuisine";

      // Create prompt for OpenAI API
      final prompt = '''
      Create $count creative recipes using some or all of these ingredients: ${ingredients.join(', ')}.
      
      The meal type should be: $mealType (or any suitable meal if "Any" is specified).
      The cuisine should be: $cuisineSpec (or any suitable cuisine if "Any" is specified).
      
      For each recipe, provide:
      1. Name
      2. Brief description
      3. Ingredients list (only using what's available plus basic pantry staples)
      4. Step-by-step instructions
      5. Estimated nutritional information (calories, protein, carbs, fat)

      Return the response as a valid JSON array with this format:
      [
        {
          "name": "Recipe Name",
          "description": "Brief description",
          "nutritionInfo": {
            "calories": 123,
            "protein": 12,
            "carbs": 34,
            "fat": 5
          },
          "ingredients": ["ingredient 1", "ingredient 2", ...],
          "instructions": "Step-by-step instructions"
        },
        ...
      ]
      ''';

      // Call OpenAI API
      final response = await http.post(
        Uri.parse(_openAiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getGptApiKey()}',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo',
          'messages': [
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.7,
          'max_tokens': 2000
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Extract JSON from the response
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0);
          final List<dynamic> recipesJson = jsonDecode(jsonStr!);
          
          // Convert to MealSuggestion objects
          final List<MealSuggestion> suggestions = recipesJson.map((recipeJson) {
            return MealSuggestion(
              name: recipeJson['name'] ?? 'Unnamed Recipe',
              description: recipeJson['description'] ?? '',
              nutritionInfo: recipeJson['nutritionInfo'] ?? {},
              ingredients: List<String>.from(recipeJson['ingredients'] ?? []),
              instructions: recipeJson['instructions'] ?? '',
              mealType: mealType == 'Any' ? 'Custom' : mealType,
              cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
              region: region,
              createdAt: DateTime.now(),
            );
          }).toList();
          
          // Automatically save all suggestions
          await _saveMealSuggestions(suggestions);
          
          return suggestions;
        }
      }
      
      // If API call fails, return empty list
      return [];
    } catch (e) {
      print('Error generating meals from ingredients: $e');
      return [];
    }
  }

  // Generate meal suggestions based on a food image
  static Future<List<MealSuggestion>> generateMealsFromImage({
    required File imageFile,
    String mealType = 'Any',
    String cuisine = 'Any',
    String region = '',
    String subRegion = '',
    int count = 1,
  }) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare cuisine specification with region and sub-region if provided
      String cuisineSpec;
      if (cuisine != 'Any') {
        if (region.isNotEmpty) {
          if (subRegion.isNotEmpty) {
            cuisineSpec = "$cuisine ($region - $subRegion)";
          } else {
            cuisineSpec = "$cuisine ($region)";
          }
        } else {
          cuisineSpec = cuisine;
        }
      } else {
        cuisineSpec = "any cuisine";
      }

      // Create prompt for OpenAI Vision API
      final prompt = '''
      Look at this image of food ingredients and:
      1. Identify all the visible ingredients
      2. Create $count creative recipe using these ingredients
      
      The meal type should be: $mealType (or any suitable meal if "Any" is specified).
      The cuisine should be: $cuisineSpec (or any suitable cuisine if "Any" is specified).
      
      For the recipe, provide:
      1. Name
      2. Brief description
      3. Ingredients list (only using what's visible in the image plus basic pantry staples)
      4. Step-by-step instructions
      5. Estimated nutritional information (calories, protein, carbs, fat)

      Return the response as a valid JSON array with this format:
      [
        {
          "name": "Recipe Name",
          "description": "Brief description",
          "nutritionInfo": {
            "calories": 123,
            "protein": 12,
            "carbs": 34,
            "fat": 5
          },
          "ingredients": ["ingredient 1", "ingredient 2", ...],
          "instructions": "Step-by-step instructions"
        }
      ]
      ''';

      print('🔍 Sending image to OpenAI Vision API using gpt-4.1...');
      
      // Call OpenAI Vision API with updated model
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getGptApiKey()}',
        },
        body: jsonEncode({
          'model': 'gpt-4.1',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 2000
        }),
      );

      print('📡 API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        print('✅ Received response from OpenAI Vision API');
        print('📝 Processing response content...');

        // Extract JSON from the response
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0);
          print('🔍 Found JSON in response');
          
          try {
            final List<dynamic> recipesJson = jsonDecode(jsonStr!);
            print('✅ Successfully parsed JSON: ${recipesJson.length} recipes found');
            
            // Convert to MealSuggestion objects
            final List<MealSuggestion> suggestions = recipesJson.map((recipeJson) {
              return MealSuggestion(
                name: recipeJson['name'] ?? 'Unnamed Recipe',
                description: recipeJson['description'] ?? '',
                nutritionInfo: recipeJson['nutritionInfo'] ?? {
                  'calories': 0,
                  'protein': 0,
                  'carbs': 0,
                  'fat': 0
                },
                ingredients: List<String>.from(recipeJson['ingredients'] ?? []),
                instructions: recipeJson['instructions'] ?? '',
                mealType: mealType == 'Any' ? 'Custom' : mealType,
                cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
                region: region,
                createdAt: DateTime.now(),
              );
            }).toList();
            
            // Automatically save all suggestions
            await _saveMealSuggestions(suggestions);
            
            return suggestions;
          } catch (parseError) {
            print('❌ Error parsing JSON: $parseError');
            print('📄 Raw JSON string: $jsonStr');
            
            // Create a fallback suggestion with the content we received
            final fallbackSuggestion = MealSuggestion(
              name: 'AI Generated Recipe',
              description: 'Recipe created from your ingredients',
              nutritionInfo: {
                'calories': 0,
                'protein': 0,
                'carbs': 0,
                'fat': 0
              },
              ingredients: ['Ingredients identified in your image'],
              instructions: content,
              mealType: mealType == 'Any' ? 'Custom' : mealType,
              cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
              region: region,
              createdAt: DateTime.now(),
            );
            
            await _saveMealSuggestions([fallbackSuggestion]);
            return [fallbackSuggestion];
          }
        } else {
          print('⚠️ No JSON found in response');
          print('📄 Raw response content: $content');
          
          // Create a fallback suggestion with the content we received
          final fallbackSuggestion = MealSuggestion(
            name: 'AI Generated Recipe',
            description: 'Recipe created from your ingredients',
            nutritionInfo: {
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0
            },
            ingredients: ['Ingredients identified in your image'],
            instructions: content,
            mealType: mealType == 'Any' ? 'Custom' : mealType,
            cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
            region: region,
            createdAt: DateTime.now(),
          );
          
          await _saveMealSuggestions([fallbackSuggestion]);
          return [fallbackSuggestion];
        }
      } else {
        print('❌ API request failed with status code: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        
        // Try fallback to GPT-4o model if initial request fails
        return _generateMealsFromImageFallback(
          imageFile: imageFile,
          mealType: mealType,
          cuisine: cuisine,
          region: region,
          prompt: prompt
        );
      }
    } catch (e) {
      print('❌ Error generating meals from image: $e');
      return [];
    }
  }
  
  // Fallback method for image processing with alternative model
  static Future<List<MealSuggestion>> _generateMealsFromImageFallback({
    required File imageFile,
    required String mealType,
    required String cuisine,
    required String region,
    required String prompt,
  }) async {
    try {
      print('🔄 Trying fallback with GPT-4o model...');
      
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Call OpenAI API with GPT-4o model
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getGptApiKey()}',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 2000
        }),
      );
      
      print('📡 Fallback API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        print('✅ Received response from fallback API');
        
        // Extract JSON from the response
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0);
          
          try {
            final List<dynamic> recipesJson = jsonDecode(jsonStr!);
            
            // Convert to MealSuggestion objects
            final List<MealSuggestion> suggestions = recipesJson.map((recipeJson) {
              return MealSuggestion(
                name: recipeJson['name'] ?? 'Unnamed Recipe',
                description: recipeJson['description'] ?? '',
                nutritionInfo: recipeJson['nutritionInfo'] ?? {
                  'calories': 0,
                  'protein': 0,
                  'carbs': 0,
                  'fat': 0
                },
                ingredients: List<String>.from(recipeJson['ingredients'] ?? []),
                instructions: recipeJson['instructions'] ?? '',
                mealType: mealType == 'Any' ? 'Custom' : mealType,
                cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
                region: region,
                createdAt: DateTime.now(),
              );
            }).toList();
            
            await _saveMealSuggestions(suggestions);
            return suggestions;
          } catch (parseError) {
            // Create a fallback suggestion
            final fallbackSuggestion = MealSuggestion(
              name: 'AI Generated Recipe',
              description: 'Recipe created from your ingredients',
              nutritionInfo: {
                'calories': 0,
                'protein': 0,
                'carbs': 0,
                'fat': 0
              },
              ingredients: ['Ingredients identified in your image'],
              instructions: content,
              mealType: mealType == 'Any' ? 'Custom' : mealType,
              cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
              region: region,
              createdAt: DateTime.now(),
            );
            
            await _saveMealSuggestions([fallbackSuggestion]);
            return [fallbackSuggestion];
          }
        } else {
          // Create a fallback suggestion with the content
          final fallbackSuggestion = MealSuggestion(
            name: 'AI Generated Recipe',
            description: 'Recipe created from your ingredients',
            nutritionInfo: {
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0
            },
            ingredients: ['Ingredients identified in your image'],
            instructions: content,
            mealType: mealType == 'Any' ? 'Custom' : mealType,
            cuisine: cuisine == 'Any' ? 'Custom' : cuisine,
            region: region,
            createdAt: DateTime.now(),
          );
          
          await _saveMealSuggestions([fallbackSuggestion]);
          return [fallbackSuggestion];
        }
      } else {
        print('❌ Fallback API request also failed: ${response.statusCode}');
        print('📄 Fallback response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error in fallback image processing: $e');
      return [];
    }
  }

  // Get all saved meal suggestions
  static Future<List<MealSuggestion>> getSavedMealSuggestions() async {
    try {
      // Make sure the box is open
      if (!Hive.isBoxOpen(_mealSuggestionsBoxName)) {
        print('📦 Opening meal suggestions box for retrieval');
        await initialize();
      }
      
      final box = Hive.box<MealSuggestion>(_mealSuggestionsBoxName);
      final suggestions = box.values.toList();
      
      print('📊 Retrieved ${suggestions.length} recipes from database');
      
      if (suggestions.isEmpty) {
        print('⚠️ No recipes found in database');
        return [];
      }
      
      return suggestions;
    } catch (e) {
      print('❌ Error getting saved meal suggestions: $e');
      return [];
    }
  }
  
  // Delete a meal suggestion
  static Future<void> deleteMealSuggestion(MealSuggestion suggestion) async {
    try {
      final box = await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName);
      
      // Find and remove the suggestion
      for (var key in box.keys) {
        final savedSuggestion = box.get(key);
        if (savedSuggestion != null && 
            savedSuggestion.name == suggestion.name && 
            savedSuggestion.createdAt.toString() == suggestion.createdAt.toString()) {
          await box.delete(key);
          break;
        }
      }
    } catch (e) {
      print('Error deleting meal suggestion: $e');
    }
  }
  
  // Clear all meal suggestions
  static Future<void> clearAllMealSuggestions() async {
    try {
      final box = await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName);
      await box.clear();
    } catch (e) {
      print('Error clearing meal suggestions: $e');
    }
  }

  // Save meal suggestions to Hive
  static Future<void> _saveMealSuggestions(List<MealSuggestion> suggestions) async {
    try {
      // Make sure the box is open
      if (!Hive.isBoxOpen(_mealSuggestionsBoxName)) {
        print('📦 Opening meal suggestions box for saving');
        await initialize();
      }
      
      final box = Hive.box<MealSuggestion>(_mealSuggestionsBoxName);
      
      // Debug log
      print('📝 Saving ${suggestions.length} new recipes. Current count: ${box.length}');
      
      // Add new suggestions
      for (var suggestion in suggestions) {
        await box.add(suggestion);
      }
      
      // Keep only the most recent 50 suggestions
      if (box.length > 50) {
        final keysToDelete = box.keys.toList().sublist(0, box.length - 50);
        for (var key in keysToDelete) {
          await box.delete(key);
        }
      }
      
      // Force flush to disk
      await box.flush();
      
      // Verify the save operation
      final verifyCount = box.length;
      print('✅ After save: ${verifyCount} recipes in database');
      
    } catch (e) {
      print('❌ Error saving meal suggestions: $e');
      
      // Try to recover
      try {
        if (!Hive.isBoxOpen(_mealSuggestionsBoxName)) {
          await initialize();
        }
        
        final box = Hive.box<MealSuggestion>(_mealSuggestionsBoxName);
        
        // Add suggestions directly
        for (var suggestion in suggestions) {
          await box.add(suggestion);
        }
        
        await box.flush();
        
        print('🔄 Recovery save completed');
      } catch (e2) {
        print('❌ Recovery save failed: $e2');
      }
    }
  }

  /// Save a single meal suggestion
  static Future<bool> saveMealSuggestion(MealSuggestion suggestion) async {
    try {
      await _saveMealSuggestions([suggestion]);
      return true;
    } catch (e) {
      print('❌ Error saving single meal suggestion: $e');
      return false;
    }
  }

  // Verify and repair the meal suggestions box if needed
  static Future<void> verifyAndRepairBox() async {
    try {
      // Check if the box is open
      if (!Hive.isBoxOpen(_mealSuggestionsBoxName)) {
        print('⚠️ Box not open, opening now...');
        await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName);
      }
      
      final box = await Hive.openBox<MealSuggestion>(_mealSuggestionsBoxName);
      
      // Check if the box is corrupted by trying to read from it
      try {
        final suggestions = box.values.toList();
        print('✅ Box verification successful, found ${suggestions.length} suggestions');
      } catch (e) {
        print('❌ Box may be corrupted: $e');
        
        // Try to repair by clearing and recreating
        await box.clear();
        print('🔄 Box repair attempted');
        
        // Verify repair
        final suggestions = box.values.toList();
        print('✅ After repair: ${suggestions.length} suggestions (should be 0)');
      }
    } catch (e) {
      print('❌ Box verification failed: $e');
    }
  }
} 