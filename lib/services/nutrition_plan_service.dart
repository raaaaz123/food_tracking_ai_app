class NutritionPlanService {
  static Map<String, double> calculateNutritionPlan({
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) {
    // Calculate BMR (Basal Metabolic Rate)
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }

    // Apply activity level multiplier
    double activityMultiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very_active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.55; // Default to moderate
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    double tdee = bmr * activityMultiplier;

    // Apply goal adjustment
    switch (goal.toLowerCase()) {
      case 'lose':
        tdee -= 500; // Create a 500 calorie deficit
        break;
      case 'gain':
        tdee += 500; // Create a 500 calorie surplus
        break;
      case 'maintain':
      default:
        // No adjustment needed
        break;
    }

    // Calculate macronutrient distribution
    // Protein: 1.6-2.2g per kg of body weight
    double proteinGrams = weight * 2.0;
    double proteinCalories = proteinGrams * 4;

    // Fat: 20-35% of total calories
    double fatCalories = tdee * 0.25;
    double fatGrams = fatCalories / 9;

    // Carbs: Remaining calories
    double carbCalories = tdee - proteinCalories - fatCalories;
    double carbGrams = carbCalories / 4;

    return {
      'calories': tdee,
      'protein': proteinGrams,
      'carbs': carbGrams,
      'fat': fatGrams,
    };
  }
} 