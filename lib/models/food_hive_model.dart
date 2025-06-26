import 'package:hive/hive.dart';
import 'nutrition_info.dart';
part 'food_hive_model.g.dart';

@HiveType(typeId: 1)
class FoodHiveModel extends HiveObject {
  @HiveField(0)
  final String foodName;

  @HiveField(1)
  final String brandName;

  @HiveField(2)
  final double calories;

  @HiveField(3)
  final double protein;

  @HiveField(4)
  final double carbs;

  @HiveField(5)
  final double fat;

  @HiveField(6)
  final String servingSize;

  @HiveField(7)
  final List<String> ingredients;

  @HiveField(8)
  final Map<String, dynamic> additionalInfo;

  FoodHiveModel({
    required this.foodName,
    required this.brandName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.ingredients,
    required this.additionalInfo,
  });

  // Factory to create from NutritionInfo
  factory FoodHiveModel.fromNutritionInfo(NutritionInfo info) {
    return FoodHiveModel(
      foodName: info.foodName,
      brandName: info.brandName ?? '',
      calories: info.calories,
      protein: info.protein,
      carbs: info.carbs,
      fat: info.fat,
      servingSize: info.servingSize ?? '1 serving',
      ingredients: info.ingredients,
      additionalInfo: info.additionalInfo,
    );
  }

  // Convert to NutritionInfo for app usage
  NutritionInfo toNutritionInfo() {
    return NutritionInfo(
      foodName: foodName,
      brandName: brandName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingSize: servingSize,
      ingredients: ingredients,
      additionalInfo: additionalInfo,
    );
  }
  
  @override
  String toString() {
    return 'FoodHiveModel{foodName: $foodName, calories: $calories, servingSize: $servingSize}';
  }
}