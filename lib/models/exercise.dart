import 'package:flutter/material.dart';

class ExerciseType {
  final String name;
  final String description;
  final IconData icon;
  final bool isCustom;

  ExerciseType({
    required this.name,
    required this.description,
    required this.icon,
    this.isCustom = false,
  });

  static IconData getIconFromName(String name) {
    switch (name) {
      case 'directions_run': return Icons.directions_run;
      case 'fitness_center': return Icons.fitness_center;
      case 'edit': return Icons.edit;
      case 'pool': return Icons.pool;
      case 'directions_bike': return Icons.directions_bike;
      case 'self_improvement': return Icons.self_improvement;
      default: return Icons.directions_run;
    }
  }

  static String getIconName(IconData icon) {
    if (icon == Icons.directions_run) return 'directions_run';
    if (icon == Icons.fitness_center) return 'fitness_center';
    if (icon == Icons.edit) return 'edit';
    if (icon == Icons.pool) return 'pool';
    if (icon == Icons.directions_bike) return 'directions_bike';
    if (icon == Icons.self_improvement) return 'self_improvement';
    return 'directions_run';
  }
}

enum IntensityLevel {
  low,
  medium,
  high,
}

class Exercise {
  final String id;
  final ExerciseType type;
  final IntensityLevel intensity;
  final int durationMinutes;
  final DateTime date;
  final int caloriesBurned;
  final String? notes;
  final double proteinBurned;
  final double carbsBurned;
  final double fatBurned;

  Exercise({
    required this.id,
    required this.type,
    required this.intensity,
    required this.durationMinutes,
    required this.date,
    required this.caloriesBurned,
    this.notes,
    this.proteinBurned = 0.0,
    this.carbsBurned = 0.0,
    this.fatBurned = 0.0,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      type: ExerciseType(
        name: json['typeName'],
        description: json['typeDescription'] ?? '',
        icon: ExerciseType.getIconFromName(json['typeIcon']),
      ),
      intensity: IntensityLevel.values[json['intensity']],
      durationMinutes: json['durationMinutes'],
      date: DateTime.parse(json['date']),
      caloriesBurned: json['caloriesBurned'],
      notes: json['notes'],
      proteinBurned: json['proteinBurned']?.toDouble() ?? 0.0,
      carbsBurned: json['carbsBurned']?.toDouble() ?? 0.0,
      fatBurned: json['fatBurned']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'typeName': type.name,
      'typeDescription': type.description,
      'typeIcon': ExerciseType.getIconName(type.icon),
      'intensity': intensity.index,
      'durationMinutes': durationMinutes,
      'date': date.toIso8601String(),
      'caloriesBurned': caloriesBurned,
      'notes': notes,
      'proteinBurned': proteinBurned,
      'carbsBurned': carbsBurned,
      'fatBurned': fatBurned,
    };
  }
}

extension ExerciseTypeJson on ExerciseType {
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'icon': ExerciseType.getIconName(icon),
      'isCustom': isCustom,
    };
  }
  
  static ExerciseType fromJson(Map<String, dynamic> json) {
    return ExerciseType(
      name: json['name'] ?? 'Unknown',
      description: json['description'] ?? '',
      icon: ExerciseType.getIconFromName(json['icon'] ?? 'directions_run'),
      isCustom: json['isCustom'] ?? false,
    );
  }
}
