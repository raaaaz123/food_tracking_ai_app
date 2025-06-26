// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_metrics_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserMetricsHistoryAdapter extends TypeAdapter<UserMetricsHistory> {
  @override
  final int typeId = 5;

  @override
  UserMetricsHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserMetricsHistory(
      startingWeight: fields[0] as double,
      startingHeight: fields[1] as double,
      isMetric: fields[2] as bool,
      startDate: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserMetricsHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.startingWeight)
      ..writeByte(1)
      ..write(obj.startingHeight)
      ..writeByte(2)
      ..write(obj.isMetric)
      ..writeByte(3)
      ..write(obj.startDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserMetricsHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
