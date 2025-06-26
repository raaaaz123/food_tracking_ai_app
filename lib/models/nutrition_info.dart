class NutritionInfo {
  final String foodName;
  final String brandName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final Map<String, dynamic> additionalInfo;
  final List<String> ingredients;

  NutritionInfo({
    required this.foodName,
    required this.brandName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.additionalInfo,
    required this.ingredients,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    // Handle ingredients which might come as different formats
    List<String> ingredients = [];
    if (json['ingredients'] != null) {
      if (json['ingredients'] is List) {
        ingredients =
            List<String>.from(json['ingredients'].map((i) => i.toString()));
      } else if (json['ingredients'] is String) {
        ingredients = json['ingredients']
            .split(',')
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList();
      }
    }

    // Handle additionalInfo which might be in different formats
    Map<String, dynamic> additionalInfo = {};
    if (json['additionalInfo'] != null) {
      if (json['additionalInfo'] is Map) {
        // Convert all values to string format for consistency
        Map<String, dynamic> rawInfo =
            Map<String, dynamic>.from(json['additionalInfo']);
        rawInfo.forEach((key, value) {
          // Convert all values to string format
          if (value is List) {
            additionalInfo[key] = value.join(", ");
          } else if (value != null) {
            additionalInfo[key] = value.toString();
          } else {
            additionalInfo[key] = "";
          }
        });
      } else if (json['additionalInfo'] is String) {
        additionalInfo = {'description': json['additionalInfo']};
      }
    }

    return NutritionInfo(
      foodName: json['foodName'] ?? 'Unknown Food',
      brandName: json['brandName'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      servingSize: json['servingSize'] ?? '100g',
      additionalInfo: additionalInfo,
      ingredients: ingredients,
    );
  }

  Map<String, dynamic> toJson() {
    // Process additionalInfo to ensure all values are serializable
    Map<String, dynamic> processedAdditionalInfo = {};
    additionalInfo.forEach((key, value) {
      if (value is List) {
        processedAdditionalInfo[key] =
            value.map((item) => item.toString()).toList();
      } else {
        processedAdditionalInfo[key] = value?.toString() ?? '';
      }
    });

    return {
      'foodName': foodName,
      'brandName': brandName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'servingSize': servingSize,
      'additionalInfo': processedAdditionalInfo,
      'ingredients': ingredients,
    };
  }
}
