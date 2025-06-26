import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_info.dart';
import '../services/api_key_service.dart';

class FoodNutritionAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static final String _apiKey = ApiKeyService.getGptApiKey();

  static Future<NutritionInfo> analyzeIngredients({
    required String foodName,
    required String ingredients,
    required String portions,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key is not set.');
    }

    final prompt = '''
Analyze the following food item and provide detailed nutritional information.

Food Name: $foodName
Ingredients: $ingredients
Portions/Quantity: $portions

Provide the nutritional information in the following JSON format:
{
  "foodName": "name of the food",
  "servingSize": "serving size in grams or standard measurement",
  "calories": number,
  "protein": number in grams,
  "carbs": number in grams,
  "fat": number in grams,
  "fiber": number in grams,
  "sugar": number in grams,
  "sodium": number in mg,
  "additionalInfo": { 
    "mealType": "meal or snack category",
    "tags": ["list", "of", "tags"]
  }
}

Use only these fields and be as accurate as possible. Base your calculations on standard USDA nutrition databases.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a nutrition expert that analyzes food ingredients and provides accurate nutritional information. Respond only with the requested JSON format.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.2,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String aiResponse =
            responseData['choices'][0]['message']['content'];

        // Extract the JSON from the response (in case there's any text before or after)
        final RegExp jsonRegex = RegExp(r'{[\s\S]*}');
        final Match? match = jsonRegex.firstMatch(aiResponse);

        if (match != null) {
          final String jsonString = match.group(0)!;
          final Map<String, dynamic> nutritionData = jsonDecode(jsonString);

          // Create NutritionInfo object from the AI response
          // Parse ingredients list
          List<String> ingredientsList = ingredients
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();

          final nutritionInfo = NutritionInfo(
            foodName: nutritionData['foodName'] ?? foodName,
            calories: (nutritionData['calories'] ?? 0).toDouble(),
            protein: (nutritionData['protein'] ?? 0).toDouble(),
            carbs: (nutritionData['carbs'] ?? 0).toDouble(),
            fat: (nutritionData['fat'] ?? 0).toDouble(),
            servingSize: nutritionData['servingSize'] ?? 'N/A',
            brandName: '',
            additionalInfo: {
              'mealType':
                  nutritionData['additionalInfo']?['mealType'] ?? 'Meal',
              'tags': nutritionData['additionalInfo']?['tags'] ?? [],
              'fiber': nutritionData['fiber']?.toString() ?? '0',
              'sugar': nutritionData['sugar']?.toString() ?? '0',
              'sodium': nutritionData['sodium']?.toString() ?? '0',
              'portions': portions,
              'timestamp': DateTime.now().toIso8601String(),
            },
            ingredients: ingredientsList,
          );

          return nutritionInfo;
        } else {
          throw Exception('Failed to parse AI response: $aiResponse');
        }
      } else {
        throw Exception('Failed to analyze ingredients: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing ingredients: $e');
    }
  }
}
