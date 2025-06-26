import 'package:hive/hive.dart';

part 'user_details.g.dart';

@HiveType(typeId: 0)
class UserDetails extends HiveObject {
  @HiveField(0)
  final double height;

  @HiveField(1)
  final double weight;

  @HiveField(2)
  final DateTime birthDate;

  @HiveField(3)
  final bool isMetric;

  @HiveField(4)
  final int workoutsPerWeek;

  @HiveField(5)
  final String weightGoal;

  @HiveField(6)
  final double targetWeight;

  @HiveField(7)
  final String gender;

  @HiveField(8)
  final String motivationGoal;

  @HiveField(9)
  final String dietType;

  @HiveField(10)
  final double weightChangeSpeed;
  
  @HiveField(11)
  final String? name;
  
  @HiveField(12)
  final String? email;
  
  @HiveField(13)
  final String? id;

  UserDetails({
    required this.height,
    required this.weight,
    required this.birthDate,
    required this.isMetric,
    required this.workoutsPerWeek,
    required this.weightGoal,
    required this.targetWeight,
    required this.gender,
    required this.motivationGoal,
    required this.dietType,
    required this.weightChangeSpeed,
    this.name,
    this.email,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'height': height,
      'weight': weight,
      'birthDate': birthDate,
      'isMetric': isMetric,
      'workoutsPerWeek': workoutsPerWeek,
      'weightGoal': weightGoal,
      'targetWeight': targetWeight,
      'gender': gender,
      'motivationGoal': motivationGoal,
      'dietType': dietType,
      'weightChangeSpeed': weightChangeSpeed,
      'name': name,
      'email': email,
      'id': id,
    };
  }
} 