import 'package:hive/hive.dart';
import '../models/workout_exercise.dart';

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
      duration: fields[4] as int?,
      targetMuscles: fields[5] as String,
      instructions: fields[6] as String,
      isCompleted: fields[7] as bool,
      pointsPerSet: fields[8] as int,
      visualInstructions: fields[9] as String?,
      visualUrl: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutExercise obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.visualUrl);
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