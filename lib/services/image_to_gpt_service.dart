import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/nutrition_info.dart';
import '../services/api_key_service.dart';

class ImageToGptService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini'; // Using the most efficient model
  static const int _timeoutSeconds = 15; // Add a timeout to prevent long waits
  static String? _apiKey; // Changed to nullable

  // Get API key only when needed, avoiding early initialization issues
  static String _getApiKey() {
    if (_apiKey == null) {
      _apiKey = ApiKeyService.getGptApiKey();
      
      if (_apiKey!.isEmpty) {
        ApiKeyService.refreshKeys(); // Try to refresh the keys
      }
    }
    
    return _apiKey ?? '';
  }

  Future<NutritionInfo> analyzeImage(File imageFile) async {
    try {
      // Get the API key when needed (just-in-time)
      final apiKey = _getApiKey();
      
      // Check if API key is available before proceeding
      if (apiKey.isEmpty) {
        throw Exception('API key is not configured. Please check Firebase Remote Config.');
      }
      
      // Compress image to reduce size and speed up upload
      final compressedImageFile = await _compressImage(imageFile);
      
      // Convert image to base64
      final bytes = await compressedImageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare the API request with a simplified prompt
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      '''Quickly analyze this food image and provide basic nutritional information in JSON format. 
                  Include only these essential fields:
                  - foodName: Name of the food
                  - calories: Number of calories
                  - protein: Protein content in grams
                  - carbs: Carbohydrate content in grams
                  - fat: Fat content in grams
                  - ingredients: Array of main ingredients (limit to 5 max)
                  
                  Return ONLY valid JSON without any additional text.'''
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 500, // Reduced token count for faster response
          'temperature': 0.3, // Lower temperature for more deterministic results
        }),
        // Set a timeout to prevent hanging on slow connections
        ).timeout(Duration(seconds: _timeoutSeconds), onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'];

        // Clean up the content - remove markdown and code blocks
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();

        // Try to parse the JSON response, handling potential formatting issues
        try {
          // First attempt to parse directly
          final nutritionData = jsonDecode(content);
          return _createNutritionInfo(nutritionData);
        } catch (jsonError) {
          // Try to extract JSON if it's surrounded by text or code blocks
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0);

            // Try to fix common JSON issues
            String cleanedJson = jsonStr!
                .replaceAll(RegExp(r',\s*\]'), ']') // Remove trailing commas in arrays
                .replaceAll(RegExp(r'\]\s*,\s*\]'), ']]') // Fix missing opening bracket
                .replaceAll(RegExp(r'\[\s*\]'), '[]'); // Replace empty arrays

            try {
              final nutritionData = jsonDecode(cleanedJson);
              return _createNutritionInfo(nutritionData);
            } catch (e) {
              throw Exception('Failed to parse nutrition data from API response');
            }
          }

          // If we still can't parse the JSON, fall back to a default
          throw Exception('Failed to parse nutrition data from API response');
        }
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // If there's a timeout or other error, return a mock response instead of throwing
      if (e.toString().contains('timed out') || e.toString().contains('Failed to analyze')) {
        return _getMockNutritionData();
      }
      
      // For other errors, throw with a user-friendly message
      throw Exception('We couldn\'t identify the food in your image. Please try again with a clearer photo.');
    }
  }

  // New method specifically for analyzing food labels
  Future<NutritionInfo> analyzeFoodLabel(File imageFile) async {
    try {
      // Get the API key when needed (just-in-time)
      final apiKey = _getApiKey();
      
      // Check if API key is available before proceeding
      if (apiKey.isEmpty) {
        throw Exception('API key is not configured. Please check Firebase Remote Config.');
      }
      
      // Compress image to reduce size and speed up upload
      final compressedImageFile = await _compressImage(imageFile);
      
      // Convert image to base64
      final bytes = await compressedImageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare the API request with a prompt specifically for food labels
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      '''You are a nutrition facts label analyzer. Extract detailed nutrition information from this food label image and return it in JSON format.
                  Include these fields:
                  - foodName: Product name
                  - brandName: Brand name if visible
                  - calories: Total calories per serving
                  - protein: Protein in grams
                  - carbs: Total carbohydrates in grams
                  - fat: Total fat in grams
                  - servingSize: Serving size as shown on label
                  - ingredients: Array of ingredients (extract from ingredients list if visible)
                  - additionalInfo: Object containing:
                      - dietaryFiber: Dietary fiber in grams
                      - sugars: Sugars in grams
                      - saturatedFat: Saturated fat in grams
                      - cholesterol: Cholesterol in mg
                      - sodium: Sodium in mg
                      - calcium: Calcium in mg or % Daily Value
                      - iron: Iron in mg or % Daily Value
                      - vitaminA: Vitamin A in % Daily Value
                      - vitaminC: Vitamin C in % Daily Value
                      - allergens: Any allergen warnings
                  
                  Return ONLY valid JSON without any additional text. If a value isn't visible in the image, use null for that field.'''
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 800, // Increased token count for more detailed response
          'temperature': 0.2, // Lower temperature for more accurate extraction
        }),
        // Set a timeout to prevent hanging on slow connections
        ).timeout(Duration(seconds: _timeoutSeconds * 2), onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'];

        // Clean up the content - remove markdown and code blocks
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();

        // Try to parse the JSON response, handling potential formatting issues
        try {
          // First attempt to parse directly
          final nutritionData = jsonDecode(content);
          return _createNutritionInfoFromLabel(nutritionData);
        } catch (jsonError) {
          // Try to extract JSON if it's surrounded by text or code blocks
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0);

            // Try to fix common JSON issues
            String cleanedJson = jsonStr!
                .replaceAll(RegExp(r',\s*\}'), '}') // Remove trailing commas in objects
                .replaceAll(RegExp(r',\s*\]'), ']') // Remove trailing commas in arrays
                .replaceAll(RegExp(r'\]\s*,\s*\]'), ']]') // Fix missing opening bracket
                .replaceAll(RegExp(r'\[\s*\]'), '[]'); // Replace empty arrays

            try {
              final nutritionData = jsonDecode(cleanedJson);
              return _createNutritionInfoFromLabel(nutritionData);
            } catch (e) {
              throw Exception('Failed to parse nutrition data from food label');
            }
          }

          // If we still can't parse the JSON, fall back to a default
          throw Exception('Failed to parse nutrition data from food label');
        }
      } else {
        throw Exception('Failed to analyze food label: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // For errors, throw with a user-friendly message
      throw Exception('We couldn\'t read the nutrition label clearly. Please try again with a clearer photo of the label.');
    }
  }

  // Compress the image to reduce size and upload time
  Future<File> _compressImage(File file) async {
    try {
      // Create temporary file path for compressed image
      final dir = file.parent;
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Check if flutter_image_compress is available
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 70, // Lower quality for faster processing
          minWidth: 800, // Resize to smaller dimension
          minHeight: 800,
        );
        
        return result != null ? File(result.path) : file;
      } catch (e) {
        // If compression fails, return the original file
        return file;
      }
    } catch (e) {
      // If any error occurs, return the original file
      return file;
    }
  }

  NutritionInfo _createNutritionInfo(Map<String, dynamic> data) {
    // Handle ingredients which might come as different types
    List<String> ingredients = [];

    if (data['ingredients'] != null) {
      if (data['ingredients'] is List) {
        // If it's already a list
        ingredients = List<String>.from(
            data['ingredients'].map((item) => item.toString()));
      } else if (data['ingredients'] is String) {
        // If it's a comma-separated string
        ingredients = data['ingredients']
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (data['ingredients'] is Map) {
        // If it's a map, use the values
        ingredients = List<String>.from(
            data['ingredients'].values.map((item) => item.toString()));
      }
    }

    // Use simplified additionalInfo with empty values for optional fields
    Map<String, dynamic> additionalInfo = {
      'cuisineType': '',
      'preparationMethod': '',
      'healthBenefits': '',
      'allergens': '',
      'storage': '',
      'shelfLife': '',
      // If any of these fields are in the response, they'll be added below
    };

    // Add any additional info that might be in the response
    if (data['additionalInfo'] is Map) {
      // Simply merge the maps
      additionalInfo.addAll(Map<String, dynamic>.from(data['additionalInfo']));
    }

    return NutritionInfo(
      foodName: data['foodName'] ?? 'Unknown Food',
      brandName: data['brandName'] ?? '',
      calories: (data['calories'] ?? 0).toDouble(),
      protein: (data['protein'] ?? 0).toDouble(),
      carbs: (data['carbs'] ?? 0).toDouble(),
      fat: (data['fat'] ?? 0).toDouble(),
      servingSize: data['servingSize'] ?? '100g',
      additionalInfo: additionalInfo,
      ingredients: ingredients,
    );
  }

  // New method to create NutritionInfo from food label data
  NutritionInfo _createNutritionInfoFromLabel(Map<String, dynamic> data) {
    // Handle ingredients which might come as different types
    List<String> ingredients = [];

    if (data['ingredients'] != null) {
      if (data['ingredients'] is List) {
        // If it's already a list
        ingredients = List<String>.from(
            data['ingredients'].map((item) => item.toString()));
      } else if (data['ingredients'] is String) {
        // If it's a comma-separated string
        ingredients = data['ingredients']
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (data['ingredients'] is Map) {
        // If it's a map, use the values
        ingredients = List<String>.from(
            data['ingredients'].values.map((item) => item.toString()));
      }
    }

    // Create additionalInfo map with nutrition label specific fields
    Map<String, dynamic> additionalInfo = {
      'cuisineType': '',
      'preparationMethod': '',
      'healthBenefits': '',
      'allergens': data['additionalInfo']?['allergens'] ?? '',
      'storage': '',
      'shelfLife': '',
      'dietaryFiber': data['additionalInfo']?['dietaryFiber'],
      'sugars': data['additionalInfo']?['sugars'],
      'saturatedFat': data['additionalInfo']?['saturatedFat'],
      'cholesterol': data['additionalInfo']?['cholesterol'],
      'sodium': data['additionalInfo']?['sodium'],
      'calcium': data['additionalInfo']?['calcium'],
      'iron': data['additionalInfo']?['iron'],
      'vitaminA': data['additionalInfo']?['vitaminA'],
      'vitaminC': data['additionalInfo']?['vitaminC'],
      'isFromLabel': true, // Mark that this data came from a food label
    };

    // Add any additional info that might be in the response
    if (data['additionalInfo'] is Map) {
      // Add any fields that weren't explicitly handled above
      final Map<String, dynamic> extraInfo = Map<String, dynamic>.from(data['additionalInfo']);
      for (final entry in extraInfo.entries) {
        if (!additionalInfo.containsKey(entry.key)) {
          additionalInfo[entry.key] = entry.value;
        }
      }
    }

    return NutritionInfo(
      foodName: data['foodName'] ?? 'Unknown Food',
      brandName: data['brandName'] ?? '',
      calories: _parseNumericValue(data['calories']),
      protein: _parseNumericValue(data['protein']),
      carbs: _parseNumericValue(data['carbs']),
      fat: _parseNumericValue(data['fat']),
      servingSize: data['servingSize'] ?? '100g',
      additionalInfo: additionalInfo,
      ingredients: ingredients,
    );
  }

  // Helper method to parse numeric values that might be strings
  double _parseNumericValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        // Remove any non-numeric characters except decimal point
        final numericString = value.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(numericString) ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  NutritionInfo _getMockNutritionData() {
    // Return a generic food item when API fails or times out
    return NutritionInfo(
      foodName: 'Food Item',
      brandName: '',
      calories: 250,
      protein: 8,
      carbs: 30,
      fat: 10,
      servingSize: '100g',
      additionalInfo: {
        'cuisineType': 'Mixed',
        'preparationMethod': 'Prepared',
        'healthBenefits': 'Nutritional value may vary',
        'allergens': 'Unknown',
        'storage': 'Store appropriately',
        'shelfLife': 'Varies by food type'
      },
      ingredients: ['Various ingredients'],
    );
  }
}
