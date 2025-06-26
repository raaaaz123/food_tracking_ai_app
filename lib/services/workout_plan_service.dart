import 'package:hive_flutter/hive_flutter.dart';
import '../models/workout_plan.dart';
import '../models/face_analysis.dart';
import 'dart:math';

class WorkoutPlanService {
  static const String _boxName = 'workoutPlans';
  static Box<WorkoutPlan>? _box;

  static Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox<WorkoutPlan>(_boxName);
  }

  static Future<void> _ensureBoxIsOpen() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<WorkoutPlan>(_boxName);
    }
  }

  static Future<void> savePlan(WorkoutPlan plan) async {
    if (_box == null) await init();
    
    // Create a new instance to avoid HiveObject error
    final newPlan = plan.copyWith();
    await _box!.put(plan.id, newPlan);
  }

  static Future<void> updatePlan(WorkoutPlan plan) async {
    if (_box == null) await init();
    
    // Create a new instance to avoid HiveObject error
    final newPlan = plan.copyWith();
    await _box!.put(plan.id, newPlan);
  }

  static Future<List<WorkoutPlan>> getAllPlans() async {
    if (_box == null) await init();
    
    // Return a copy of each plan to avoid HiveObject errors
    return _box!.values.map((plan) => plan.copyWith()).toList();
  }

  static Future<void> deletePlan(String id) async {
    if (_box == null) await init();
    await _box!.delete(id);
  }

  static Future<WorkoutPlan?> getPlan(String id) async {
    if (_box == null) await init();
    final plan = _box!.get(id);
    if (plan != null) {
      // Return a copy to avoid HiveObject errors
      return plan.copyWith();
    }
    return null;
  }

  static Future<WorkoutPlan?> getCurrentDayPlan() async {
    if (_box == null) await init();
    final plans = await getAllPlans();
    if (plans.isEmpty) return null;
    
    // Find a plan for today, or return the most recent one
    final today = DateTime.now();
    for (var plan in plans) {
      if (plan.date.day == today.day && plan.date.month == today.month && plan.date.year == today.year) {
        return plan;
      }
    }
    
    // If no plan for today, return the most recent one
    plans.sort((a, b) => b.date.compareTo(a.date));
    return plans.first;
  }

  static Future<void> generateAndSaveWorkoutPlan() async {
    if (_box == null) await init();
    final plan = await _generateRandomWorkoutPlan();
    await savePlan(plan);
  }
  
  static Future<WorkoutPlan> _generateRandomWorkoutPlan() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random();
    final difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
    final targetAreas = ['Full Face', 'Jaw', 'Cheeks', 'Forehead', 'Eyes'];
    
    return WorkoutPlan(
      id: id,
      name: 'Daily Workout ${DateTime.now().day}/${DateTime.now().month}',
      description: 'Generated workout plan for today',
      date: DateTime.now(),
      exercises: _generateRandomExercises(random.nextInt(3) + 3),
      difficultyLevel: difficultyLevels[random.nextInt(difficultyLevels.length)],
      estimatedDurationMinutes: random.nextInt(20) + 10,
      estimatedCaloriesBurn: random.nextInt(100) + 50,
      targetArea: targetAreas[random.nextInt(targetAreas.length)],
      isCompleted: false,
      pointsEarned: 0,
      achievementsUnlocked: [],
    );
  }
  
  static List<WorkoutExercise> _generateRandomExercises(int count) {
    final random = Random();
    final exercises = <WorkoutExercise>[];
    final exerciseNames = [
      'Cheek Puffer', 'Jaw Sculptor', 'Forehead Smoother', 
      'Eye Lifter', 'Neck Tightener', 'Lip Lifter'
    ];
    
    for (int i = 0; i < count; i++) {
      exercises.add(
        WorkoutExercise(
          name: exerciseNames[random.nextInt(exerciseNames.length)],
          description: 'Exercise to strengthen facial muscles',
          sets: random.nextInt(3) + 1,
          reps: random.nextInt(10) + 5,
          duration: '${random.nextInt(2) + 1} minutes',
          targetMuscles: 'Face',
          instructions: 'Follow the visual instructions for proper form',
          isCompleted: false,
          pointsPerSet: random.nextInt(10) + 5,
          visualInstructions: null,
          visualUrl: null,
        )
      );
    }
    
    return exercises;
  }
  
  static Future<WorkoutPlan> createPersonalizedPlan(
    FaceAnalysis analysis,
    String gender,
  ) async {
    if (_box == null) await init();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random();
    
    return WorkoutPlan(
      id: id,
      name: 'Personalized Plan ${DateTime.now().day}/${DateTime.now().month}',
      description: 'Custom workout based on your face analysis',
      date: DateTime.now(),
      exercises: _generateRandomExercises(random.nextInt(3) + 3),
      difficultyLevel: 'Personalized',
      estimatedDurationMinutes: random.nextInt(20) + 10,
      estimatedCaloriesBurn: random.nextInt(100) + 50,
      targetArea: 'Full Face',
      isCompleted: false,
      pointsEarned: 0,
      achievementsUnlocked: [],
    );
  }

  static Future<void> markExerciseCompleted(String planId, String exerciseName, bool isCompleted) async {
    if (_box == null) await init();
    final plan = _box!.get(planId);
    if (plan != null) {
      final exercise = plan.exercises.firstWhere((e) => e.name == exerciseName);
      exercise.isCompleted = isCompleted;
      await savePlan(plan);
    }
  }

  // Get a specific exercise from a plan by its name
  static Future<WorkoutExercise?> getExerciseById(String planId, String exerciseName) async {
    if (_box == null) await init();
    final plan = _box!.get(planId);
    if (plan != null) {
      try {
        final exerciseIndex = plan.exercises.indexWhere((e) => e.name == exerciseName);
        if (exerciseIndex != -1) {
          return plan.exercises[exerciseIndex];
        }
      } catch (e) {
        // Handle any errors
        print('Error getting exercise: $e');
      }
    }
    return null;
  }

  static Future<void> deleteAllPlans() async {
    await _ensureBoxIsOpen();
    await _box!.clear();
  }
} 