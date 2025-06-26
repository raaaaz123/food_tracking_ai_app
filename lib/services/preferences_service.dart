import 'package:shared_preferences/shared_preferences.dart';

// DEPRECATED: This service is being replaced by direct Hive usage.
// New code should use Hive for storage instead of SharedPreferences.
class PreferencesService {
  static const String _heightKey = 'user_height';
  static const String _weightKey = 'user_weight';
  static const String _birthDateKey = 'user_birth_date';
  static const String _isMetricKey = 'is_metric';
  static const String _workoutsPerWeekKey = 'workouts_per_week';
  static const String _weightGoalKey = 'weight_goal';
  static const String _targetWeightKey = 'target_weight';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _genderKey = 'gender';
  static const String _motivationGoalKey = 'motivation_goal';
  static const String _dietTypeKey = 'diet_type';
  static const String _weightChangeSpeedKey = 'weight_change_speed';
  static const String _nameKey = 'userName';

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedOnboardingKey) != true;
  }

  static Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, !value);
  }

  static Future<void> saveUserDetails({
    required double height,
    required double weight,
    required DateTime birthDate,
    required bool isMetric,
    int? workoutsPerWeek,
    String? weightGoal,
    double? targetWeight,
    String? gender,
    String? motivationGoal,
    String? dietType,
    double? weightChangeSpeed,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_heightKey, height);
    await prefs.setDouble(_weightKey, weight);
    await prefs.setString(_birthDateKey, birthDate.toIso8601String());
    await prefs.setBool(_isMetricKey, isMetric);
    
    if (workoutsPerWeek != null) {
      await prefs.setInt(_workoutsPerWeekKey, workoutsPerWeek);
    }
    
    if (weightGoal != null) {
      await prefs.setString(_weightGoalKey, weightGoal);
    }
    
    if (targetWeight != null) {
      await prefs.setDouble(_targetWeightKey, targetWeight);
    }
    
    if (gender != null) {
      await prefs.setString(_genderKey, gender);
    }
    
    if (motivationGoal != null) {
      await prefs.setString(_motivationGoalKey, motivationGoal);
    }
    
    if (dietType != null) {
      await prefs.setString(_dietTypeKey, dietType);
    }
    
    if (weightChangeSpeed != null) {
      await prefs.setDouble(_weightChangeSpeedKey, weightChangeSpeed);
    }

    if (name != null) {
      await prefs.setString(_nameKey, name);
    }
    
    await prefs.setBool(_hasCompletedOnboardingKey, true);
  }

  static Future<Map<String, dynamic>?> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_heightKey) || !prefs.containsKey(_weightKey) || !prefs.containsKey(_birthDateKey)) {
      return null;
    }
    
    final birthDateStr = prefs.getString(_birthDateKey);
    final birthDate = birthDateStr != null ? DateTime.parse(birthDateStr) : null;
    
    return {
      'height': prefs.getDouble(_heightKey),
      'weight': prefs.getDouble(_weightKey),
      'birthDate': birthDate,
      'isMetric': prefs.getBool(_isMetricKey) ?? true,
      'workoutsPerWeek': prefs.getInt(_workoutsPerWeekKey) ?? 3,
      'weightGoal': prefs.getString(_weightGoalKey) ?? 'maintain',
      'targetWeight': prefs.getDouble(_targetWeightKey),
      'gender': prefs.getString(_genderKey),
      'motivationGoal': prefs.getString(_motivationGoalKey),
      'dietType': prefs.getString(_dietTypeKey),
      'weightChangeSpeed': prefs.getDouble(_weightChangeSpeedKey),
      'name': prefs.getString(_nameKey) ?? 'User',
    };
  }

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  static Future<void> setHasCompletedOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, value);
  }

  static Future<void> clearUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_heightKey);
    await prefs.remove(_weightKey);
    await prefs.remove(_birthDateKey);
    await prefs.remove(_isMetricKey);
    await prefs.remove(_workoutsPerWeekKey);
    await prefs.remove(_weightGoalKey);
    await prefs.remove(_targetWeightKey);
    await prefs.remove(_hasCompletedOnboardingKey);
    await prefs.remove(_genderKey);
    await prefs.remove(_motivationGoalKey);
    await prefs.remove(_dietTypeKey);
    await prefs.remove(_weightChangeSpeedKey);
    await prefs.remove(_nameKey);
  }
} 