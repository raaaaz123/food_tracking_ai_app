import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'gain_speed_screen.dart';
import 'weight_goal_screen.dart';

class Diet {
  final String name;
  final String id;
  final IconData icon;

  const Diet({
    required this.name,
    required this.id,
    required this.icon,
  });
}

class DietScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;
  final String motivationGoal;
  final int workoutsPerWeek;
  final String weightGoal;

  const DietScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
    required this.motivationGoal,
    required this.workoutsPerWeek,
    required this.weightGoal,
  });

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  String? _selectedDiet;
  final double _progressValue = 0.80; // 80% progress

  final List<Diet> _diets = const [
    Diet(name: 'Classic', id: 'classic', icon: Icons.restaurant),
    Diet(name: 'Pescatarian', id: 'pescatarian', icon: Icons.set_meal),
    Diet(name: 'Vegetarian', id: 'vegetarian', icon: Icons.apple),
    Diet(name: 'Vegan', id: 'vegan', icon: Icons.spa),
  ];

  // Diet-specific accent colors - using AppColors for base styling
  final Map<String, Color> _dietAccentColors = {
    'classic': AppColors.primary.withBlue(220),
    'pescatarian': AppColors.primary.withBlue(240),
    'vegetarian': AppColors.primary.withGreen(180),
    'vegan': AppColors.primary.withGreen(200),
  };

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
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
                            color: index < 8
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
                    'Do you follow a specific diet?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'ll customize your nutrition plan based on your preferences.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Diet options
            Expanded(
              child: ListView.builder(
                itemCount: _diets.length,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (context, index) {
                  final diet = _diets[index];
                  final isSelected = _selectedDiet == diet.id;
                  final dietColor = isSelected ? AppColors.primary : _dietAccentColors[diet.id] ?? AppColors.primary;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDiet = diet.id;
                      });
                      HapticFeedback.selectionClick();
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
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                            decoration: BoxDecoration(
                              color: dietColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              diet.icon,
                              color: dietColor,
                              size: isSmallScreen ? 20 : 24,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diet.name,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (diet.id == 'classic')
                                  Text(
                                    'Regular diet with all food groups',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else if (diet.id == 'pescatarian')
                                  Text(
                                    'Fish, no meat or poultry',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else if (diet.id == 'vegetarian')
                                  Text(
                                    'No meat, fish or poultry',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else if (diet.id == 'vegan')
                                  Text(
                                    'No animal products',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
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
                    ),
                  );
                },
              ),
            ),
            // Next button
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedDiet != null
                      ? () {
                        HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => WeightGoalScreen(
                                height: widget.height,
                                weight: widget.weight,
                                isMetric: widget.isMetric,
                                birthDate: widget.birthDate,
                                gender: widget.gender,
                                motivationGoal: widget.motivationGoal,
                                workoutsPerWeek: widget.workoutsPerWeek,
                                dietType: _selectedDiet!,
                                weightChangeSpeed: 0.1, // Default value
                                isUpdate: false,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 16,
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
