class WorkoutExercise {
  final String name;
  final String description;
  final int sets;
  final int reps;
  final int? duration;
  final String targetMuscles;
  final String instructions;
  final bool isCompleted;
  final int pointsPerSet;
  final String? visualInstructions;
  final String? visualUrl;

  WorkoutExercise({
    required this.name,
    required this.description,
    required this.sets,
    required this.reps,
    this.duration,
    required this.targetMuscles,
    required this.instructions,
    this.isCompleted = false,
    required this.pointsPerSet,
    this.visualInstructions,
    this.visualUrl,
  });

  WorkoutExercise copyWith({
    String? name,
    String? description,
    int? sets,
    int? reps,
    int? duration,
    String? targetMuscles,
    String? instructions,
    bool? isCompleted,
    int? pointsPerSet,
    String? visualInstructions,
    String? visualUrl,
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
    );
  }
} 