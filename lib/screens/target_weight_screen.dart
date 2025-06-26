import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/preferences_service.dart';
import '../services/nutrition_service.dart';
import '../services/storage_service.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';
import '../screens/main_app_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_details.dart';
import '../models/user_metrics_history.dart';
import 'nutrition_loading_screen.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import '../screens/projected_timeline_screen.dart';

class TargetWeightScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final int workoutsPerWeek;
  final String weightGoal;
  final String gender;
  final String motivationGoal;
  final String dietType;
  final double weightChangeSpeed;
  final double? initialTargetWeight;
  final bool isUpdate;

  const TargetWeightScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.workoutsPerWeek,
    required this.weightGoal,
    required this.gender,
    required this.motivationGoal,
    required this.dietType,
    required this.weightChangeSpeed,
    this.initialTargetWeight,
    this.isUpdate = false,
  });

  @override
  State<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends State<TargetWeightScreen> {
  late double _targetWeight;
  final double _progressValue = 1.0; // 100% progress
  bool _isLoading = false;
  bool _hasChanges = false;
  
  // Number picker variables
  late int _selectedWeightWhole;
  late int _weightMinWhole;
  late int _weightMaxWhole;

  @override
  void initState() {
    Posthog().screen(
      screenName: 'Target Screen',
    );
    super.initState();

    // Set initial target weight from parameter if provided
    if (widget.initialTargetWeight != null) {
      _targetWeight = widget.initialTargetWeight!;
    } else {
      // Otherwise calculate based on current weight and goal
      _targetWeight = widget.weight.round().toDouble();

      // Adjust default target based on goal
      if (widget.weightGoal == 'gain') {
        _targetWeight += 5; // Add 5 kg/lbs for gain goal
      } else if (widget.weightGoal == 'lose') {
        _targetWeight -= 5; // Subtract 5 kg/lbs for lose goal
      }
    }
    
    // Initialize number picker variables
    _setupWeightRanges();
    _initializeNumberPickerValues();
  }

  void _setupWeightRanges() {
    if (widget.weightGoal == 'lose') {
      // For weight loss, allow down to 50% of current weight or 30kg/66lbs minimum
      _weightMinWhole = widget.isMetric 
          ? (widget.weight * 0.5).round().clamp(30, widget.weight.round() - 1)
          : (widget.weight * 0.5).round().clamp(66, widget.weight.round() - 1);
      
      // Set max to current weight for weight loss
      _weightMaxWhole = widget.weight.round();
    } else if (widget.weightGoal == 'gain') {
      // For weight gain, set min to current weight
      _weightMinWhole = widget.weight.round();
      
      // Allow up to 150% of current weight
      _weightMaxWhole = (widget.weight * 1.5).round();
    } else {
      // For maintenance, allow small range around current weight
      _weightMinWhole = (widget.weight * 0.9).round();
      _weightMaxWhole = (widget.weight * 1.1).round();
    }
  }

  void _initializeNumberPickerValues() {
    // Set whole number value
    _selectedWeightWhole = _targetWeight.round();
    
    // Ensure it's within valid range
    _selectedWeightWhole = _selectedWeightWhole.clamp(_weightMinWhole, _weightMaxWhole);
  }

  // Calculate min and max values for display purposes
  double get _minWeight => _weightMinWhole.toDouble();
  double get _maxWeight => _weightMaxWhole.toDouble();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure target weight is within bounds after all parameters are set
    _targetWeight = _targetWeight.clamp(_minWeight, _maxWeight);
    _updateNumberPickerFromTargetWeight();
  }
  
  void _updateNumberPickerFromTargetWeight() {
    _selectedWeightWhole = _targetWeight.round();
    _selectedWeightWhole = _selectedWeightWhole.clamp(_weightMinWhole, _weightMaxWhole);
  }
  
  void _updateTargetWeightFromPicker() {
    setState(() {
      _targetWeight = _selectedWeightWhole.toDouble();
      _hasChanges = widget.isUpdate &&
          widget.initialTargetWeight != null &&
          (widget.initialTargetWeight! - _targetWeight).abs() > 0.1;
    });
  }

  String _formatWeight(double value) {
    return widget.isMetric
        ? '${value.round()} kg'
        : '${value.round()} lbs';
  }

  void _handleContinue() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
    });

    // If we're in update mode, just return the target weight
    if (widget.isUpdate) {
      Navigator.pop(context, _targetWeight);
      return;
    }

    // Save starting metrics if this is not an update
    _saveStartingMetrics();

    // Create user details object to pass to loading screen
    final userDetails = UserDetails(
      height: widget.height,
      weight: widget.weight,
      birthDate: widget.birthDate,
      isMetric: widget.isMetric,
      workoutsPerWeek: widget.workoutsPerWeek,
      weightGoal: widget.weightGoal,
      targetWeight: _targetWeight,
      gender: widget.gender,
      motivationGoal: widget.motivationGoal,
      dietType: widget.dietType,
      weightChangeSpeed: widget.weightChangeSpeed,
    );

    // Navigate to the ProjectedTimelineScreen first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectedTimelineScreen(
          userDetails: userDetails,
        ),
      ),
    );
  }
  
  // Save the user's starting weight and height permanently
  Future<void> _saveStartingMetrics() async {
    try {
      final hasStartingMetrics = await StorageService.hasStartingMetrics();
      
      // Only save if no starting metrics exist yet
      if (!hasStartingMetrics) {
        final startingMetrics = UserMetricsHistory(
          startingWeight: widget.weight,
          startingHeight: widget.height,
          isMetric: widget.isMetric,
          startDate: DateTime.now(),
        );
        
        await StorageService.saveStartingMetrics(startingMetrics);
      }
    } catch (e) {
      // Just log the error but continue with the flow
      print('Error saving starting metrics: $e');
    }
  }
  
  Widget _buildWeightPicker() {
    // Safe value for NumberPicker to prevent assertion error
    final safeWeightWhole = _selectedWeightWhole.clamp(_weightMinWhole, _weightMaxWhole);
    
    // Get screen dimensions for responsive sizing
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 600;
    final bool isVerySmallScreen = screenHeight < 500;
    
    // Adjust item height based on screen size
    final itemHeight = isVerySmallScreen ? 40.0 : (isSmallScreen ? 44.0 : 48.0);
    final fontSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);
    final textFontSize = isVerySmallScreen ? 16.0 : (isSmallScreen ? 17.0 : 18.0);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Whole number picker
        Expanded(
          child: NumberPicker(
            value: safeWeightWhole,
            minValue: _weightMinWhole,
            maxValue: _weightMaxWhole,
            step: 1,
            itemHeight: itemHeight,
            itemWidth: isVerySmallScreen ? 60.0 : 80.0,
            selectedTextStyle: TextStyle(
              color: AppColors.primary,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
            textStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: textFontSize,
            ),
            haptics: true,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selectedWeightWhole = value;
                _updateTargetWeightFromPicker();
                HapticFeedback.selectionClick();
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            widget.isMetric ? 'kg' : 'lbs',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildNumberPicker({
    required String label, 
    required Widget pickerWidget, 
    bool isSmallScreen = false, 
    bool isVerySmallScreen = false
  }) {
    return Container(
      padding: EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 18),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          pickerWidget,
          SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          Text(
            _formatWeight(_targetWeight),
            style: TextStyle(
              fontSize: isVerySmallScreen ? 20 : (isSmallScreen ? 21 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 600;
    final bool isVerySmallScreen = screenHeight < 500;
    
    // Adjust paddings and spacings based on screen size
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 24.0);
    final titleFontSize = isVerySmallScreen ? 22.0 : (isSmallScreen ? 26.0 : 32.0);
    final subtitleFontSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);

    // Text to display based on weight goal
    final String goalText = widget.weightGoal == 'gain'
        ? 'Gain Weight'
        : (widget.weightGoal == 'lose' ? 'Lose Weight' : 'Maintain');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress indicator
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0, 
                        vertical: isVerySmallScreen ? 8.0 : 16.0
                      ),
                      child: Row(
                        children: List.generate(12, (index) {
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: index < 11
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 12 : verticalSpacing),
                    
                    // Title and description
                    Text(
                      'Choose your desired weight',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
                    Text(
                      'This will help us set your daily calorie target.',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 16 : 24)),

                    // Goal text
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04, 
                          vertical: isVerySmallScreen ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          goalText,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 32)),
                    
                    // Weight Picker
                    _buildNumberPicker(
                      label: 'Target Weight',
                      pickerWidget: _buildWeightPicker(),
                      isSmallScreen: isSmallScreen,
                      isVerySmallScreen: isVerySmallScreen,
                    ),
                    SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24)),
                    
                    // Range information
                    Center(
                      child: Text(
                        'Range: ${_formatWeight(_minWeight)} - ${_formatWeight(_maxWeight)}',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 11 : (isSmallScreen ? 12 : 14), 
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    
                    // Bottom padding to ensure content doesn't get hidden behind button
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // Static Next button at bottom
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isVerySmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (widget.isUpdate && !_hasChanges)
                      ? null
                      : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 14,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
                          height: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: isVerySmallScreen ? 1.5 : (isSmallScreen ? 1.5 : 2),
                          ),
                        )
                      : Text(
                          widget.isUpdate ? 'Save' : 'Continue',
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
