import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'target_weight_screen.dart';
import '../constants/app_colors.dart';
import 'weight_goal_screen.dart';

class GainSpeedScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;
  final String motivationGoal;
  final int workoutsPerWeek;
  final String dietType;
  final String weightGoal;

  const GainSpeedScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
    required this.motivationGoal,
    required this.workoutsPerWeek,
    required this.dietType,
    required this.weightGoal,
  });

  @override
  State<GainSpeedScreen> createState() => _GainSpeedScreenState();
}

class _GainSpeedScreenState extends State<GainSpeedScreen> {
  double _selectedSpeed = 0.25; // Default to slow
  final double _progressValue = 0.85; // 85% progress

  final Map<String, List<Map<String, dynamic>>> _speedOptions = {
    'lose': [
      {
        'value': 0.25,
        'label': '0.25 kg',
        'description': 'Slow and Steady',
        'icon': '🦥'
      },
      {'value': 0.5, 'label': '0.5 kg', 'description': 'Moderate', 'icon': '🏃'},
      {'value': 1.0, 'label': '1.0 kg', 'description': 'Fast', 'icon': '🏎️'},
    ],
    'gain': [
      {
        'value': 0.25,
        'label': '0.25 kg',
        'description': 'Slow and Steady',
        'icon': '🦥'
      },
      {'value': 0.5, 'label': '0.5 kg', 'description': 'Moderate', 'icon': '🏃'},
      {'value': 0.75, 'label': '0.75 kg', 'description': 'Fast', 'icon': '🏎️'},
    ],
    'maintain': [
      {
        'value': 0.0,
        'label': '0.0 kg',
        'description': 'Maintenance',
        'icon': '⚖️'
      },
    ]
  };

  List<Map<String, dynamic>> get _speeds => _speedOptions[widget.weightGoal] ?? _speedOptions['gain']!;

  String get _screenTitle {
    switch (widget.weightGoal) {
      case 'lose':
        return 'How fast do you want to lose weight?';
      case 'gain':
        return 'How fast do you want to gain weight?';
      case 'maintain':
        return 'Your weight maintenance speed';
      default:
        return 'How fast do you want to reach your goal?';
    }
  }

  String get _speedLabel {
    switch (widget.weightGoal) {
      case 'lose':
        return 'Weight loss speed per week';
      case 'gain':
        return 'Weight gain speed per week';
      case 'maintain':
        return 'Weight maintenance';
      default:
        return 'Change speed per week';
    }
  }

  @override
  void initState() {
    super.initState();
    // Set default speed based on weight goal
    if (widget.weightGoal == 'maintain') {
      _selectedSpeed = 0.0;
    } else {
      // For lose or gain, set to the first option in the appropriate list
      final options = _speedOptions[widget.weightGoal] ?? _speedOptions['gain']!;
      if (options.isNotEmpty) {
        _selectedSpeed = options.first['value'];
      }
    }
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
    final labelFontSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);
    final valueFontSize = isVerySmallScreen ? 28.0 : (isSmallScreen ? 36.0 : 42.0);
    final emojiSize = isVerySmallScreen ? 24.0 : (isSmallScreen ? 32.0 : 40.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                                color: index < 10
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
                    
                    // Title
                    Text(
                      _screenTitle,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 20 : (isSmallScreen ? 30 : 60)),
                    
                    // Current selection display
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _speedLabel,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 10)),
                          Text(
                            '$_selectedSpeed kg',
                            style: TextStyle(
                              fontSize: valueFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 20 : (isSmallScreen ? 30 : 60)),
                    
                    // Speed options
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _speeds.map((speed) {
                          final isSelected = _selectedSpeed == speed['value'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSpeed = speed['value'];
                              });
                              // Add haptic feedback
                              HapticFeedback.selectionClick();
                            },
                            child: Column(
                              children: [
                                Text(
                                  speed['icon'],
                                  style: TextStyle(fontSize: emojiSize),
                                ),
                                SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 20)),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
                                  height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        isSelected ? AppColors.primary : Colors.transparent,
                                    border: Border.all(
                                      color:
                                          isSelected ? AppColors.primary : AppColors.textSecondary,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 10)),
                                Text(
                                  speed['label'],
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 30)),
                    
                    // Description
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05, 
                          vertical: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _speeds.firstWhere(
                              (s) => s['value'] == _selectedSpeed)['description'],
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
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
                color: Colors.white,
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
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TargetWeightScreen(
                          height: widget.height,
                          weight: widget.weight,
                          isMetric: widget.isMetric,
                          birthDate: widget.birthDate,
                          workoutsPerWeek: widget.workoutsPerWeek,
                          gender: widget.gender,
                          motivationGoal: widget.motivationGoal,
                          weightChangeSpeed: _selectedSpeed,
                          dietType: widget.dietType,
                          weightGoal: widget.weightGoal,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 14,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Next',
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
