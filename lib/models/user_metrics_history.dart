import 'package:hive/hive.dart';
part 'user_metrics_history.g.dart';

@HiveType(typeId: 5) // Make sure this ID doesn't conflict with existing types
class UserMetricsHistory extends HiveObject {
  @HiveField(0)
  final double startingWeight;

  @HiveField(1)
  final double startingHeight;

  @HiveField(2)
  final bool isMetric;

  @HiveField(3)
  final DateTime startDate;

  UserMetricsHistory({
    required this.startingWeight,
    required this.startingHeight,
    required this.isMetric,
    required this.startDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'startingWeight': startingWeight,
      'startingHeight': startingHeight,
      'isMetric': isMetric,
      'startDate': startDate,
    };
  }
} 