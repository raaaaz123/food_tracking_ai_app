import 'package:hive/hive.dart';
import '../models/workout_plan.dart';

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