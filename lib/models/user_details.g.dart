// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_details.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserDetailsAdapter extends TypeAdapter<UserDetails> {
  @override
  final int typeId = 0;

  @override
  UserDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserDetails(
      height: fields[0] as double,
      weight: fields[1] as double,
      birthDate: fields[2] as DateTime,
      isMetric: fields[3] as bool,
      workoutsPerWeek: fields[4] as int,
      weightGoal: fields[5] as String,
      targetWeight: fields[6] as double,
      gender: fields[7] as String,
      motivationGoal: fields[8] as String,
      dietType: fields[9] as String,
      weightChangeSpeed: fields[10] as double,
      name: fields[11] as String?,
      email: fields[12] as String?,
      id: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserDetails obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.height)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.birthDate)
      ..writeByte(3)
      ..write(obj.isMetric)
      ..writeByte(4)
      ..write(obj.workoutsPerWeek)
      ..writeByte(5)
      ..write(obj.weightGoal)
      ..writeByte(6)
      ..write(obj.targetWeight)
      ..writeByte(7)
      ..write(obj.gender)
      ..writeByte(8)
      ..write(obj.motivationGoal)
      ..writeByte(9)
      ..write(obj.dietType)
      ..writeByte(10)
      ..write(obj.weightChangeSpeed)
      ..writeByte(11)
      ..write(obj.name)
      ..writeByte(12)
      ..write(obj.email)
      ..writeByte(13)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
