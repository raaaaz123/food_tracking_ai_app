import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'target_weight_screen.dart';
import 'gain_speed_screen.dart';

class WeightGoalScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;
  final String motivationGoal;
  final int workoutsPerWeek;
  final double weightChangeSpeed;
  final String dietType;
  final String? initialGoalId;
  final bool isUpdate;

  const WeightGoalScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
    required this.motivationGoal,
    required this.workoutsPerWeek,
    required this.weightChangeSpeed,
    required this.dietType,
    this.initialGoalId,
    this.isUpdate = false,
  });

  @override
  State<WeightGoalScreen> createState() => _WeightGoalScreenState();
}

class _WeightGoalScreenState extends State<WeightGoalScreen> with SingleTickerProviderStateMixin {
  String _selectedGoal = 'lose';
  late AnimationController _animationController;
  
  final Map<String, Map<String, dynamic>> _weightGoals = {
    'lose': {
      'title': 'Lose Weight',
      'icon': '🔥',
      'description': 'Reduce body fat while preserving lean muscle'
    },
    'maintain': {
      'title': 'Maintain Weight',
      'icon': '⚖️',
      'description': 'Keep your current weight while improving body composition'
    },
    'gain': {
      'title': 'Gain Weight',
      'icon': '💪',
      'description': 'Build muscle mass and strength'
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Set initial goal based on initialGoalId if available
    if (widget.initialGoalId != null) {
      _selectedGoal = widget.initialGoalId!;
    }
    // Otherwise set based on motivation if possible
    else if (widget.motivationGoal.toLowerCase().contains('muscle') || 
        widget.motivationGoal.toLowerCase().contains('strength')) {
      _selectedGoal = 'gain';
    } else if (widget.motivationGoal.toLowerCase().contains('lose') ||
               widget.motivationGoal.toLowerCase().contains('weight') ||
               widget.motivationGoal.toLowerCase().contains('fat')) {
      _selectedGoal = 'lose';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    HapticFeedback.mediumImpact();
    if (widget.isUpdate) {
      Navigator.pop(context, _selectedGoal);
      return;
    }
    
    // Navigate to appropriate speed screen based on the weight goal
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GainSpeedScreen(
          height: widget.height,
          weight: widget.weight,
          isMetric: widget.isMetric,
          birthDate: widget.birthDate,
          gender: widget.gender,
          motivationGoal: widget.motivationGoal,
          workoutsPerWeek: widget.workoutsPerWeek,
          dietType: widget.dietType,
          weightGoal: _selectedGoal, // Pass the selected weight goal
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 700;
    final bool isLargeScreen = screenHeight > 800;
    
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
      // Use a Column with Expanded content + fixed bottom button
      body: Column(
        children: [
          // Main Content - Scrollable
          Expanded(
            child: SafeArea(
              bottom: false, // Since we have our own bottom button
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress indicator - Segment style
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: List.generate(12, (index) {
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: index < 9
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          
                          // Title with more modern spacing
                          const SizedBox(height: 12),
                          Text(
                            'What is your weight goal?',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 24 : 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Description with improved styling
                          Text(
                            'Choose the option that best aligns with your fitness objectives.',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Goal options - Improved styling
                          ..._buildGoalOptions(isSmallScreen, isLargeScreen),
                          
                          // Add extra space at bottom for scrolling
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Fixed bottom button - NEVER SCROLLS
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _navigateToNextScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Continue',
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
  
  List<Widget> _buildGoalOptions(bool isSmallScreen, bool isLargeScreen) {
    return _weightGoals.entries.map((entry) {
      final String key = entry.key;
      final Map<String, dynamic> goal = entry.value;
      final bool isSelected = _selectedGoal == key;
      
      // Calculate responsive sizes
      final double iconSize = isSmallScreen ? 44 : (isLargeScreen ? 60 : 52);
      final double emojiSize = isSmallScreen ? 28 : (isLargeScreen ? 36 : 32);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedGoal = key;
            });
            // Add haptic feedback
            HapticFeedback.selectionClick();
            _animationController.reset();
            _animationController.forward();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary 
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      )
                    ],
            ),
            child: Row(
              children: [
                // Icon container with improved styling
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      goal['icon'],
                      style: TextStyle(fontSize: emojiSize),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text content with improved styling
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with check icon
                      Row(
                        children: [
                          Text(
                            goal['title'],
                            style: TextStyle(
                              fontSize: isSmallScreen ? 17 : 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Description with improved styling
                      Text(
                        goal['description'],
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}
