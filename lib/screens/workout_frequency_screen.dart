import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_permission_screen.dart';
import '../constants/app_colors.dart';

class WorkoutFrequencyScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;
  final String motivationGoal;

  const WorkoutFrequencyScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
    required this.motivationGoal,
  });

  @override
  State<WorkoutFrequencyScreen> createState() => _WorkoutFrequencyScreenState();
}

class _WorkoutFrequencyScreenState extends State<WorkoutFrequencyScreen> {
  int? _workoutsPerWeek;
  final double _progressValue = 0.70; // 70% progress

  // Simplified workout frequency options
  final List<Map<String, dynamic>> _frequencyOptions = [
    {'value': 0, 'label': 'Rarely/None', 'emoji': '🛌', 'description': 'Less than once a week'},
    {'value': 1, 'label': 'Light', 'emoji': '🚶', 'description': '1-2 times per week'},
    {'value': 3, 'label': 'Moderate', 'emoji': '🏋️', 'description': '3-4 times per week'},
    {'value': 5, 'label': 'Active', 'emoji': '🏃', 'description': '5+ times per week'}
  ];

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
                            color: index < 6
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
                    'How active are you?',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This helps us calculate your calorie needs.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Frequency selector - more adaptive
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ListView.separated(
                      itemCount: _frequencyOptions.length,
                      padding: EdgeInsets.only(top: 4, bottom: isSmallScreen ? 8 : 16),
                      separatorBuilder: (context, index) => SizedBox(height: isSmallScreen ? 10 : 12),
                      itemBuilder: (context, index) {
                        final option = _frequencyOptions[index];
                        final isSelected = _workoutsPerWeek == option['value'];
                        
                        // Calculate responsive spacing
                        final double verticalPadding = isSmallScreen ? 12 : 16;
                        final double horizontalPadding = constraints.maxWidth < 320 ? 12 : 16;
                        final double iconSize = isSmallScreen ? 34 : 40;
                        final double fontSize = isSmallScreen ? 15 : 16;
                        final double descFontSize = isSmallScreen ? 12 : 13;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _workoutsPerWeek = option['value'];
                            });
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding, 
                              vertical: verticalPadding
                            ),
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
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      option['emoji'],
                                      style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                                    ),
                                  ),
                                ),
                                SizedBox(width: constraints.maxWidth < 320 ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option['label'],
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 2 : 4),
                                      Text(
                                        option['description'],
                                        style: TextStyle(
                                          fontSize: descFontSize,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: isSmallScreen ? 14 : 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ),
            // Next button
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _workoutsPerWeek != null
                      ? () {
                        HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NotificationPermissionScreen(
                                height: widget.height,
                                weight: widget.weight,
                                isMetric: widget.isMetric,
                                birthDate: widget.birthDate,
                                workoutsPerWeek: _workoutsPerWeek!,
                                gender: widget.gender,
                                motivationGoal: widget.motivationGoal,
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
