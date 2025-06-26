// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final int typeId = 3;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      date: fields[3] as DateTime,
      exercises: (fields[4] as List).cast<WorkoutExercise>(),
      difficultyLevel: fields[5] as String,
      estimatedDurationMinutes: fields[6] as int,
      estimatedCaloriesBurn: fields[7] as int,
      targetArea: fields[8] as String,
      isCompleted: fields[9] as bool,
      pointsEarned: fields[10] as int,
      achievementsUnlocked: (fields[11] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.exercises)
      ..writeByte(5)
      ..write(obj.difficultyLevel)
      ..writeByte(6)
      ..write(obj.estimatedDurationMinutes)
      ..writeByte(7)
      ..write(obj.estimatedCaloriesBurn)
      ..writeByte(8)
      ..write(obj.targetArea)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.pointsEarned)
      ..writeByte(11)
      ..write(obj.achievementsUnlocked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutExerciseAdapter extends TypeAdapter<WorkoutExercise> {
  @override
  final int typeId = 4;

  @override
  WorkoutExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutExercise(
      name: fields[0] as String,
      description: fields[1] as String,
      sets: fields[2] as int,
      reps: fields[3] as int,
      duration: fields[4] as String,
      targetMuscles: fields[5] as String,
      instructions: fields[6] as String,
      isCompleted: fields[7] as bool,
      pointsPerSet: fields[8] as int,
      visualInstructions: (fields[9] as List?)?.cast<String>(),
      visualUrl: fields[10] as String?,
      localImagePaths: (fields[11] as List?)?.cast<String>(),
      youtubeUrls: (fields[12] as Map?)?.cast<String, String>(),
      benefits: (fields[13] as List?)?.cast<String>(),
      precautions: (fields[14] as List?)?.cast<String>(),
      variations: (fields[15] as List?)?.cast<String>(),
      tips: (fields[16] as List?)?.cast<String>(),
      commonMistakes: (fields[17] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutExercise obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.sets)
      ..writeByte(3)
      ..write(obj.reps)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.targetMuscles)
      ..writeByte(6)
      ..write(obj.instructions)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.pointsPerSet)
      ..writeByte(9)
      ..write(obj.visualInstructions)
      ..writeByte(10)
      ..write(obj.visualUrl)
      ..writeByte(11)
      ..write(obj.localImagePaths)
      ..writeByte(12)
      ..write(obj.youtubeUrls)
      ..writeByte(13)
      ..write(obj.benefits)
      ..writeByte(14)
      ..write(obj.precautions)
      ..writeByte(15)
      ..write(obj.variations)
      ..writeByte(16)
      ..write(obj.tips)
      ..writeByte(17)
      ..write(obj.commonMistakes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
