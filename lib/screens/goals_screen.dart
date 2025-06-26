import 'package:flutter/material.dart';
import 'workout_frequency_screen.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class Goal {
  final String title;
  final String id;
  final IconData icon;
  final String description;

  const Goal({
    required this.title,
    required this.id,
    required this.icon,
    required this.description,
  });
}

class GoalsScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;

  const GoalsScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
  });

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String? _selectedGoalId;
  final double _progressValue = 0.60; // 60% progress

  final List<Goal> _goals = const [
    Goal(
      title: 'Improve overall nutrition',
      id: 'nutrition',
      icon: Icons.restaurant_menu,
      description: 'Focus on balanced meals and better food choices for overall health',
    ),
    Goal(
      title: 'Increase fitness level',
      id: 'fitness',
      icon: Icons.fitness_center,
      description: 'Build strength and endurance through appropriate exercise plans',
    ),
    Goal(
      title: 'Boost energy and focus',
      id: 'energy',
      icon: Icons.bolt,
      description: 'Optimize diet and activity for improved daily energy levels',
    ),
    Goal(
      title: 'Better sleep quality',
      id: 'sleep',
      icon: Icons.nightlight_round,
      description: 'Adjust habits and nutrition to support improved sleep patterns',
    ),
    Goal(
      title: 'Manage stress levels',
      id: 'stress',
      icon: Icons.spa,
      description: 'Balance nutrition and activity to reduce stress and anxiety',
    ),
    Goal(
      title: 'Long-term health',
      id: 'longevity',
      icon: Icons.favorite_border,
      description: 'Focus on sustainable lifestyle changes for lasting wellness',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 600;
    
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
                            color: index < 5
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
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s your main health goal?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This helps us personalize your nutrition and workout plans.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Goal options
            Expanded(
              child: ListView.builder(
                itemCount: _goals.length,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (context, index) {
                  final goal = _goals[index];
                  final isSelected = _selectedGoalId == goal.id;

                  // Choose a unique color for each goal
                  Color iconColor;
                  switch (index) {
                    case 0:
                      iconColor = Colors.green.shade500;
                      break;
                    case 1:
                      iconColor = Colors.amber.shade500;
                      break;
                    case 2:
                      iconColor = AppColors.primary;
                      break;
                    case 3:
                      iconColor = Colors.orange;
                      break;
                    case 4:
                      iconColor = Colors.blue.shade500;
                      break;
                    case 5:
                      iconColor = Colors.purple.shade500;
                      break;
                    default:
                      iconColor = AppColors.primary;
                  }

                  return GestureDetector(
                    onTap: () {
                      // Add haptic feedback
                      HapticFeedback.selectionClick();
                      
                      setState(() {
                        _selectedGoalId = goal.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          else
                            BoxShadow(
                              color: AppColors.textPrimary.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  goal.icon,
                                  color: iconColor,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Padding(
                            padding: EdgeInsets.only(left: isSmallScreen ? 46 : 52),
                            child: Text(
                              goal.description,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedGoalId != null
                      ? () {
                          // Add haptic feedback
                          HapticFeedback.mediumImpact();
                          
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => WorkoutFrequencyScreen(
                                height: widget.height,
                                weight: widget.weight,
                                isMetric: widget.isMetric,
                                birthDate: widget.birthDate,
                                gender: widget.gender,
                                motivationGoal: _selectedGoalId!,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
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
