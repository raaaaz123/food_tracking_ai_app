import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';

class NutritionCard extends StatelessWidget {
  final double calories;
  final double caloriesGoal;
  final double carbs;
  final double carbsGoal;
  final double protein;
  final double proteinGoal;
  final double fat;
  final double fatGoal;
  final double caloriesBurned;
  final Function()? onTap;
  final DateTime? selectedDate;
  final Function()? onPreviousDate;
  final Function()? onNextDate;
  final int streak;
  final Function()? onStreakTap;
  final bool isPremium;

  const NutritionCard({
    Key? key,
    required this.calories,
    required this.caloriesGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
    this.caloriesBurned = 0,
    this.onTap,
    this.selectedDate,
    this.onPreviousDate,
    this.onNextDate,
    this.streak = 0,
    this.onStreakTap,
    this.isPremium = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final netCalories = calories - caloriesBurned;
    final caloriesLeft = (caloriesGoal - netCalories).round();
    final DateTime date = selectedDate ?? DateTime.now();
    final bool isToday = _isToday(date);
    
    // Calculate percentage of calories consumed for the pie chart
    final double consumedPercentage = netCalories > 0 
        ? (netCalories / caloriesGoal).clamp(0.0, 1.0) 
        : 0.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8E0C0), // Light green from heart health image
              Color(0xFF7BC27D), // Medium green from heart health image
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Promotion button (SAVE 50%) - Only visible for non-premium users
                  if (!isPremium)
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => _showSpecialOfferDialog(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.fromARGB(255, 255, 60, 112), // Orange
                                    Color(0xFFFF5722), // Deep orange
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.local_offer,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'SAVE 50%',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(
                      flex: 1,
                      child: SizedBox(), // Empty space to balance the layout for premium users
                    ),
                  
                  // App Logo or Text - Centered
                  const Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'Dietly Ai',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Streak indicator button instead of account/notification icons
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: onStreakTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromARGB(255, 255, 103, 76), // Purple
                                Color.fromARGB(255, 240, 80, 136), // Deep purple
                              ],
                            ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Nutrition data section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left column (Eaten)
                  Column(
                    children: [
                      Text(
                        '${calories.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'EATEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Center column (Calories left) with pie chart
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pie chart to show consumed calories
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CustomPaint(
                          painter: CaloriesPieChartPainter(
                            consumedPercentage: consumedPercentage,
                            consumedColor: Colors.white,
                            remainingColor: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      
                      // KCAL LEFT text and number
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${caloriesLeft > 0 ? caloriesLeft : 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              'KCAL LEFT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Right column (Burned)
                  Column(
                    children: [
                      Text(
                        '${caloriesBurned.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'BURNED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Macronutrient details - More compact with proper spacing
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMacroColumn('Carbs', carbs, carbsGoal),
                      const VerticalDivider(
                        color: Colors.grey,
                        thickness: 0.5,
                        width: 20,
                      ),
                      _buildMacroColumn('Protein', protein, proteinGoal),
                      const VerticalDivider(
                        color: Colors.grey,
                        thickness: 0.5,
                        width: 20,
                      ),
                      _buildMacroColumn('Fat', fat, fatGoal),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Date navigation
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous date button
                      InkWell(
                        onTap: onPreviousDate,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chevron_left, color: AppColors.primary, size: 20),
                        ),
                      ),
                      
                      // Date display
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today, 
                                color: AppColors.primary, 
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isToday ? 'TODAY' : _getDayOfWeek(date),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatFullDate(date),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      
                      // Next date button - disabled if it's today
                      InkWell(
                        onTap: isToday ? null : onNextDate,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isToday 
                              ? Colors.grey.withOpacity(0.1) 
                              : AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right, 
                            color: isToday 
                              ? Colors.grey 
                              : AppColors.primary, 
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroColumn(String title, double value, double goal) {
    // Calculate net value (considering both consumed and burned values)
    double netValue = value;
    if (title == 'Carbs' && caloriesBurned > 0) {
      // Estimated carbs burned based on calories burned (rough estimate)
      netValue = math.max(0, value - (caloriesBurned * 0.15) / 4); // ~15% of burned calories come from carbs, 4 calories per gram
    } else if (title == 'Protein' && caloriesBurned > 0) {
      // Estimated protein burned based on calories burned (rough estimate)
      netValue = math.max(0, value - (caloriesBurned * 0.05) / 4); // ~5% of burned calories come from protein, 4 calories per gram
    } else if (title == 'Fat' && caloriesBurned > 0) {
      // Estimated fat burned based on calories burned (rough estimate)
      netValue = math.max(0, value - (caloriesBurned * 0.8) / 9); // ~80% of burned calories come from fat, 9 calories per gram
    }
    
    final progress = goal > 0 ? (netValue / goal).clamp(0.0, 1.0) : 0.0;
    
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (progress * 100).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: title == 'Carbs' 
                          ? Colors.orange 
                          : title == 'Protein' 
                              ? Colors.blue 
                              : Colors.green,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Expanded(
                  flex: 100 - (progress * 100).toInt(),
                  child: Container(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${netValue.toInt()}/${goal.toInt()}g',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthAbbr(date.month)}';
  }

  String _getMonthAbbr(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // Show the special 50% off promotion dialog
  void _showSpecialOfferDialog(BuildContext context) {
    showSpecialOfferDialog(
      context,
      feature: Feature.scanFood,
      title: '50% OFF',
      subtitle: 'You have been selected for this exclusive offer! Upgrade now and save 50% on your premium subscription.',
      forceShow: true,
    );
  }

  String _getDayOfWeek(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatFullDate(DateTime date) {
    return '${_formatDate(date)}, ${date.year}';
  }
}

// Custom painter for the pie chart
class CaloriesPieChartPainter extends CustomPainter {
  final double consumedPercentage;
  final Color consumedColor;
  final Color remainingColor;
  
  CaloriesPieChartPainter({
    required this.consumedPercentage,
    required this.consumedColor,
    required this.remainingColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 10.0;
    
    // Draw the remaining calories arc (background)
    final backgroundPaint = Paint()
      ..color = remainingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    
    // Draw the consumed calories arc
    if (consumedPercentage > 0) {
      final foregroundPaint = Paint()
        ..color = consumedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
      
      // Start at the top (270 degrees) and draw clockwise
      final startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * consumedPercentage;
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CaloriesPieChartPainter oldDelegate) {
    return oldDelegate.consumedPercentage != consumedPercentage ||
           oldDelegate.consumedColor != consumedColor ||
           oldDelegate.remainingColor != remainingColor;
  }
} 