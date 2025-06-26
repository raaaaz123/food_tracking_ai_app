import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';
import '../services/api_key_service.dart';

class GPTService {
  static final String _apiKey = ApiKeyService.getGptApiKey();
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, dynamic>> analyzeExercise(String description) async {
    try {


      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert fitness and nutrition analyzer. Analyze the exercise description and provide detailed information about the workout. 
              Return the data in a structured JSON format with the following fields:
              - intensity: "low", "medium", or "high"
              - duration: number of minutes
              - calories: estimated calories burned
              - protein: grams of protein burned
              - carbs: grams of carbohydrates burned
              - fat: grams of fat burned
              - notes: any additional notes about the exercise
              
              Example response format:
              {
                "intensity": "high",
                "duration": 30,
                "calories": 300.0,
                "protein": 5.0,
                "carbs": 10.0,
                "fat": 2.0,
                "notes": "High intensity interval training with good cardio benefits"
              }'''
            },
            {
              'role': 'user',
              'content': 'Analyze this exercise: $description'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );



      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
       

        try {
          final parsedContent = jsonDecode(content);
        
          return parsedContent;
        } catch (e) {
         
          // Try to extract JSON from the content if it's wrapped in text
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0);
            if (jsonStr != null) {
              return jsonDecode(jsonStr);
            }
          }
          throw Exception('Failed to parse GPT response: $e');
        }
      } else {
       
        throw Exception('Failed to analyze exercise: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
    
      throw Exception('Error analyzing exercise: $e');
    }
  }

  static Map<String, dynamic> parseGPTResponse(Map<String, dynamic> response) {
  

    // Ensure all required fields are present with correct types
    final parsedResponse = {
      'intensity': _parseIntensity(response['intensity']?.toString() ?? 'medium'),
      'duration': _parseInt(response['duration'], 30),
      'calories': _parseDouble(response['calories'], 0.0),
      'protein': _parseDouble(response['protein'], 0.0),
      'carbs': _parseDouble(response['carbs'], 0.0),
      'fat': _parseDouble(response['fat'], 0.0),
      'notes': response['notes']?.toString() ?? '',
    };

   
    return parsedResponse;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static IntensityLevel _parseIntensity(String intensity) {

    final normalizedIntensity = intensity.toLowerCase().trim();
    
    switch (normalizedIntensity) {
      case 'low':
        return IntensityLevel.low;
      case 'high':
        return IntensityLevel.high;
      case 'medium':
      default:
        return IntensityLevel.medium;
    }
  }
} 