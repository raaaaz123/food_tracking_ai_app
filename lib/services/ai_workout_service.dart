import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_plan.dart' as workout_model;
import '../models/face_analysis.dart';
import 'dart:math';
import '../services/local_storage_service.dart';
import '../services/api_key_service.dart';

class AIWorkoutService {
  static final String _gptApiKey = ApiKeyService.getGptApiKey();
  static const String _gptApiUrl = 'https://api.openai.com/v1/chat/completions';
  
  static final String _geminiApiKey = ApiKeyService.getGeminiApiKey();
  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  static const String _geminiImageGenerationUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent';

  // You need to get a key from https://platform.stability.ai/
  static const String _stabilityApiKey = 'YOUR_STABILITY_API_KEY'; 
  static const String _stabilityApiUrl = 'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image';

  static Future<workout_model.WorkoutPlan> generateWorkoutPlan(FaceAnalysis faceAnalysis) async {
    try {
      // Prepare the prompt for GPT-4
      final prompt = '''
        Based on the following face analysis results, create a personalized face workout plan:
        
        Face Analysis:
        ${_formatFaceAnalysis(faceAnalysis)}
        
        Please create a detailed workout plan with 5-7 exercises specifically targeting the areas that need improvement.
        For each exercise, include:
        - Name
        - Description
        - Number of sets
        - Number of repetitions
        - Duration
        - Target muscles
        - Detailed instructions
        - Points per set
        
        Format the response as a JSON object with the following structure:
        {
          "name": "string",
          "description": "string",
          "exercises": [
            {
              "name": "string",
              "description": "string",
              "sets": number,
              "reps": number,
              "duration": "string",
              "targetMuscles": "string",
              "instructions": "string",
              "pointsPerSet": number
            }
          ],
          "difficultyLevel": "string",
          "estimatedDurationMinutes": number,
          "estimatedCaloriesBurn": number,
          "targetArea": "string"
        }
      ''';

      // Call GPT-4 API
      final response = await http.post(
        Uri.parse(_gptApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_gptApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {'role': 'system', 'content': 'You are a professional facial fitness trainer.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final workoutJson = jsonDecode(data['choices'][0]['message']['content']);
        
        // Create workout plan from JSON
        return workout_model.WorkoutPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: workoutJson['name'],
          description: workoutJson['description'],
          date: DateTime.now(),
          exercises: (workoutJson['exercises'] as List).map((exercise) {
            return workout_model.WorkoutExercise(
              name: exercise['name'],
              description: exercise['description'],
              sets: exercise['sets'],
              reps: exercise['reps'],
              duration: exercise['duration'],
              targetMuscles: exercise['targetMuscles'],
              instructions: exercise['instructions'],
              isCompleted: false,
              pointsPerSet: exercise['pointsPerSet'],
              visualInstructions: null,
              visualUrl: null,
            );
          }).toList(),
          difficultyLevel: workoutJson['difficultyLevel'],
          estimatedDurationMinutes: workoutJson['estimatedDurationMinutes'],
          estimatedCaloriesBurn: workoutJson['estimatedCaloriesBurn'],
          targetArea: workoutJson['targetArea'],
          isCompleted: false,
          pointsEarned: 0,
          achievementsUnlocked: [],
        );
      } else {
        throw Exception('Failed to generate workout plan: ${response.statusCode}');
      }
    } catch (e) {
    
      rethrow;
    }
  }

  static Future<List<String>> generateExerciseImages(String exerciseName, String instructions) async {
    try {
      final prompt = '''
        Create two realistic photographic images of a properly dressed person showing how to perform the following face exercise:
        
        Exercise: $exerciseName
        Instructions: $instructions
        
        The images should show:
        1. Starting position
        2. Final position or movement
        
        IMPORTANT CONSTRAINTS:
        - Show a real human person with modest clothing (no exposed skin except face/hands)
        - ONLY external face/body (NO internal anatomy, cross-sections, or diagrams)
        - Clear, well-lit images focused on the facial muscles being worked
        - Only ONE person in each image
        - NO text, labels, arrows, or annotations on the images
        - NO diagrams, sketches or graphics - only realistic photography
        - NO split images or multiple frames
      ''';

      // Add API key as a query parameter
      final url = Uri.parse('$_geminiApiUrl?key=$_geminiApiKey');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 1024,
          }
        }),
      );


      
      // Create safer placeholder images using placehold.co instead of via.placeholder.com
      // Encode the exercise name for the URL
      final encodedName = Uri.encodeComponent(exerciseName);
      final startPlaceholder = 'https://placehold.co/400x300/e8f4f8/333333?text=$encodedName+-+Start';
      final endPlaceholder = 'https://placehold.co/400x300/e8f4f8/333333?text=$encodedName+-+End';
      
      if (response.statusCode == 200) {

        // Use reliable placeholder images
        return [startPlaceholder, endPlaceholder];
      } else {

        // Return placeholder images instead of throwing
        return [startPlaceholder, endPlaceholder];
      }
    } catch (e) {

      // Return placeholder images instead of rethrowing
      return [
        'https://placehold.co/400x300/f8e8e8/333333?text=Start+Position',
        'https://placehold.co/400x300/f8e8e8/333333?text=End+Position'
      ];
    }
  }

  static String _formatFaceAnalysis(FaceAnalysis analysis) {
    final buffer = StringBuffer();
    
    // Add scores
    buffer.writeln('Scores:');
    analysis.scores.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });
    
    // Add attributes
    buffer.writeln('\nAttributes:');
    analysis.attributes.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });
    
    // Add recommendations
    buffer.writeln('\nRecommendations:');
    analysis.recommendations.forEach((recommendation) {
      buffer.writeln('- ${recommendation.title}: ${recommendation.description}');
    });
    
    return buffer.toString();
  }

  // New method to generate a default workout plan without images
  static Future<workout_model.WorkoutPlan> generateWorkoutPlanWithoutImages(FaceAnalysis faceAnalysis) async {
    // This is a duplicate of generateWorkoutPlan but doesn't generate images
    final plan = await generateWorkoutPlan(faceAnalysis);
    return plan;
  }

  // New method to generate images for a single exercise
  static Future<workout_model.WorkoutExercise> generateImagesForExercise(workout_model.WorkoutExercise exercise) async {
    try {
      print('AIWorkoutService: Starting image generation for ${exercise.name}');
      // Generate two images using OpenAI's gpt-image-1 model
      final startPositionPrompt = '''
        Generate a high-quality image of a single adult person showing the starting position for the facial exercise: ${exercise.name}
        Description: ${exercise.description}
        
        Requirements:
        - A real human person with normal clothing
        - Clear demonstration of the starting position
        - Well-lit environment with neutral background
        - Focus on facial muscles from outside
        - Only ONE person in the image
        - No text or labels
        - Realistic photographic style
      ''';

      final endPositionPrompt = '''
        Generate a high-quality image of a single adult person showing the final position for the facial exercise: ${exercise.name}
        Description: ${exercise.description}
        
        Requirements:
        - A real human person with normal clothing
        - Clear demonstration of the final position
        - Well-lit environment with neutral background
        - Focus on facial muscles from outside
        - Only ONE person in the image
        - No text or labels
        - Realistic photographic style
      ''';

      print('AIWorkoutService: Sending start position image request');
      // Generate start position image using OpenAI's API
      final startImageResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_gptApiKey'
        },
        body: jsonEncode({
          'model': 'gpt-image-1',
          'prompt': startPositionPrompt,
          'n': 1,
          'size': '1024x1024',
          'quality': 'medium',
          // response_format removed as it's not supported
        }),
      );

      print('AIWorkoutService: Sending end position image request');
      // Generate end position image using OpenAI's API
      final endImageResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_gptApiKey'
        },
        body: jsonEncode({
          'model': 'gpt-image-1',
          'prompt': endPositionPrompt,
          'n': 1,
          'size': '1024x1024',
          'quality': 'medium',
          // response_format removed as it's not supported
        }),
      );

      print('AIWorkoutService: Both image requests completed');
      List<String> imageDataList = [];

      // Process start position image response
      if (startImageResponse.statusCode == 200) {
        print('AIWorkoutService: Start image response success (status ${startImageResponse.statusCode})');
        final startData = jsonDecode(startImageResponse.body);
        print('AIWorkoutService: Parsed start image JSON response: ${startData.keys.join(", ")}');
        
        if (startData.containsKey('data') && startData['data'].isNotEmpty) {
          print('AIWorkoutService: Found data in start image response');
          
          // Check for URL or base64 data
          if (startData['data'][0].containsKey('url')) {
            // If URL is returned, download the image and convert to base64
            print('AIWorkoutService: Found URL in start image response');
            final imageUrl = startData['data'][0]['url'];
            print('AIWorkoutService: Downloading image from URL: $imageUrl');
            
            try {
              final imageResponse = await http.get(Uri.parse(imageUrl));
              if (imageResponse.statusCode == 200) {
                final bytes = imageResponse.bodyBytes;
                final base64String = base64Encode(bytes);
                imageDataList.add(base64String);
                print('AIWorkoutService: Successfully downloaded and encoded start image (${bytes.length} bytes)');
              } else {
                print('AIWorkoutService: Failed to download image: ${imageResponse.statusCode}');
              }
            } catch (e) {
              print('AIWorkoutService: Error downloading image: $e');
            }
          } else if (startData['data'][0].containsKey('b64_json')) {
            // If base64 data is returned directly
            final String base64Data = startData['data'][0]['b64_json'];
            imageDataList.add(base64Data);
            print('AIWorkoutService: Added start image base64 data (length: ${base64Data.length} chars)');
          } else {
            print('AIWorkoutService: No recognized image format in response: ${startData['data'][0].keys.join(", ")}');
          }
        } else {
          print('AIWorkoutService: No data found in start image response: ${startData.keys.join(", ")}');
        }
      } else {
        print('AIWorkoutService: Start image request failed with status ${startImageResponse.statusCode}');
        print('AIWorkoutService: Error response: ${startImageResponse.body}');
      }

      // Process end position image response
      if (endImageResponse.statusCode == 200) {
        print('AIWorkoutService: End image response success (status ${endImageResponse.statusCode})');
        final endData = jsonDecode(endImageResponse.body);
        print('AIWorkoutService: Parsed end image JSON response: ${endData.keys.join(", ")}');
        
        if (endData.containsKey('data') && endData['data'].isNotEmpty) {
          print('AIWorkoutService: Found data in end image response');
          
          // Check for URL or base64 data
          if (endData['data'][0].containsKey('url')) {
            // If URL is returned, download the image and convert to base64
            print('AIWorkoutService: Found URL in end image response');
            final imageUrl = endData['data'][0]['url'];
            print('AIWorkoutService: Downloading image from URL: $imageUrl');
            
            try {
              final imageResponse = await http.get(Uri.parse(imageUrl));
              if (imageResponse.statusCode == 200) {
                final bytes = imageResponse.bodyBytes;
                final base64String = base64Encode(bytes);
                imageDataList.add(base64String);
                print('AIWorkoutService: Successfully downloaded and encoded end image (${bytes.length} bytes)');
              } else {
                print('AIWorkoutService: Failed to download image: ${imageResponse.statusCode}');
              }
            } catch (e) {
              print('AIWorkoutService: Error downloading image: $e');
            }
          } else if (endData['data'][0].containsKey('b64_json')) {
            // If base64 data is returned directly
            final String base64Data = endData['data'][0]['b64_json'];
            imageDataList.add(base64Data);
            print('AIWorkoutService: Added end image base64 data (length: ${base64Data.length} chars)');
          } else {
            print('AIWorkoutService: No recognized image format in response: ${endData['data'][0].keys.join(", ")}');
          }
        } else {
          print('AIWorkoutService: No data found in end image response: ${endData.keys.join(", ")}');
        }
      } else {
        print('AIWorkoutService: End image request failed with status ${endImageResponse.statusCode}');
        print('AIWorkoutService: Error response: ${endImageResponse.body}');
      }

      print('AIWorkoutService: Total images collected: ${imageDataList.length}');
      
      // Create a new instance of the exercise with the generated images
      return workout_model.WorkoutExercise(
        name: exercise.name,
        description: exercise.description,
        sets: exercise.sets,
        reps: exercise.reps,
        duration: exercise.duration,
        targetMuscles: exercise.targetMuscles,
        instructions: exercise.instructions,
        isCompleted: exercise.isCompleted,
        pointsPerSet: exercise.pointsPerSet,
        visualInstructions: imageDataList.isNotEmpty ? imageDataList : null,
        visualUrl: null,
      );
    } catch (e) {
      print('AIWorkoutService: Error generating images: $e');
      // Return the original exercise if generation fails
      return exercise;
    }
  }
  
  // Helper method to generate a single image using OpenAI's gpt-image-1 model
  static Future<String?> _generateImageWithGPT(String prompt) async {
    try {
      // Ensure the prompt includes constraints to avoid anatomical diagrams
      final enhancedPrompt = '''
$prompt

IMPORTANT CONSTRAINTS:
- Generate realistic photographic images only
- Show only external human features
- Include only ONE person in the image
- No text overlays or labels
''';
      
      final url = Uri.parse('https://api.openai.com/v1/images/generations');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_gptApiKey'
        },
        body: jsonEncode({
          'model': 'gpt-image-1',
          'prompt': enhancedPrompt,
          'n': 1,
          'size': '1024x1024',
          'quality': 'medium',
          'response_format': 'b64_json'
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        try {
          if (data.containsKey('data') && data['data'].isNotEmpty) {
            final String base64Data = data['data'][0]['b64_json'];
            return 'data:image/jpeg;base64,$base64Data';
          }
        } catch (e) {
          // Handle parsing errors
        }
      }
    } catch (e) {
      // Handle request errors
    }
    return null;
  }

  // Helper method to generate a single image using DALL-E
  static Future<String?> _generateDallEImage(String prompt) async {
    try {
      // Enhance the prompt with constraints
      final enhancedPrompt = '''
$prompt

IMPORTANT CONSTRAINTS:
- Generate a realistic photographic image of a single person in modest clothing
- Show only external physical features (NO internal anatomy, cross-sections, or anatomical diagrams)
- Include only ONE person in the image
- NO text overlays, labels, arrows, or annotations
- NO diagrams, sketches or graphics - only realistic photography
- NO split images or multiple frames
''';
      
    
      final url = Uri.parse('https://api.openai.com/v1/images/generations');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_gptApiKey'
        },
        body: jsonEncode({
          'model': 'dall-e-3',
          'prompt': enhancedPrompt,
          'n': 1,
          'size': '1024x1024',
          'quality': 'standard',
          'response_format': 'url'
        }),
      );
      
    
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data'][0]['url'];
      
      } else {
       
        return null;
      }
    } catch (e) {

      return null;
    }
  }

  // New method to generate weight goal projection using Gemini
  static Future<Map<String, dynamic>> getWeightGoalProjection({
    required double startWeight,
    required double targetWeight,
    required String weightGoal,
    required double weightChangeSpeed,
  }) async {
    try {
      // Get pace description based on the updated speed values
      String paceDescription;
      if (weightGoal == 'lose') {
        if (weightChangeSpeed >= 1.0) {
          paceDescription = 'fast (1.0 kg per week)';
        } else if (weightChangeSpeed >= 0.5) {
          paceDescription = 'moderate (0.5 kg per week)';
        } else {
          paceDescription = 'slow (0.25 kg per week)';
        }
      } else if (weightGoal == 'gain') {
        if (weightChangeSpeed >= 0.75) {
          paceDescription = 'fast (0.75 kg per week)';
        } else if (weightChangeSpeed >= 0.5) {
          paceDescription = 'moderate (0.5 kg per week)';
        } else {
          paceDescription = 'slow (0.25 kg per week)';
        }
      } else {
        paceDescription = 'maintenance (0.0 kg per week)';
      }

      // Prepare the prompt for Gemini
      final prompt = '''
        I need you to provide a scientifically sound weight ${weightGoal == 'lose' ? 'loss' : weightGoal == 'gain' ? 'gain' : 'maintenance'} projection.
        
        Starting weight: $startWeight kg
        Target weight: $targetWeight kg
        Goal: $weightGoal
        Selected pace: $paceDescription
        Exact weekly change rate: $weightChangeSpeed kg per week
        
        Please calculate:
        1. The exact weekly rate of weight change in kg (weightChangePerWeek) - should be $weightChangeSpeed
        2. The total number of weeks needed to reach the target (totalWeeks)
        
        For maintenance goals, recommend a standard 12-week program.
        
        Return ONLY a valid JSON object with exactly these two fields:
        {
          "weightChangePerWeek": number,
          "totalWeeks": number
        }
      ''';

      // Add API key as a query parameter
      final url = Uri.parse('$_geminiApiUrl?key=$_geminiApiKey');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('candidates') && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0].containsKey('content')) {
          
          final content = data['candidates'][0]['content'];
          final parts = content['parts'] as List;
          
          String jsonString = '';
          for (var part in parts) {
            if (part.containsKey('text')) {
              final text = part['text'] as String;
              
              // Extract only the JSON part from the text (remove any explanations)
              final jsonRegex = RegExp(r'\{.*\}', dotAll: true);
              final match = jsonRegex.firstMatch(text);
              
              if (match != null) {
                jsonString = match.group(0) ?? '';
                break;
              } else {
                jsonString = text;
              }
            }
          }
          
          // Parse the JSON string
          final Map<String, dynamic> projectionData = jsonDecode(jsonString);
          
          // Ensure we have the required fields
          if (projectionData.containsKey('weightChangePerWeek') && 
              projectionData.containsKey('totalWeeks')) {
            return {
              'weightChangePerWeek': projectionData['weightChangePerWeek'] as double,
              'totalWeeks': projectionData['totalWeeks'] as int,
            };
          }
        }
      }
      
      // Fallback calculation if API fails to return expected format
      return _calculateFallbackProjection(startWeight, targetWeight, weightGoal, weightChangeSpeed);
    } catch (e) {
      // Use fallback calculation in case of any error
      return _calculateFallbackProjection(startWeight, targetWeight, weightGoal, weightChangeSpeed);
    }
  }
  
  // Helper method to calculate fallback projection values
  static Map<String, dynamic> _calculateFallbackProjection(
    double startWeight, 
    double targetWeight, 
    String weightGoal,
    double weightChangeSpeed,
  ) {
    // Calculate weight difference
    final double weightDifference = (targetWeight - startWeight).abs();
    
    // Use the selected speed directly from GainSpeedScreen
    double weeklyRate = weightChangeSpeed;
    
    // Safety check: ensure we have a valid rate
    if (weightGoal == 'maintain') {
      weeklyRate = 0.0; // No change for maintenance
    } else if (weeklyRate <= 0) {
      // Fallback to standard values if something went wrong
      weeklyRate = (weightGoal == 'lose') ? 0.5 : 0.25;
    }
    
    // Calculate total weeks needed (with a minimum of 1 week)
    int totalWeeks;
    if (weeklyRate == 0 || weightDifference == 0) {
      // For maintenance or if already at target weight
      totalWeeks = 12; // Default 12-week maintenance program
    } else {
      totalWeeks = max(1, (weightDifference / weeklyRate).ceil());
    }
    
    return {
      'weightChangePerWeek': weeklyRate,
      'totalWeeks': totalWeeks,
    };
  }
} 