import 'package:hive/hive.dart';

@HiveType(typeId: 6)
class MealSuggestion {
  @HiveField(0)
  final String name;
  
  @HiveField(1)
  final String description;
  
  @HiveField(2)
  final Map<String, dynamic> nutritionInfo;
  
  @HiveField(3)
  final List<String> ingredients;
  
  @HiveField(4)
  final String instructions;
  
  @HiveField(5)
  final String imageUrl;
  
  @HiveField(6)
  final String mealType;
  
  @HiveField(7)
  final String cuisine;
  
  @HiveField(8)
  final String region;
  
  @HiveField(9)
  final DateTime createdAt;
  
  @HiveField(10)
  final String? audioUrl;

  MealSuggestion({
    required this.name,
    required this.description,
    required this.nutritionInfo,
    required this.ingredients,
    required this.instructions,
    this.imageUrl = '',
    required this.mealType,
    required this.cuisine,
    this.region = '',
    required this.createdAt,
    this.audioUrl,
  });

  // Create a copy with modified fields
  MealSuggestion copyWith({
    String? name,
    String? description,
    Map<String, dynamic>? nutritionInfo,
    List<String>? ingredients,
    String? instructions,
    String? imageUrl,
    String? mealType,
    String? cuisine,
    String? region,
    DateTime? createdAt,
    String? audioUrl,
  }) {
    return MealSuggestion(
      name: name ?? this.name,
      description: description ?? this.description,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      imageUrl: imageUrl ?? this.imageUrl,
      mealType: mealType ?? this.mealType,
      cuisine: cuisine ?? this.cuisine,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
} 