import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/storage_service.dart';
import '../models/user_details.dart';
import '../models/user_metrics_history.dart';
import '../services/nutrition_service.dart';
import '../constants/app_colors.dart';
import 'user_details_screen.dart';
import 'dob_screen.dart';
import 'weight_goal_screen.dart';
import 'target_weight_screen.dart';
import 'package:intl/intl.dart';
import 'weight_update_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  Map<String, dynamic>? _userDetails;
  bool _isLoading = true;
  UserMetricsHistory? _startingMetrics;

  // Design constants
  Color get _primaryColor => AppColors.primary;
  Color get _accentColor => AppColors.error;
  Color get _backgroundColor => AppColors.background;
  Color get _cardColor => AppColors.cardBackground;
  Color get _textColor => AppColors.textPrimary;
  Color get _lightTextColor => AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStartingMetrics();
    Posthog().screen(
      screenName: 'Personal Details Screen',
    );
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userDetails = await StorageService.getUserDetails();

      setState(() {
        _userDetails = userDetails?.toMap();
        _isLoading = false;
      });
    } catch (e) {

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStartingMetrics() async {
    try {
      final metrics = await StorageService.getStartingMetrics();
      setState(() {
        _startingMetrics = metrics;
      });
    } catch (e) {
      print('Error loading starting metrics: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _navigateToHeightWeightScreen() async {
    if (_userDetails == null) return;
    HapticFeedback.lightImpact();
    
    // Convert userDetails map to UserDetails object for the WeightUpdateScreen
    final userDetailsObj = UserDetails(
      height: _userDetails!['height'] as double? ?? 170.0,
      weight: _userDetails!['weight'] as double? ?? 70.0,
      birthDate: _userDetails!['birthDate'] as DateTime? ?? DateTime.now(),
      isMetric: _userDetails!['isMetric'] as bool? ?? true,
      workoutsPerWeek: _userDetails!['workoutsPerWeek'] as int? ?? 3,
      weightGoal: _userDetails!['weightGoal'] as String? ?? 'maintain',
      targetWeight: _userDetails!['targetWeight'] as double? ?? 70.0,
      gender: _userDetails!['gender'] as String? ?? 'Other',
      motivationGoal: _userDetails!['motivationGoal'] as String? ?? 'healthier',
      dietType: _userDetails!['dietType'] as String? ?? 'classic',
      weightChangeSpeed: _userDetails!['weightChangeSpeed'] as double? ?? 0.1,
    );
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightUpdateScreen(
          userDetails: userDetailsObj,
        ),
      ),
    );
    
    if (result != null && result is double) {
      // Update weight in userDetails map
      final updatedDetails = Map<String, dynamic>.from(_userDetails!);
      updatedDetails['weight'] = result;
      
      // Save the updated details
      await _updateUserDetails(updatedDetails);
      
      // If no starting metrics exist yet, save these as starting metrics
      final hasStartingMetrics = await StorageService.hasStartingMetrics();
      if (!hasStartingMetrics) {
        final startingMetrics = UserMetricsHistory(
          startingWeight: result,
          startingHeight: updatedDetails['height'] as double? ?? 170.0,
          isMetric: updatedDetails['isMetric'] as bool? ?? true,
          startDate: DateTime.now(),
        );
        await StorageService.saveStartingMetrics(startingMetrics);
        await _loadStartingMetrics();
      }
    }
  }

  void _navigateToDOBScreen() async {
    if (_userDetails == null) return;
HapticFeedback.lightImpact();
    final birthDate = _userDetails!['birthDate'] as DateTime? ?? DateTime.now();
    final height = _userDetails!['height'] as double? ?? 170.0;
    final weight = _userDetails!['weight'] as double? ?? 70.0;
    final isMetric = _userDetails!['isMetric'] as bool? ?? true;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DOBScreen(
          height: height,
          weight: weight,
          isMetric: isMetric,
          initialBirthDate: birthDate,
          isUpdate: true,
        ),
      ),
    );

    if (result != null && result is DateTime) {
      final updatedDetails = Map<String, dynamic>.from(_userDetails!);
      updatedDetails['birthDate'] = result;

      await _updateUserDetails(updatedDetails);
    }
  }

  void _navigateToWeightGoalScreen() async {
    if (_userDetails == null) return;

    final height = _userDetails!['height'] as double? ?? 170.0;
    final weight = _userDetails!['weight'] as double? ?? 70.0;
    final isMetric = _userDetails!['isMetric'] as bool? ?? true;
    final birthDate = _userDetails!['birthDate'] as DateTime? ?? DateTime.now();
    final workoutsPerWeek = _userDetails!['workoutsPerWeek'] as int? ?? 3;
    final weightGoal = _userDetails!['weightGoal'] as String? ?? 'maintain';
    final gender = _userDetails!['gender'] as String? ?? 'Other';
    final motivationGoal =
        _userDetails!['motivationGoal'] as String? ?? 'healthier';
    final dietType = _userDetails!['dietType'] as String? ?? 'classic';
    final weightChangeSpeed =
        _userDetails!['weightChangeSpeed'] as double? ?? 0.1;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightGoalScreen(
          height: height,
          weight: weight,
          isMetric: isMetric,
          birthDate: birthDate,
          workoutsPerWeek: workoutsPerWeek,
          gender: gender,
          motivationGoal: motivationGoal,
          dietType: dietType,
          weightChangeSpeed: weightChangeSpeed,
        ),
      ),
    );

    if (result != null && result is String) {
      final updatedDetails = Map<String, dynamic>.from(_userDetails!);
      updatedDetails['weightGoal'] = result;

      await _updateUserDetails(updatedDetails);

      // After weight goal is updated, go to target weight screen
      _navigateToTargetWeightScreen();
    }
  }

  void _navigateToTargetWeightScreen() async {
    if (_userDetails == null) return;

    final height = _userDetails!['height'] as double? ?? 170.0;
    final weight = _userDetails!['weight'] as double? ?? 70.0;
    final isMetric = _userDetails!['isMetric'] as bool? ?? true;
    final birthDate = _userDetails!['birthDate'] as DateTime? ?? DateTime.now();
    final workoutsPerWeek = _userDetails!['workoutsPerWeek'] as int? ?? 3;
    final weightGoal = _userDetails!['weightGoal'] as String? ?? 'maintain';
    final targetWeight = _userDetails!['targetWeight'] as double? ?? weight;
    final gender = _userDetails!['gender'] as String? ?? 'Other';
    final motivationGoal =
        _userDetails!['motivationGoal'] as String? ?? 'healthier';
    final dietType = _userDetails!['dietType'] as String? ?? 'classic';
    final weightChangeSpeed =
        _userDetails!['weightChangeSpeed'] as double? ?? 0.1;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TargetWeightScreen(
          height: height,
          weight: weight,
          isMetric: isMetric,
          birthDate: birthDate,
          workoutsPerWeek: workoutsPerWeek,
          weightGoal: weightGoal,
          gender: gender,
          motivationGoal: motivationGoal,
          dietType: dietType,
          weightChangeSpeed: weightChangeSpeed,
          initialTargetWeight: targetWeight,
          isUpdate: true,
        ),
      ),
    );

    if (result != null && result is double) {
      final updatedDetails = Map<String, dynamic>.from(_userDetails!);
      updatedDetails['targetWeight'] = result;

      await _updateUserDetails(updatedDetails);
      await _recalculateNutrition(updatedDetails);
    }
  }

  Future<void> _updateUserDetails(Map<String, dynamic> updatedDetails) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await StorageService.saveUserDetails(
        UserDetails(
          height: updatedDetails['height'] as double? ?? 0.0,
          weight: updatedDetails['weight'] as double? ?? 0.0,
          birthDate: updatedDetails['birthDate'] as DateTime? ?? DateTime.now(),
          isMetric: updatedDetails['isMetric'] as bool? ?? true,
          workoutsPerWeek: updatedDetails['workoutsPerWeek'] as int? ?? 3,
          weightGoal: updatedDetails['weightGoal'] as String? ?? 'maintain',
          targetWeight: updatedDetails['targetWeight'] as double? ?? 0.0,
          gender: updatedDetails['gender'] as String? ?? 'Other',
          motivationGoal: updatedDetails['motivationGoal'] as String? ?? 'healthier',
          dietType: updatedDetails['dietType'] as String? ?? 'classic',
          weightChangeSpeed: updatedDetails['weightChangeSpeed'] as double? ?? 0.1,
        )
      );

      setState(() {
        _userDetails = updatedDetails;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Personal details updated'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating details: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _recalculateNutrition(Map<String, dynamic> details) async {
    try {
      final nutritionData = await NutritionService.calculateNutrition(
        height: details['height'] as double? ?? 0.0,
        weight: details['weight'] as double? ?? 0.0,
        birthDate: details['birthDate'] as DateTime? ?? DateTime.now(),
        isMetric: details['isMetric'] as bool? ?? true,
        workoutsPerWeek: details['workoutsPerWeek'] as int? ?? 3,
        weightGoal: details['weightGoal'] as String? ?? 'maintain',
        targetWeight: details['targetWeight'] as double? ?? 0.0,
        gender: details['gender'] as String?,
        motivationGoal: details['motivationGoal'] as String?,
        dietType: details['dietType'] as String?,
        weightChangeSpeed: details['weightChangeSpeed'] as double?,
      );

      // Convert to Map<String, int> for saveNutritionPlan
      final processedNutritionData = {
        'dailyCalories': (nutritionData['dailyCalories'] as num).toInt(),
        'protein': (nutritionData['protein'] as num).toInt(),
        'carbs': (nutritionData['carbs'] as num).toInt(),
        'fats': (nutritionData['fats'] as num).toInt(),
      };

      await NutritionService.saveNutritionPlan(processedNutritionData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nutrition plan updated'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating nutrition plan: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildDetailsItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: _lightTextColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartingMetricsCard() {
    if (_startingMetrics == null) {
      return const SizedBox.shrink();
    }

    final isMetric = _startingMetrics!.isMetric;
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'in';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Starting Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          
          // Starting date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: _primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Started on ${_formatDate(_startingMetrics!.startDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Divider(color: _lightTextColor.withOpacity(0.2)),
          const SizedBox(height: 8),
          
          // Weight and height information
          Row(
            children: [
              // Starting weight
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting Weight',
                      style: TextStyle(
                        fontSize: 14,
                        color: _lightTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_startingMetrics!.startingWeight.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            weightUnit,
                            style: TextStyle(
                              fontSize: 14,
                              color: _lightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Starting height
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting Height',
                      style: TextStyle(
                        fontSize: 14,
                        color: _lightTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_startingMetrics!.startingHeight.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            heightUnit,
                            style: TextStyle(
                              fontSize: 14,
                              color: _lightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Info text
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Starting stats are recorded when you first start tracking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _lightTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: _primaryColor,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your details...',
                style: TextStyle(
                  color: _lightTextColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final targetWeight = _userDetails?['targetWeight'] as double? ?? 0.0;
    final currentWeight = _userDetails?['weight'] as double? ?? 0.0;
    final height = _userDetails?['height'] as double? ?? 0.0;
    final dob = _userDetails?['birthDate'] as DateTime? ?? DateTime.now();
    final weightGoal = _userDetails?['weightGoal'] as String? ?? 'maintain';
    final isMetric = _userDetails?['isMetric'] as bool? ?? true;

    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'in';

    // Convert weight goal to readable text
    final weightGoalText = weightGoal == 'gain'
        ? 'Gain Weight'
        : (weightGoal == 'lose' ? 'Lose Weight' : 'Maintain');

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outlined,
                  color: AppColors.textLight, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Personal Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          await _loadUserData();
          await _loadStartingMetrics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _textColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Goal Weight',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _navigateToWeightGoalScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: AppColors.textLight,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Change Goal'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${targetWeight.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              weightUnit,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _lightTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          weightGoalText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _textColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailsItem(
                        label: 'Current Weight',
                        value:
                            '${currentWeight.toStringAsFixed(1)} $weightUnit',
                        onTap: _navigateToHeightWeightScreen,
                      ),
                      _buildDetailsItem(
                        label: 'Height',
                        value: '${height.toStringAsFixed(1)} $heightUnit',
                        onTap: _navigateToHeightWeightScreen,
                      ),
                      _buildDetailsItem(
                        label: 'Date of birth',
                        value: _formatDate(dob),
                        onTap: _navigateToDOBScreen,
                      ),
                    ],
                  ),
                ),
                _buildStartingMetricsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
