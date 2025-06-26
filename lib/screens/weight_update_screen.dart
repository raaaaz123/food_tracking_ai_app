import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import '../constants/app_colors.dart';
import '../models/user_details.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WeightUpdateScreen extends StatefulWidget {
  // Current user details required to update weight
  final UserDetails userDetails;

  // Callback function for when weight is updated
  final Function(double newWeight)? onWeightUpdated;

  const WeightUpdateScreen({
    Key? key,
    required this.userDetails,
    this.onWeightUpdated,
  }) : super(key: key);

  @override
  State<WeightUpdateScreen> createState() => _WeightUpdateScreenState();
}

class _WeightUpdateScreenState extends State<WeightUpdateScreen> {
  // Weight picker related variables
  late double _currentWeight;
  late int _selectedWeightWhole;
  late int _selectedWeightDecimal;
  bool _isLoading = false;
  bool _hasChanges = false;

  // Min/Max values for weight picker
  late int _minWeightValue;
  late int _maxWeightValue;

  @override
  void initState() {
    super.initState();
    
    // Initialize current weight from user details
    _currentWeight = widget.userDetails.weight;
    
    // Setup weight picker values
    _setupWeightRanges();
    _initializeWeightPickerValues();
  }

  void _setupWeightRanges() {
    final bool isMetric = widget.userDetails.isMetric;
    
    // Set reasonable min/max ranges based on measurement system
    if (isMetric) {
      // For kg: Allow 30kg to 250kg
      _minWeightValue = 30;
      _maxWeightValue = 250;
    } else {
      // For lbs: Allow 66lbs to 550lbs
      _minWeightValue = 66;
      _maxWeightValue = 550;
    }
  }

  void _initializeWeightPickerValues() {
    // Extract whole number part
    _selectedWeightWhole = _currentWeight.floor();
    
    // Extract decimal part (convert to whole number 0-9)
    _selectedWeightDecimal = ((_currentWeight - _selectedWeightWhole) * 10).round();
    
    // Ensure values are within valid ranges
    _selectedWeightWhole = _selectedWeightWhole.clamp(_minWeightValue, _maxWeightValue);
    _selectedWeightDecimal = _selectedWeightDecimal.clamp(0, 9);
  }

  void _updateWeightFromPickers() {
    setState(() {
      // Combine whole and decimal parts
      double newWeight = _selectedWeightWhole + (_selectedWeightDecimal / 10);
      
      // Check if weight has changed
      _hasChanges = (newWeight - _currentWeight).abs() > 0.01;
      
      // Update current weight
      _currentWeight = newWeight;
    });
  }

  // Format weight based on measurement system
  String _formatWeight(double weight) {
    return widget.userDetails.isMetric
        ? '${weight.toStringAsFixed(1)} kg'
        : '${weight.toStringAsFixed(1)} lbs';
  }

  // Save updated weight
  Future<void> _saveWeight() async {
    if (!_hasChanges) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated user details object
      final updatedDetails = UserDetails(
        height: widget.userDetails.height,
        weight: _currentWeight,
        birthDate: widget.userDetails.birthDate,
        isMetric: widget.userDetails.isMetric,
        workoutsPerWeek: widget.userDetails.workoutsPerWeek,
        weightGoal: widget.userDetails.weightGoal,
        targetWeight: widget.userDetails.targetWeight,
        gender: widget.userDetails.gender,
        motivationGoal: widget.userDetails.motivationGoal,
        dietType: widget.userDetails.dietType,
        weightChangeSpeed: widget.userDetails.weightChangeSpeed,
      );

      // Save to Hive
      final userBox = await Hive.openBox<UserDetails>('userDetails');
      await userBox.put('currentUser', updatedDetails);
      
      // Call callback if provided
      if (widget.onWeightUpdated != null) {
        widget.onWeightUpdated!(_currentWeight);
      }
      
      // Return to previous screen
      if (mounted) {
        Navigator.pop(context, _currentWeight);
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating weight: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildWeightPicker() {
    final bool isMetric = widget.userDetails.isMetric;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Whole number picker
        Expanded(
          flex: 2,
          child: NumberPicker(
            value: _selectedWeightWhole,
            minValue: _minWeightValue,
            maxValue: _maxWeightValue,
            step: 1,
            itemHeight: 60,
            selectedTextStyle: TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 20,
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
                _updateWeightFromPickers();
                HapticFeedback.selectionClick();
              });
            },
          ),
        ),
        
        // Decimal point
        Text(
          '.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        
        // Decimal picker
        Expanded(
          flex: 1,
          child: NumberPicker(
            value: _selectedWeightDecimal,
            minValue: 0,
            maxValue: 9,
            step: 1,
            itemHeight: 60,
            selectedTextStyle: TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 20,
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
                _selectedWeightDecimal = value;
                _updateWeightFromPickers();
                HapticFeedback.selectionClick();
              });
            },
          ),
        ),
        
        // Unit label
        SizedBox(width: 8),
        Text(
          isMetric ? 'kg' : 'lbs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final bool isSmallScreen = screenHeight < 700;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Update Weight',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 24),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'What is your current weight?',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Keeping your weight up to date helps us provide more accurate nutrition recommendations',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Date info
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Today, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Weight picker
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            size: 40,
                            color: AppColors.primary.withOpacity(0.8),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Select Your Current Weight',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 32),
                          _buildWeightPicker(),
                          SizedBox(height: 20),
                          Text(
                            _formatWeight(_currentWeight),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF182319),
                              leadingDistribution: TextLeadingDistribution.even,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Fixed save button at bottom
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _hasChanges ? _saveWeight : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save Weight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 