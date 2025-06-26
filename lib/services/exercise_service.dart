import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class ExerciseService {
  static const String _exercisesKey = 'user_exercises';

  // Singleton pattern
  static final ExerciseService _instance = ExerciseService._internal();

  factory ExerciseService() {
    return _instance;
  }

  ExerciseService._internal();

  // Get all exercises
  Future<List<Exercise>> getExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final exerciseJsonList = prefs.getStringList(_exercisesKey) ?? [];

    return exerciseJsonList
        .map((json) => Exercise.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date, newest first
  }

  // Get recent exercises (last 7 days)
  Future<List<Exercise>> getRecentExercises() async {
    final allExercises = await getExercises();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return allExercises
        .where((exercise) => exercise.date.isAfter(sevenDaysAgo))
        .toList();
  }

  // Get today's exercises
  Future<List<Exercise>> getTodayExercises() async {
    final allExercises = await getExercises();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allExercises.where((exercise) {
      final exerciseDate =
          DateTime(exercise.date.year, exercise.date.month, exercise.date.day);
      return exerciseDate.isAtSameMomentAs(today);
    }).toList();
  }

  // Get total calories burned today
  Future<int> getTodayCaloriesBurned() async {
    final todayExercises = await getTodayExercises();
    int total = 0;
    for (final exercise in todayExercises) {
      total += exercise.caloriesBurned;
    }
    return total;
  }

  // Get total calories burned this week
  Future<int> getWeekCaloriesBurned() async {
    final recentExercises = await getRecentExercises();
    int total = 0;
    for (final exercise in recentExercises) {
      total += exercise.caloriesBurned;
    }
    return total;
  }

  // Save a single exercise
  Future<bool> saveExercise(Exercise exercise) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure we have a clean date without time components
    DateTime cleanDate = DateTime(
      exercise.date.year,
      exercise.date.month,
      exercise.date.day
    );
    

    
    // Validate the exercise date before saving
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime validDate = cleanDate;
    
    // Check if the date is in the future (which could indicate a system time issue)
    if (validDate.isAfter(today)) {
     
      validDate = today;
      
      // Create a new exercise with the corrected date
      exercise = Exercise(
        id: exercise.id,
        type: exercise.type,
        intensity: exercise.intensity,
        durationMinutes: exercise.durationMinutes,
        date: validDate,
        caloriesBurned: exercise.caloriesBurned,
        notes: exercise.notes,
        proteinBurned: exercise.proteinBurned,
        carbsBurned: exercise.carbsBurned,
        fatBurned: exercise.fatBurned,
      );
    } else if (exercise.date != cleanDate) {
      // If the original date had time components, create a new exercise with the clean date
      exercise = Exercise(
        id: exercise.id,
        type: exercise.type,
        intensity: exercise.intensity,
        durationMinutes: exercise.durationMinutes,
        date: validDate,
        caloriesBurned: exercise.caloriesBurned,
        notes: exercise.notes,
        proteinBurned: exercise.proteinBurned,
        carbsBurned: exercise.carbsBurned,
        fatBurned: exercise.fatBurned,
      );
    }
    

    
    try {
      // Get existing exercises
      final exerciseJsonList = prefs.getStringList(_exercisesKey) ?? [];
      final exercises = exerciseJsonList
          .map((json) => Exercise.fromJson(jsonDecode(json)))
          .toList();
      
      // Check if we're updating an existing exercise or adding a new one
      final existingIndex = exercises.indexWhere((e) => e.id == exercise.id);
      if (existingIndex >= 0) {
        exercises[existingIndex] = exercise;
      } else {
        exercises.add(exercise);
      }
      
      // Save updated list
      final updatedJsonList = exercises
          .map((e) => jsonEncode(e.toJson()))
          .toList();
      
      final result = await prefs.setStringList(_exercisesKey, updatedJsonList);
  
      return result;
    } catch (e) {

      // Re-throw to allow proper error handling upstream
      throw Exception('Failed to save exercise: $e');
    }
  }

  // Delete an exercise
  Future<void> deleteExercise(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing exercises
    final exerciseJsonList = prefs.getStringList(_exercisesKey) ?? [];
    final exercises = exerciseJsonList
        .map((json) => Exercise.fromJson(jsonDecode(json)))
        .toList();
    
    // Remove the exercise with matching id
    exercises.removeWhere((e) => e.id == id);
    
    // Save updated list
    final updatedJsonList = exercises
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    
    await prefs.setStringList(_exercisesKey, updatedJsonList);
  }

  // Get exercises for a specific date range
  Future<List<Exercise>> getExercisesForDateRange(DateTime start, DateTime end) async {
    final allExercises = await getExercises();
    
  
    
    // Filter exercises by date and log what we find
    final filteredExercises = allExercises.where((exercise) {
      final isInRange = exercise.date.isAfter(start.subtract(const Duration(days: 1))) && 
             exercise.date.isBefore(end.add(const Duration(days: 1)));
      
      if (isInRange) {
      
      }
      
      return isInRange;
    }).toList();
    
    return filteredExercises;
  }

  // Calculate total calories burned in a date range
  Future<int> getTotalCaloriesBurned(DateTime start, DateTime end) async {
    final exercises = await getExercisesForDateRange(start, end);
    
    int total = 0;
    for (final exercise in exercises) {
      total += exercise.caloriesBurned;
    }
    return total;
  }

  // Calculate total workout time in minutes for a date range
  Future<int> getTotalWorkoutTime(DateTime start, DateTime end) async {
    final exercises = await getExercisesForDateRange(start, end);
    
    int total = 0;
    for (final exercise in exercises) {
      total += exercise.durationMinutes;
    }
    return total;
  }

  // Calculate calories burned based on exercise type, intensity, duration, and user weight
  int calculateCaloriesBurned({
    required String exerciseType,
    required IntensityLevel intensity,
    required int durationMinutes,
    required double weightKg,
  }) {
    // MET values (Metabolic Equivalent of Task)
    // These are approximate values
    Map<String, Map<IntensityLevel, double>> metValues = {
      'Run': {
        IntensityLevel.low: 5.0, // Walking/Light jog
        IntensityLevel.medium: 8.0, // Jogging
        IntensityLevel.high: 12.0, // Running/Sprinting
      },
      'Weight lifting': {
        IntensityLevel.low: 3.0, // Light effort
        IntensityLevel.medium: 5.0, // Moderate effort
        IntensityLevel.high: 6.0, // Vigorous effort
      },
      'Swimming': {
        IntensityLevel.low: 5.0, // Casual
        IntensityLevel.medium: 7.0, // Moderate
        IntensityLevel.high: 10.0, // Vigorous
      },
      'Cycling': {
        IntensityLevel.low: 4.0, // Leisure
        IntensityLevel.medium: 8.0, // Moderate
        IntensityLevel.high: 12.0, // Vigorous
      },
      'Yoga': {
        IntensityLevel.low: 2.5, // Hatha yoga
        IntensityLevel.medium: 4.0, // Power yoga
        IntensityLevel.high: 6.0, // Hot yoga
      },
      'Describe': {
        IntensityLevel.low: 3.0,
        IntensityLevel.medium: 5.0,
        IntensityLevel.high: 7.0,
      },
    };

    // Get MET value or use default
    double met = 5.0; // Default MET
    if (metValues.containsKey(exerciseType)) {
      met = metValues[exerciseType]![intensity] ?? met;
    }

    // Calories = MET × weight (kg) × duration (hours)
    double durationHours = durationMinutes / 60.0;
    int calories = (met * weightKg * durationHours).round();

    return calories;
  }

  // Calculate nutrients burned based on exercise type, intensity, and calories
  Map<String, double> calculateNutritionBurned({
    required String exerciseType,
    required IntensityLevel intensity,
    required int caloriesBurned,
  }) {
    // Different exercise types burn different proportions of macronutrients
    // These are estimated proportions based on exercise physiology
    Map<String, Map<String, double>> macroRatios = {
      'Run': {
        'protein': 0.05, // 5% of calories from protein
        'carbs': 0.70,   // 70% of calories from carbs
        'fat': 0.25,     // 25% of calories from fat
      },
      'Weight lifting': {
        'protein': 0.10, // 10% of calories from protein
        'carbs': 0.55,   // 55% of calories from carbs
        'fat': 0.35,     // 35% of calories from fat
      },
      'Swimming': {
        'protein': 0.05, // 5% of calories from protein
        'carbs': 0.65,   // 65% of calories from carbs
        'fat': 0.30,     // 30% of calories from fat
      },
      'Cycling': {
        'protein': 0.05, // 5% of calories from protein
        'carbs': 0.65,   // 65% of calories from carbs
        'fat': 0.30,     // 30% of calories from fat
      },
      'Yoga': {
        'protein': 0.07, // 7% of calories from protein
        'carbs': 0.58,   // 58% of calories from carbs
        'fat': 0.35,     // 35% of calories from fat
      },
      'Describe': {
        'protein': 0.06, // 6% of calories from protein
        'carbs': 0.64,   // 64% of calories from carbs
        'fat': 0.30,     // 30% of calories from fat
      },
    };

    // Intensity affects the proportion of fat to carbs (higher intensity = more carbs)
    double intensityFactor = 0.0;
    switch (intensity) {
      case IntensityLevel.low:
        intensityFactor = -0.1; // More fat, less carbs
        break;
      case IntensityLevel.medium:
        intensityFactor = 0.0; // Baseline
        break;
      case IntensityLevel.high:
        intensityFactor = 0.1; // More carbs, less fat
        break;
    }

    // Get default ratios if exercise type not found
    Map<String, double> ratios = macroRatios['Describe']!;
    if (macroRatios.containsKey(exerciseType)) {
      ratios = macroRatios[exerciseType]!;
    }

    // Adjust ratios based on intensity
    double adjustedCarbRatio = (ratios['carbs']! + intensityFactor).clamp(0.4, 0.8);
    double adjustedFatRatio = (ratios['fat']! - intensityFactor).clamp(0.15, 0.45);
    double proteinRatio = ratios['protein']!;

    // Normalize ratios to ensure they sum to 1.0
    double sum = proteinRatio + adjustedCarbRatio + adjustedFatRatio;
    proteinRatio = proteinRatio / sum;
    adjustedCarbRatio = adjustedCarbRatio / sum;
    adjustedFatRatio = adjustedFatRatio / sum;

    // Calculate grams of each macronutrient burned
    // Using 4 calories per gram of protein, 4 calories per gram of carbs, 9 calories per gram of fat
    double proteinBurned = (caloriesBurned * proteinRatio) / 4.0;
    double carbsBurned = (caloriesBurned * adjustedCarbRatio) / 4.0;
    double fatBurned = (caloriesBurned * adjustedFatRatio) / 9.0;

    return {
      'protein': double.parse(proteinBurned.toStringAsFixed(1)),
      'carbs': double.parse(carbsBurned.toStringAsFixed(1)),
      'fat': double.parse(fatBurned.toStringAsFixed(1)),
    };
  }

  // Clear all exercises (for testing)
  Future<void> clearExercises() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_exercisesKey);
  }

  // Get exercises for a specific date
  Future<List<Exercise>> getExercisesForDate(DateTime date) async {
    final allExercises = await getExercises();
    final targetDate = DateTime(date.year, date.month, date.day);
    

    
    // Filter exercises for the specific date
    final filteredExercises = allExercises.where((exercise) {
      final exerciseDate = DateTime(
        exercise.date.year, 
        exercise.date.month, 
        exercise.date.day
      );
      
      final isOnDate = exerciseDate.isAtSameMomentAs(targetDate);
      
      if (isOnDate) {
      
      }
      
      return isOnDate;
    }).toList();
    
   
    
    return filteredExercises;
  }
}
