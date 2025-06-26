import 'package:hive/hive.dart';

part 'workout_plan.g.dart';

@HiveType(typeId: 3)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  List<WorkoutExercise> exercises;

  @HiveField(5)
  String difficultyLevel;

  @HiveField(6)
  int estimatedDurationMinutes;

  @HiveField(7)
  int estimatedCaloriesBurn;

  @HiveField(8)
  String targetArea;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  int pointsEarned;

  @HiveField(11)
  List<String> achievementsUnlocked;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.exercises,
    required this.difficultyLevel,
    required this.estimatedDurationMinutes,
    required this.estimatedCaloriesBurn,
    required this.targetArea,
    required this.isCompleted,
    required this.pointsEarned,
    required this.achievementsUnlocked,
  });

  // Create a copy of the workout plan with new instances of exercises
  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? date,
    List<WorkoutExercise>? exercises,
    String? difficultyLevel,
    int? estimatedDurationMinutes,
    int? estimatedCaloriesBurn,
    String? targetArea,
    bool? isCompleted,
    int? pointsEarned,
    List<String>? achievementsUnlocked,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      date: date ?? this.date,
      exercises: exercises ?? List<WorkoutExercise>.from(this.exercises.map((e) => e.copyWith())),
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      estimatedCaloriesBurn: estimatedCaloriesBurn ?? this.estimatedCaloriesBurn,
      targetArea: targetArea ?? this.targetArea,
      isCompleted: isCompleted ?? this.isCompleted,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      achievementsUnlocked: achievementsUnlocked ?? List<String>.from(this.achievementsUnlocked),
    );
  }
}

@HiveType(typeId: 4)
class WorkoutExercise extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String description;

  @HiveField(2)
  final int sets;

  @HiveField(3)
  final int reps;

  @HiveField(4)
  final String duration;

  @HiveField(5)
  final String targetMuscles;

  @HiveField(6)
  final String instructions;

  @HiveField(7)
  bool isCompleted;

  @HiveField(8)
  final int pointsPerSet;

  @HiveField(9)
  List<String>? visualInstructions;

  @HiveField(10)
  String? visualUrl;

  @HiveField(11)
  List<String>? localImagePaths;

  @HiveField(12)
  Map<String, String>? youtubeUrls;

  @HiveField(13)
  List<String>? benefits;

  @HiveField(14)
  List<String>? precautions;

  @HiveField(15)
  List<String>? variations;

  @HiveField(16)
  List<String>? tips;

  @HiveField(17)
  List<String>? commonMistakes;

  WorkoutExercise({
    required this.name,
    required this.description,
    required this.sets,
    required this.reps,
    required this.duration,
    required this.targetMuscles,
    required this.instructions,
    this.isCompleted = false,
    required this.pointsPerSet,
    this.visualInstructions,
    this.visualUrl,
    this.localImagePaths,
    this.youtubeUrls,
    this.benefits,
    this.precautions,
    this.variations,
    this.tips,
    this.commonMistakes,
  });

  WorkoutExercise copyWith({
    String? name,
    String? description,
    int? sets,
    int? reps,
    String? duration,
    String? targetMuscles,
    String? instructions,
    bool? isCompleted,
    int? pointsPerSet,
    List<String>? visualInstructions,
    String? visualUrl,
    List<String>? localImagePaths,
    Map<String, String>? youtubeUrls,
    List<String>? benefits,
    List<String>? precautions,
    List<String>? variations,
    List<String>? tips,
    List<String>? commonMistakes,
  }) {
    return WorkoutExercise(
      name: name ?? this.name,
      description: description ?? this.description,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      duration: duration ?? this.duration,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      instructions: instructions ?? this.instructions,
      isCompleted: isCompleted ?? this.isCompleted,
      pointsPerSet: pointsPerSet ?? this.pointsPerSet,
      visualInstructions: visualInstructions ?? this.visualInstructions,
      visualUrl: visualUrl ?? this.visualUrl,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      youtubeUrls: youtubeUrls ?? this.youtubeUrls,
      benefits: benefits ?? this.benefits,
      precautions: precautions ?? this.precautions,
      variations: variations ?? this.variations,
      tips: tips ?? this.tips,
      commonMistakes: commonMistakes ?? this.commonMistakes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'sets': sets,
      'reps': reps,
      'duration': duration,
      'targetMuscles': targetMuscles,
      'instructions': instructions,
      'isCompleted': isCompleted,
      'pointsPerSet': pointsPerSet,
      'visualInstructions': visualInstructions,
      'visualUrl': visualUrl,
      'localImagePaths': localImagePaths,
      'youtubeUrls': youtubeUrls,
      'benefits': benefits,
      'precautions': precautions,
      'variations': variations,
      'tips': tips,
      'commonMistakes': commonMistakes,
    };
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      name: json['name'],
      description: json['description'],
      sets: json['sets'],
      reps: json['reps'],
      duration: json['duration'],
      targetMuscles: json['targetMuscles'],
      instructions: json['instructions'],
      isCompleted: json['isCompleted'] ?? false,
      pointsPerSet: json['pointsPerSet'],
      visualInstructions: json['visualInstructions'] != null 
          ? List<String>.from(json['visualInstructions'])
          : null,
      visualUrl: json['visualUrl'],
      localImagePaths: json['localImagePaths'] != null 
          ? List<String>.from(json['localImagePaths'])
          : null,
      youtubeUrls: json['youtubeUrls'] != null 
          ? Map<String, String>.from(json['youtubeUrls'])
          : null,
      benefits: json['benefits'] != null 
          ? List<String>.from(json['benefits'])
          : null,
      precautions: json['precautions'] != null 
          ? List<String>.from(json['precautions'])
          : null,
      variations: json['variations'] != null 
          ? List<String>.from(json['variations'])
          : null,
      tips: json['tips'] != null 
          ? List<String>.from(json['tips'])
          : null,
      commonMistakes: json['commonMistakes'] != null 
          ? List<String>.from(json['commonMistakes'])
          : null,
    );
  }
}
