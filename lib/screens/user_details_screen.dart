import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:numberpicker/numberpicker.dart';
import '../constants/app_colors.dart';
import 'dob_screen.dart';
import 'reviews_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final double? initialHeight;
  final double? initialWeight;
  final bool? initialIsMetric;

  const UserDetailsScreen({
    super.key,
    this.initialHeight,
    this.initialWeight,
    this.initialIsMetric,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late bool _isMetric;
  late int _selectedHeightWhole;
  late int _selectedHeightFraction = 0;
  late int _selectedWeightWhole;
  late int _selectedWeightFraction = 0;
  final double _progressValue = 0.66; // 66% progress
  bool _hasChanges = false;

  // Height min/max values based on units
  int get _heightMinWhole => _isMetric ? 120 : 4;
  int get _heightMaxWhole => _isMetric ? 240 : 8;
  int get _heightMinFraction => 0;
  int get _heightMaxFraction => _isMetric ? 9 : 11;
  
  // Weight min/max values based on units
  int get _weightMinWhole => _isMetric ? 30 : 66;
  int get _weightMaxWhole => _isMetric ? 180 : 396;
  int get _weightMinFraction => 0;
  int get _weightMaxFraction => 9;

  @override
  void initState() {
    super.initState();
    _isMetric = widget.initialIsMetric ?? true;
    
    // Initialize with safe defaults first
    _selectedHeightWhole = _isMetric ? 170 : 5;
    _selectedWeightWhole = _isMetric ? 70 : 155;
    
    // Then set from parameters if available
    _initializeFromParams();
    
       Posthog().screen(
      screenName: 'User Details',
    );
  }
  
  void _initializeFromParams() {
    // Set values from parameters if available
    if (widget.initialHeight != null) {
      if (_isMetric) {
        _selectedHeightWhole = widget.initialHeight!.toInt();
        _selectedHeightFraction = ((widget.initialHeight! - _selectedHeightWhole) * 10).round().clamp(0, 9);
    } else {
        _selectedHeightWhole = (widget.initialHeight! / 12).floor().clamp(_heightMinWhole, _heightMaxWhole);
        _selectedHeightFraction = (widget.initialHeight! % 12).round().clamp(_heightMinFraction, _heightMaxFraction);
      }
    }
    
    if (widget.initialWeight != null) {
      if (_isMetric) {
        _selectedWeightWhole = widget.initialWeight!.toInt().clamp(_weightMinWhole, _weightMaxWhole);
        _selectedWeightFraction = ((widget.initialWeight! - _selectedWeightWhole) * 10).round().clamp(0, 9);
      } else {
        _selectedWeightWhole = widget.initialWeight!.toInt().clamp(_weightMinWhole, _weightMaxWhole);
        _selectedWeightFraction = ((widget.initialWeight! - _selectedWeightWhole) * 10).round().clamp(0, 9);
      }
    }
  }

  double get _currentHeight {
    if (_isMetric) {
      return _selectedHeightWhole.toDouble();
    } else {
      return (_selectedHeightWhole * 12).toDouble() + _selectedHeightFraction.toDouble();
    }
  }

  double get _currentWeight {
    return _selectedWeightWhole.toDouble();
  }

  String _formatHeightValue() {
    if (_isMetric) {
      return '$_selectedHeightWhole cm';
    } else {
      return '$_selectedHeightWhole\' $_selectedHeightFraction"';
    }
  }

  String _formatWeightValue() {
    if (_isMetric) {
      return '$_selectedWeightWhole kg';
    } else {
      return '$_selectedWeightWhole lbs';
    }
  }

  void _convertHeight(bool toMetric) {
    setState(() {
      try {
        if (toMetric) {
          // Convert from feet/inches to cm
          final totalInches = (_selectedHeightWhole * 12) + _selectedHeightFraction;
          final totalCm = totalInches * 2.54;
          _selectedHeightWhole = totalCm.toInt().clamp(_heightMinWhole, _heightMaxWhole);
          _selectedHeightFraction = ((totalCm - _selectedHeightWhole) * 10).round().clamp(0, 9);
        } else {
          // Convert from cm to feet/inches
          final totalCm = _selectedHeightWhole + (_selectedHeightFraction / 10);
          final totalInches = totalCm / 2.54;
          _selectedHeightWhole = (totalInches / 12).floor().clamp(_heightMinWhole, _heightMaxWhole);
          _selectedHeightFraction = (totalInches % 12).round().clamp(0, 11);
        }
      } catch (e) {
        // Fallback to safe defaults if conversion fails
        if (toMetric) {
          _selectedHeightWhole = 170;
          _selectedHeightFraction = 0;
        } else {
          _selectedHeightWhole = 5;
          _selectedHeightFraction = 9;
        }
      }
      _hasChanges = true;
    });
  }

  void _convertWeight(bool toMetric) {
    setState(() {
      try {
        final currentWeight = _selectedWeightWhole + (_selectedWeightFraction / 10);
        if (toMetric) {
          // Convert from lbs to kg
          final weightInKg = currentWeight * 0.453592;
          _selectedWeightWhole = weightInKg.floor().clamp(_weightMinWhole, _weightMaxWhole);
          _selectedWeightFraction = ((weightInKg - _selectedWeightWhole) * 10).round().clamp(0, 9);
        } else {
          // Convert from kg to lbs
          final weightInLbs = currentWeight / 0.453592;
          _selectedWeightWhole = weightInLbs.floor().clamp(_weightMinWhole, _weightMaxWhole);
          _selectedWeightFraction = ((weightInLbs - _selectedWeightWhole) * 10).round().clamp(0, 9);
        }
      } catch (e) {
        // Fallback to safe defaults if conversion fails
        if (toMetric) {
          _selectedWeightWhole = 70;
          _selectedWeightFraction = 0;
        } else {
          _selectedWeightWhole = 155;
          _selectedWeightFraction = 0;
        }
      }
      _hasChanges = true;
    });
  }

  // Helper method to get formatted value based on label
  String _getFormattedValue(String label) {
    if (label == 'Weight') {
      return _formatWeightValue();
    } else if (label == 'Height') {
      return _formatHeightValue();
    }
    return '';
  }

  Widget _buildNumberPicker({
    required String label,
    required Widget pickerWidget,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: pickerWidget,
          ),
          const SizedBox(height: 12),
          Text(
            _getFormattedValue(label),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeightPicker() {
    // Safe values for NumberPicker to prevent assertion error
    final safeHeightWhole = _selectedHeightWhole.clamp(_heightMinWhole, _heightMaxWhole);
    final safeHeightFraction = _selectedHeightFraction.clamp(_heightMinFraction, _heightMaxFraction);
    
    if (_isMetric) {
      // Metric height picker (cm)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Whole number
          Expanded(
            flex: 3,
            child: NumberPicker(
              value: safeHeightWhole,
              minValue: _heightMinWhole,
              maxValue: _heightMaxWhole,
              step: 1,
              itemHeight: 48,
              selectedTextStyle: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
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
                  _selectedHeightWhole = value;
                  _hasChanges = true;
                  HapticFeedback.selectionClick();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'cm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    } else {
      // Imperial height picker (feet, inches)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feet
          Expanded(
            flex: 2,
            child: NumberPicker(
              value: safeHeightWhole,
              minValue: _heightMinWhole,
              maxValue: _heightMaxWhole,
              step: 1,
              itemHeight: 48,
              selectedTextStyle: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
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
                  _selectedHeightWhole = value;
                  _hasChanges = true;
                  HapticFeedback.selectionClick();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text(
              'ft',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Inches
          Expanded(
            flex: 2,
            child: NumberPicker(
              value: safeHeightFraction,
              minValue: _heightMinFraction,
              maxValue: _heightMaxFraction,
              step: 1,
              itemHeight: 48,
              infiniteLoop: true,
              selectedTextStyle: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
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
                  _selectedHeightFraction = value;
                  _hasChanges = true;
                  HapticFeedback.selectionClick();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'in',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildWeightPicker() {
    // Safe values for NumberPicker to prevent assertion error
    final safeWeightWhole = _selectedWeightWhole.clamp(_weightMinWhole, _weightMaxWhole);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Whole number
        Expanded(
          flex: 4,
          child: NumberPicker(
            value: safeWeightWhole,
            minValue: _weightMinWhole,
            maxValue: _weightMaxWhole,
            step: 1,
            itemHeight: 48,
            selectedTextStyle: TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
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
                _hasChanges = true;
                HapticFeedback.selectionClick();
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            _isMetric ? 'kg' : 'lbs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  bool get _isValid => true; // Always valid with the new implementation

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ReviewsScreen()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
         Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: List.generate(12, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: index < 2
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            const SizedBox(height: 24),
            // Title and description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s your height and weight?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This helps us create your personalized plan.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Metric/Imperial toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Imperial',
                      style: TextStyle(
                        color: !_isMetric ? AppColors.primary : AppColors.textSecondary,
                        fontWeight:
                            !_isMetric ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isMetric,
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                      inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
                      inactiveThumbColor: AppColors.textSecondary,
                      onChanged: (value) {
                        if (value != _isMetric) {
                          _convertHeight(value);
                          _convertWeight(value);
                        setState(() {
                            _isMetric = value;
                          });
                          }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Metric',
                      style: TextStyle(
                        color: _isMetric ? AppColors.primary : AppColors.textSecondary,
                        fontWeight:
                            _isMetric ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Weight and Height pickers - Side by Side
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weight (Left)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: _buildNumberPicker(
                            label: 'Weight',
                            pickerWidget: _buildWeightPicker(),
                          ),
                        ),
                      ),
                      // Height (Right)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          child: _buildNumberPicker(
                            label: 'Height',
                            pickerWidget: _buildHeightPicker(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Continue button
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.cardBackground,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                          // Return the updated values if we're editing
                          if (widget.initialHeight != null ||
                              widget.initialWeight != null) {
                            Navigator.pop(context, {
                        'height': _currentHeight,
                        'weight': _currentWeight,
                              'isMetric': _isMetric,
                            });
                          } else {
                            // Continue to the next screen
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DOBScreen(
                            height: _currentHeight,
                            weight: _currentWeight,
                                  isMetric: _isMetric,
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  child: Text(
                    widget.initialHeight != null ? 'Save' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
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
