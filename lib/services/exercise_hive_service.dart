import 'package:hive/hive.dart';
import 'package:nutrizen_ai/adapters/exercise_adapter.dart';
import '../models/exercise.dart';
import 'package:flutter/foundation.dart';

class ExerciseHiveService {
  static const String _boxName = 'exerciseBox';
  static Box<Exercise>? _exerciseBox;

  static Future<void> init() async {
    try {

      
      // Register the adapter if not already registered
      if (!Hive.isAdapterRegistered(2)) {

        Hive.registerAdapter(ExerciseAdapter());
    
      } else {
       
      }


      _exerciseBox = await Hive.openBox<Exercise>(_boxName);

    } catch (e) {

      // Try again with override
      try {
 
        Hive.registerAdapter(ExerciseAdapter(), override: true);
        _exerciseBox = await Hive.openBox<Exercise>(_boxName);
     
      } catch (retryError) {
      
        rethrow;
      }
    }
  }

  static Future<void> addExercise(Exercise exercise) async {
    try {

      
      // First, ensure the box is initialized
      if (_exerciseBox == null) {
     
        await init();
      }
      
      // Double-check that initialization worked
      if (_exerciseBox == null) {
        throw Exception('Could not initialize exercise storage');
      }
      
      // Save the exercise to Hive
      await _exerciseBox!.put(exercise.id, exercise);
      
   
    } catch (e) {

      
      // Try to recover by reopening the box
      try {
        
        await Hive.openBox<Exercise>(_boxName);
        
        // Try saving again
        await _exerciseBox!.put(exercise.id, exercise);
        
       
      } catch (recoveryError) {
    
        throw Exception('Failed to save exercise after retry: $recoveryError');
      }
    }
  }

  static List<Exercise> getExercisesForDate(DateTime date) {
    try {
      if (_exerciseBox == null) {
     
        init();
        if (_exerciseBox == null) {

          return [];
        }
      }
      
      final normalizedDate = DateTime(date.year, date.month, date.day);
     
      
      final exercises = _exerciseBox?.values.where((exercise) {
        final exerciseDate = DateTime(
          exercise.date.year,
          exercise.date.month,
          exercise.date.day
        );
        
        // More reliable date comparison
        final isSameDate = exerciseDate.year == normalizedDate.year && 
                          exerciseDate.month == normalizedDate.month && 
                          exerciseDate.day == normalizedDate.day;
        
        if (isSameDate) {
      
        }
        
        return isSameDate;
      }).toList() ?? [];
      
     
      return exercises;
    } catch (e) {

      return [];
    }
  }

  static List<Exercise> getAllExercises() {
    return _exerciseBox?.values.toList() ?? [];
  }

  static Future<void> deleteExercise(String id) async {
    await _exerciseBox?.delete(id);
  }

  static Future<void> clearAllExercises() async {
    await _exerciseBox?.clear();
  }

  static double getTotalCaloriesForDate(DateTime date) {
    final exercises = getExercisesForDate(date);
    return exercises.fold(0.0, (sum, exercise) => sum + exercise.caloriesBurned);
  }

  static Map<String, double> getTotalNutritionForDate(DateTime date) {
    final exercises = getExercisesForDate(date);
    return {
      'protein': exercises.fold(0.0, (sum, exercise) => sum + (exercise.proteinBurned ?? 0)),
      'carbs': exercises.fold(0.0, (sum, exercise) => sum + (exercise.carbsBurned ?? 0)),
      'fat': exercises.fold(0.0, (sum, exercise) => sum + (exercise.fatBurned ?? 0)),
    };
  }

  // Add calculation methods
  static int calculateCaloriesBurned({
    required String exerciseType,
    required IntensityLevel intensity,
    required int durationMinutes,
    required double weightKg,
  }) {
    // Base MET values for different exercises
    final Map<String, double> baseMetValues = {
      'Run': 9.8,
      'Weight lifting': 3.5,
      'Swimming': 6.0,
      'Cycling': 7.5,
      'Yoga': 2.5,
    };

    // Intensity multipliers
    final Map<IntensityLevel, double> intensityMultipliers = {
      IntensityLevel.low: 0.7,
      IntensityLevel.medium: 1.0,
      IntensityLevel.high: 1.3,
    };

    // Get base MET value for the exercise type
    final baseMet = baseMetValues[exerciseType] ?? 3.0;
    final intensityMultiplier = intensityMultipliers[intensity] ?? 1.0;
    
    // Calculate calories burned using MET formula
    // Calories = MET * weight(kg) * duration(hours)
    final durationHours = durationMinutes / 60.0;
    return (baseMet * weightKg * durationHours * intensityMultiplier).round();
  }

  static Map<String, double> calculateNutritionBurned({
    required String exerciseType,
    required IntensityLevel intensity,
    required int caloriesBurned,
  }) {
    // Nutrition burn ratios based on exercise type and intensity
    final Map<String, Map<IntensityLevel, double>> nutritionRatios = {
      'Run': {
        IntensityLevel.low: 0.4,
        IntensityLevel.medium: 0.5,
        IntensityLevel.high: 0.6,
      },
      'Weight lifting': {
        IntensityLevel.low: 0.3,
        IntensityLevel.medium: 0.4,
        IntensityLevel.high: 0.5,
      },
      'Swimming': {
        IntensityLevel.low: 0.4,
        IntensityLevel.medium: 0.5,
        IntensityLevel.high: 0.6,
      },
      'Cycling': {
        IntensityLevel.low: 0.4,
        IntensityLevel.medium: 0.5,
        IntensityLevel.high: 0.6,
      },
      'Yoga': {
        IntensityLevel.low: 0.3,
        IntensityLevel.medium: 0.4,
        IntensityLevel.high: 0.5,
      },
    };

    // Get ratios for the exercise type and intensity
    final ratios = nutritionRatios[exerciseType] ?? {
      IntensityLevel.low: 0.4,
      IntensityLevel.medium: 0.5,
      IntensityLevel.high: 0.6,
    };
    final ratio = ratios[intensity] ?? 0.5;

    // Calculate nutrition burned (in grams)
    // Using approximate conversion: 1g protein/carbs = 4 calories, 1g fat = 9 calories
    final proteinCalories = caloriesBurned * ratio * 0.4;
    final carbsCalories = caloriesBurned * ratio * 0.4;
    final fatCalories = caloriesBurned * ratio * 0.2;

    return {
      'protein': proteinCalories / 4.0,
      'carbs': carbsCalories / 4.0,
      'fat': fatCalories / 9.0,
    };
  }
} 