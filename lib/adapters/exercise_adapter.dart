import 'package:hive/hive.dart';
import '../models/exercise.dart';

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 2; // Updated to 2 to avoid conflict with FoodHiveModelAdapter

  @override
  Exercise read(BinaryReader reader) {
    final id = reader.readString();
    final typeName = reader.readString();
    final typeDescription = reader.readString();
    final typeIcon = reader.readString();
    final intensity = IntensityLevel.values[reader.readInt()];
    final durationMinutes = reader.readInt();
    final date = DateTime.parse(reader.readString());
    final caloriesBurned = reader.readInt();
    final notes = reader.readString();
    final proteinBurned = reader.readDouble();
    final carbsBurned = reader.readDouble();
    final fatBurned = reader.readDouble();

    return Exercise(
      id: id,
      type: ExerciseType(
        name: typeName,
        description: typeDescription,
        icon: ExerciseType.getIconFromName(typeIcon),
      ),
      intensity: intensity,
      durationMinutes: durationMinutes,
      date: date,
      caloriesBurned: caloriesBurned,
      notes: notes,
      proteinBurned: proteinBurned,
      carbsBurned: carbsBurned,
      fatBurned: fatBurned,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.type.name);
    writer.writeString(obj.type.description);
    writer.writeString(ExerciseType.getIconName(obj.type.icon));
    writer.writeInt(obj.intensity.index);
    writer.writeInt(obj.durationMinutes);
    writer.writeString(obj.date.toIso8601String());
    writer.writeInt(obj.caloriesBurned);
    writer.writeString(obj.notes ?? '');
    writer.writeDouble(obj.proteinBurned);
    writer.writeDouble(obj.carbsBurned);
    writer.writeDouble(obj.fatBurned);
  }
}