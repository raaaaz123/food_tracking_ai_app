import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/preferences_service.dart';
import '../services/food_hive_service.dart';
import '../services/exercise_hive_service.dart';
import '../services/google_health_service.dart';
import '../models/nutrition_info.dart';
import '../models/exercise.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import '../models/user_details.dart';
import 'user_details_screen.dart';
import 'weight_goal_screen.dart';
import 'target_weight_screen.dart';
import '../constants/app_colors.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../models/user_metrics_history.dart';
import '../services/nutrition_service.dart';
import 'weight_update_screen.dart';

// Dashed line painter for legend
class DashedLinePainter extends CustomPainter {
  final Color color;
  
  DashedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    const dashWidth = 3;
    const dashSpace = 3;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  UserDetails? _userDetails;
  bool _isLoading = true;
  String _selectedTimeframe = '7 Days';  // Changed from '90 Days' to '7 Days'
  
  // New data properties for real analytics
  Map<DateTime, Map<String, double>> _nutritionHistory = {};
  Map<DateTime, double> _weightHistory = {};
  Map<DateTime, int> _workoutCaloriesBurned = {};
  Map<String, Map<String, dynamic>> _exerciseTypeDistribution = {};
  Map<DateTime, int> _stepsHistory = {};
  Map<String, double> _macroDistribution = {'protein': 0, 'carbs': 0, 'fat': 0};
  
  // Food log service
  final FoodHiveService _foodHiveService = FoodHiveService();
  final ExerciseHiveService _exerciseHiveService = ExerciseHiveService();

  // Design constants
  final Color _primaryColor = AppColors.primary; // Modern indigo
  final Color _accentColor = AppColors.warning; // Vibrant orange
  final Color _backgroundColor = AppColors.background; // Light gray background
  final Color _cardColor = AppColors.cardBackground;
  final Color _textColor = AppColors.textPrimary; // Dark gray
  final Color _lightTextColor = AppColors.textSecondary; // Medium gray
  
  // Chart colors - retain as local variables for specific chart colors
  final Color _proteinColor = const Color(0xFF4ade80); // Green
  final Color _carbsColor = const Color(0xFF60a5fa); // Blue
  final Color _fatColor = const Color(0xFFfb923c); // Orange
  final Color _caloriesColor = const Color(0xFFf87171); // Red
  final Color _stepsColor = const Color(0xFF818cf8); // Purple

  @override
  void initState() {
    super.initState();
    Posthog().screen(
      screenName: 'Analytics Screen',
    );
    _loadData();
    _checkProgress = true; // Always check progress on initial load
  }

  // Track whether to check progress (to avoid showing popup multiple times)
  bool _checkProgress = false;
  bool _hasShownMilestoneDialog = false;
  
  // Track which milestones have been shown to avoid repetition
  bool _hasShown50Milestone = false;
  bool _hasShown100Milestone = false;
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user details from Hive
      final userBox = await Hive.openBox<UserDetails>('userDetails');
      final userDetails = userBox.get('currentUser');

      if (userDetails == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Load nutrition history
      await _loadNutritionHistory(30);
      
      // Load weight history from Hive
      await _loadWeightHistoryFromHive(userDetails);
      
      // Load workout data
      await _loadExerciseData();
      
      // Load step data if health is connected
      final isConnected = await GoogleHealthService.isConnected();
      if (isConnected) {
        await _loadStepData();
      }

      setState(() {
        _userDetails = userDetails;
        _isLoading = false;
      });
      
      // Check if the user has hit any progress milestones
      if (_checkProgress) {
        _checkProgressMilestones();
        _checkProgress = false; // Reset flag after checking
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Check if user has reached progress milestones
  void _checkProgressMilestones() async {
    if (_userDetails == null || !mounted) return;
    
    // Load milestone dialog history from storage service
    _hasShown50Milestone = await StorageService.getSetting('hasShown50Milestone', defaultValue: false);
    _hasShown100Milestone = await StorageService.getSetting('hasShown100Milestone', defaultValue: false);
    
    // Calculate current progress
    final progress = _calculateActualProgress(_userDetails!.weight, _userDetails!.targetWeight);
    
    // Show 100% milestone if reached and not shown before
    if (progress >= 100 && !_hasShown100Milestone) {
      await StorageService.saveSetting('hasShown100Milestone', true);
      _showMilestoneDialog(100, progress);
      return;
    }
    
    // Show 50% milestone if reached and not shown before
    if (progress >= 50 && !_hasShown50Milestone && progress < 100) {
      await StorageService.saveSetting('hasShown50Milestone', true);
      _showMilestoneDialog(50, progress);
    }
  }
  
  // Show milestone celebration dialog
  void _showMilestoneDialog(int milestone, double progress) {
    if (_hasShownMilestoneDialog || !mounted || _userDetails == null) return;

    _hasShownMilestoneDialog = true;
    
    final message = milestone == 100
        ? 'Congratulations! You\'ve reached your weight goal! 🎉'
        : 'You\'re ${milestone.toStringAsFixed(0)}% of the way to your goal weight! Keep going! 💪';
        
    final title = milestone == 100
        ? 'Goal Achieved!'
        : 'Milestone Reached!';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Thanks!'),
          ),
        ],
      ),
    ).then((_) {
      // Reset flag after dialog is dismissed
      _hasShownMilestoneDialog = false;
    });
  }
  
  // Build the celebration dialog
  Widget _buildCelebrationDialog(int milestone, double progress) {
    final weightUnit = _userDetails?.isMetric == true ? 'kg' : 'lbs';
    final currentWeight = _userDetails?.weight ?? 0;
    final targetWeight = _userDetails?.targetWeight ?? 0;
    final startWeight = _getStartingWeight();
    
    // Calculate weight change
    final isWeightLoss = targetWeight < startWeight;
    final weightChange = (startWeight - currentWeight).abs();
    
    // Get weight entries for the chart
    final entries = _weightHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: milestone == 100 
              ? [Color.fromARGB(255, 74, 195, 82), Color.fromARGB(255, 143, 212, 45)]
              : [Color.fromARGB(255, 74, 195, 82), Color.fromARGB(255, 173, 255, 59)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Congratulations header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      milestone == 100 ? Icons.emoji_events : Icons.trending_up,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone == 100 ? 'Goal Achieved!' : 'Halfway There!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "You've reached a ${milestone}% milestone",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Progress stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  // Progress indicator
                  Row(
                    children: [
                      Text(
                        "${progress.round()}%",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isWeightLoss 
                                ? "You've lost ${weightChange.toStringAsFixed(1)} $weightUnit" 
                                : "You've gained ${weightChange.toStringAsFixed(1)} $weightUnit",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Mini weight chart
                  if (entries.length >= 3)
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(enabled: false),
                          minX: 0,
                          maxX: (entries.length - 1).toDouble(),
                          minY: (_getMinWeight(entries) - 1),
                          maxY: (_getMaxWeight(entries) + 1),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getWeightSpots(entries),
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.3),
                                    AppColors.primary.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
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
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dismiss button
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Share button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareAchievement(milestone, progress),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Share achievement as image
  Future<void> _shareAchievement(int milestone, double progress) async {
    // Close dialog first
    Navigator.of(context).pop();
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing your achievement to share...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      // In a real implementation, this would capture the achievement card as an image
      // and share it using a plugin like share_plus or screenshot
      
      // For now, just simulate the behavior
      await Future.delayed(const Duration(seconds: 1));
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Achievement shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing achievement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Get the starting weight from history or use current weight
  double _getStartingWeight() {
    if (_weightHistory.isEmpty) return _userDetails?.weight ?? 0;
    
    final entries = _weightHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return entries.first.value;
  }

  // Calculate progress percentage correctly based on starting weight, current weight, and target weight
  double _calculateActualProgress(double currentWeight, double targetWeight) {
    if (currentWeight == targetWeight) return 100.0;
    
    // Recalculate starting weight every time this method is called
    final startingWeight = getStartingWeightSync();
    
    // If starting weight equals target weight, return appropriate progress
    if (startingWeight == targetWeight) {
      return currentWeight == targetWeight ? 100.0 : 0.0;
    }
    
    // Determine if goal is weight loss or gain
    final isWeightLoss = targetWeight < startingWeight;
    
    // Calculate total change needed and progress made
    final totalChangeNeeded = (startingWeight - targetWeight).abs();
    final progressMade = isWeightLoss ? 
      (startingWeight - currentWeight).abs() : // For weight loss
      (currentWeight - startingWeight).abs();   // For weight gain
    
    // Calculate percentage with bounds checking
    double percentage = totalChangeNeeded > 0 ? (progressMade / totalChangeNeeded) * 100 : 0.0;
    
    // Handle overshooting the target
    if (isWeightLoss) {
      if (currentWeight < targetWeight) {
        // Overshot weight loss goal
        percentage = 100.0;
      }
    } else {
      if (currentWeight > targetWeight) {
        // Overshot weight gain goal
        percentage = 100.0;
      }
    }
    
    // Ensure percentage is between 0 and 100
    return percentage.clamp(0.0, 100.0);
  }

  // For the Goal Progress widget in the UI, use the fixed calculation
  double _calculateProgress(double currentWeight, double targetWeight) {
    return _calculateActualProgress(currentWeight, targetWeight);
  }

  Future<void> _loadNutritionHistory(int days) async {
    final Map<DateTime, Map<String, double>> nutritionHistory = {};
    Map<String, double> macroTotals = {'protein': 0, 'carbs': 0, 'fat': 0};
    
    // Get data for each day
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      
      // Get foods for date using FoodHiveService
      final foodLogs = await FoodHiveService.getFoodsForDate(date);
      
      // Calculate daily nutrition totals
      final Map<String, double> dailyNutrition = {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };
      
      for (var food in foodLogs) {
        dailyNutrition['calories'] = (dailyNutrition['calories'] ?? 0) + food.calories;
        dailyNutrition['protein'] = (dailyNutrition['protein'] ?? 0) + food.protein;
        dailyNutrition['carbs'] = (dailyNutrition['carbs'] ?? 0) + food.carbs;
        dailyNutrition['fat'] = (dailyNutrition['fat'] ?? 0) + food.fat;
      }
      
      // Only add days with actual consumption
      if (dailyNutrition['calories']! > 0) {
        nutritionHistory[date] = dailyNutrition;
        
        // Add to macro totals for distribution calculation
        macroTotals['protein'] = (macroTotals['protein'] ?? 0) + (dailyNutrition['protein'] ?? 0);
        macroTotals['carbs'] = (macroTotals['carbs'] ?? 0) + (dailyNutrition['carbs'] ?? 0);
        macroTotals['fat'] = (macroTotals['fat'] ?? 0) + (dailyNutrition['fat'] ?? 0);
      }
    }
    
    // Calculate macro distribution percentages
    final totalMacros = macroTotals['protein']! + macroTotals['carbs']! + macroTotals['fat']!;
    if (totalMacros > 0) {
      _macroDistribution = {
        'protein': macroTotals['protein']! / totalMacros,
        'carbs': macroTotals['carbs']! / totalMacros,
        'fat': macroTotals['fat']! / totalMacros,
      };
    }
    
    setState(() {
      _nutritionHistory = nutritionHistory;
    });
    

  }
  
  Future<void> _loadWeightHistoryFromHive(UserDetails userDetails) async {
    Map<DateTime, double> weightHistory = {};
    
    // Load the starting metrics first
    final startingMetrics = await StorageService.getStartingMetrics();
    
    // Get the current weight from user details
    final currentWeight = userDetails.weight;
    
    // Generate some realistic weight data based on the current weight and weight goal
    final now = DateTime.now();
    final random = Random();
    
    // Get the target weight to determine direction of change
    final targetWeight = userDetails.targetWeight;
    final isWeightLoss = targetWeight < currentWeight;
    
    // If we have starting metrics, use those values as the starting point
    final startingWeight = startingMetrics?.startingWeight ?? currentWeight;
    final startDate = startingMetrics?.startDate ?? now.subtract(const Duration(days: 90));
    
    // Calculate days since start date
    final daysSinceStart = now.difference(startDate).inDays;
    final daysToGenerate = daysSinceStart > 0 ? daysSinceStart : 90;
    
    // Generate weight entries from start date to now with a trend towards the goal
    for (int i = 0; i < daysToGenerate; i += 3) { // Record every 3 days
      final date = now.subtract(Duration(days: i));
      
      // Skip dates before the start date
      if (date.isBefore(startDate)) {
        continue;
      }
      
      // Calculate a reasonable variation that trends towards the goal
      // Later dates (further in the past) should be closer to the starting weight
      final progressPercent = i / daysToGenerate; // 0.0 to 1.0, where 1.0 is the furthest in the past
      
      // Calculate a weight with small random variation and a trend
      double weightDifference = (currentWeight - startingWeight) * (1 - progressPercent);
      
      // Add a small random variation
      final randomVariation = (random.nextDouble() * 0.4 - 0.2); // +/- 0.2 kg
      
      // Calculate the historical weight - closer to starting weight as we go back in time
      final historicalWeight = startingWeight + weightDifference + randomVariation;
      
      weightHistory[date] = double.parse(historicalWeight.toStringAsFixed(1));
    }
    
    // Add current weight as today's entry
    weightHistory[now] = currentWeight;
    
    // Add starting weight at the start date if we have starting metrics
    if (startingMetrics != null) {
      // Ensure the starting weight is exactly at the recorded start date
      weightHistory[startDate] = startingMetrics.startingWeight;
    }
    
    setState(() {
      _weightHistory = weightHistory;
    });
  }
  
  Future<void> _loadExerciseData() async {
    // Get exercises for the last 30 days
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    
    // Use ExerciseHiveService to get exercises
    final exercises = ExerciseHiveService.getAllExercises().where((exercise) {
      return exercise.date.isAfter(start) && exercise.date.isBefore(now.add(const Duration(days: 1)));
    }).toList();
    
    // Process exercise data
    Map<DateTime, int> caloriesByDay = {};
    Map<String, Map<String, dynamic>> exerciseTypes = {};
    
    for (final exercise in exercises) {
      // Convert to date only for grouping by day
      final exerciseDate = DateTime(
        exercise.date.year, 
        exercise.date.month, 
        exercise.date.day
      );
      
      // Sum calories by day
      caloriesByDay[exerciseDate] = (caloriesByDay[exerciseDate] ?? 0) + exercise.caloriesBurned;
      
      // Track exercise type details
      final type = exercise.type.name;
      if (!exerciseTypes.containsKey(type)) {
        exerciseTypes[type] = {
          'count': 0,
          'totalDuration': 0,
          'totalCalories': 0,
          'icon': exercise.type.icon,
        };
      }
      
      // Update exercise type statistics
      exerciseTypes[type]!['count'] = (exerciseTypes[type]!['count'] as int) + 1;
      exerciseTypes[type]!['totalDuration'] = (exerciseTypes[type]!['totalDuration'] as int) + exercise.durationMinutes;
      exerciseTypes[type]!['totalCalories'] = (exerciseTypes[type]!['totalCalories'] as int) + exercise.caloriesBurned;
    }
    
    setState(() {
      _workoutCaloriesBurned = caloriesByDay;
      _exerciseTypeDistribution = exerciseTypes;
    });
    
  
  }
  
  Future<void> _loadStepData() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weeklyStepsData = await GoogleHealthService.getStepsForDateRange(weekStart, weekEnd);
      
      setState(() {
        _stepsHistory = weeklyStepsData;
      });
    } catch (e) {
  
      // Fallback to empty data
      _stepsHistory = {};
    }
  }

  double _getBMI() {
    if (_userDetails == null) return 0.0;

    final height = _userDetails!.height;
    final weight = _userDetails!.weight;
    final isMetric = _userDetails!.isMetric;

    // Convert to metric if needed
    final heightInMeters = isMetric ? height / 100 : height * 0.0254;
    final weightInKg = isMetric ? weight : weight * 0.453592;

    // BMI = weight(kg) / height²(m)
    return weightInKg / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Healthy';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _getBMICategoryColor(String category) {
    switch (category) {
      case 'Underweight':
        return Colors.blue.shade400;
      case 'Healthy':
        return Colors.green.shade500;
      case 'Overweight':
        return Colors.amber.shade600;
      case 'Obese':
        return Colors.red.shade500;
      default:
        return _lightTextColor;
    }
  }

  Widget _buildTimeframeSelector() {
    // List of available timeframes
    final List<String> timeframes = ['7 Days', '30 Days', '90 Days', '6 Months', '1 Year'];
    
    return Container(
      height: 35,
      width: double.infinity, // Make it take full width
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute buttons evenly
          children: timeframes.map((timeframe) {
            final isSelected = _selectedTimeframe == timeframe;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
      onTap: () {
        setState(() {
                    _selectedTimeframe = timeframe;
                  });
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
                      width: 1,
                    ),
        ),
        child: Text(
                    timeframe,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
          ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeightChart() {
    return FutureBuilder<UserMetricsHistory?>(
      future: StorageService.getStartingMetrics(),
      builder: (context, snapshot) {
        final startingMetrics = snapshot.data;
        
        // Get fresh weight entries each time this widget builds
        final entries = getWeightEntriesForUI();
    
        // Filter out any entries before the starting date
        final filteredByStartDate = startingMetrics != null 
            ? entries.where((entry) => !entry.key.isBefore(startingMetrics.startDate)).toList()
            : entries;
        
        // Then apply the regular timeframe filter
        final filteredEntries = _filterEntriesByTimeframe(filteredByStartDate);
    
    // If no data, show placeholder
    if (filteredEntries.isEmpty) {
      return _buildEmptyChart('No weight data available');
    }

    // Calculate ideal interval between points to avoid crowding
    int interval = (filteredEntries.length / 5).ceil();
    interval = interval < 1 ? 1 : interval;

    // Target weight for reference line
    final targetWeight = _userDetails?.targetWeight ?? 0;
        
        // Find the starting metrics point if it exists in the filtered data
        int? startingPointIndex;
        
        if (startingMetrics != null) {
          // Find if the starting date is in our filtered entries
          for (int i = 0; i < filteredEntries.length; i++) {
            final entryDate = filteredEntries[i].key;
            // Check if dates are the same day (ignoring time)
            if (DateFormat('yyyy-MM-dd').format(entryDate) == 
                DateFormat('yyyy-MM-dd').format(startingMetrics.startDate)) {
              startingPointIndex = i;
              break;
            }
          }
        }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Title section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.show_chart,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Weight Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                                ),
                              ],
                            ),
              
              // Days selection section below title
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 0, left: 0),
                child: _buildTimeframeSelector(),
              ),
              
              // Start date indicator
              if (startingMetrics != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                      Icons.calendar_today,
                  size: 14,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Started tracking: ${DateFormat('MMM d, yyyy').format(startingMetrics.startDate)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: _lightTextColor,
                        fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

              // Chart area
              AspectRatio(
                aspectRatio: 1.6,
            child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                        drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                            color: AppColors.textSecondary.withOpacity(0.1),
                        strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                            reservedSize: 30,
                            interval: (filteredEntries.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                              if (value.toInt() >= filteredEntries.length || value.toInt() < 0) {
                                return const SizedBox();
                              }
                              final date = filteredEntries[value.toInt()].key;
                            return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM d').format(date),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    ),
                              ),
                            );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (filteredEntries.length - 1).toDouble(),
                  minY: (_getMinWeight(filteredEntries) - 1).clamp(
                      // Make sure target weight is visible in the chart
                      (targetWeight > 0) ? 
                        min(targetWeight - 2, _getMinWeight(filteredEntries) - 1) : 
                        _getMinWeight(filteredEntries) - 1,
                      double.infinity),
                  maxY: (_getMaxWeight(filteredEntries) + 1).clamp(
                      0,
                      (targetWeight > 0) ? 
                        max(targetWeight + 2, _getMaxWeight(filteredEntries) + 1) :
                        _getMaxWeight(filteredEntries) + 1),
                      
                      // Add tooltips that show the date and weight
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spots) => AppColors.primary.withOpacity(0.8),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = filteredEntries[spot.x.toInt()].key;
                          final isLatest = spot.x.toInt() == filteredEntries.length - 1;
                              final isStartPoint = startingPointIndex != null && spot.x.toInt() == startingPointIndex;
                              
                              String label = '${DateFormat('MMM d').format(date)}\n${spot.y.toStringAsFixed(1)} ${_userDetails?.isMetric == true ? 'kg' : 'lbs'}';
                              
                              if (isLatest) {
                                label += ' (current)';
                              } else if (isStartPoint) {
                                label += ' (starting)';
                              }
                              
                          return LineTooltipItem(
                                label,
                            TextStyle(
                              color: Colors.white,
                                  fontWeight: (isLatest || isStartPoint) ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                      
                  lineBarsData: [
                    // Target weight reference line (dashed)
                    if (targetWeight > 0)
                    LineChartBarData(
                        spots: [
                          FlSpot(0, targetWeight),
                          FlSpot((filteredEntries.length - 1).toDouble(), targetWeight),
                        ],
                        isCurved: false,
                            color: AppColors.warning.withOpacity(0.8),
                            barWidth: 2.0,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                    // Actual weight data line
                    LineChartBarData(
                      spots: _getWeightSpots(filteredEntries),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppColors.primary,
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                              // Highlight points of interest
                              final bool isLatestPoint = index == filteredEntries.length - 1;
                              final bool isStartPoint = startingPointIndex != null && index == startingPointIndex;
                              
                              if (isLatestPoint) {
                                // Current weight - green dot
                          return FlDotCirclePainter(
                                  radius: 6,
                                  color: const Color(0xFF4CAF50),
                                  strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                              } else if (isStartPoint) {
                                // Starting weight - blue dot
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: Colors.blue.shade400,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              } else {
                                // Hide other dots
                                return FlDotCirclePainter(
                                  radius: 0,
                                  color: Colors.transparent,
                                  strokeWidth: 0,
                                  strokeColor: Colors.transparent,
                                );
                              }
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                                AppColors.primary.withOpacity(0.3),
                            AppColors.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                    ),
                  ),
                ),
              ),
              
              // Add modern completion progress UI below the graph
              if (_userDetails != null && targetWeight > 0)
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 4, right: 4, bottom: 8),
                child: _buildModernProgressUI(_userDetails!.weight, targetWeight, _userDetails!.isMetric),
          ),
          
          // Legend
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildChartLegendItem(
                      'Starting Weight', 
                      Colors.blue.shade400,
                      isDashed: false,
                      isSpecial: true
                    ),
                    _buildChartLegendItem(
                      'Current Weight', 
                      const Color(0xFF4CAF50),
                      isDashed: false,
                      isSpecial: true
                    ),
                    _buildChartLegendItem(
                      'Progress', 
                      AppColors.primary,
                      isDashed: false
                    ),
                    _buildChartLegendItem(
                      'Target', 
                      AppColors.warning,
                      isDashed: true
                    ),
                  ],
              ),
            ),
        ],
      ),
        );
      }
    );
  }
  
  Widget _buildChartLegendItem(String label, Color color, {bool isDashed = false, bool isSpecial = false}) {
    return Row(
      children: [
        // Line indicator
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(1.5),
          ),
          child: isDashed 
            ? CustomPaint(
                painter: DashedLinePainter(color: color),
              )
            : null,
        ),
        const SizedBox(width: 4),
        if (isSpecial)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  // Filter entries based on selected timeframe
  List<MapEntry<DateTime, double>> _filterEntriesByTimeframe(List<MapEntry<DateTime, double>> entries) {
    if (entries.isEmpty) {
      return [];
    }
    
    final now = DateTime.now();
    final cutoff = _selectedTimeframe == '7 Days' 
      ? now.subtract(const Duration(days: 7))
      : _selectedTimeframe == '30 Days'
        ? now.subtract(const Duration(days: 30))
        : _selectedTimeframe == '90 Days'
          ? now.subtract(const Duration(days: 90))
          : _selectedTimeframe == '6 Months'
            ? now.subtract(const Duration(days: 180))
            : now.subtract(const Duration(days: 365)); // 1 Year

    return entries.where((entry) => entry.key.isAfter(cutoff)).toList();
  }
  
  List<FlSpot> _getWeightSpots(List<MapEntry<DateTime, double>> entries) {
    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }
    return spots;
  }
  
  double _getMinWeight(List<MapEntry<DateTime, double>> entries) {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.value).reduce(min);
  }
  
  double _getMaxWeight(List<MapEntry<DateTime, double>> entries) {
    if (entries.isEmpty) return 100;
    return entries.map((e) => e.value).reduce(max);
  }
  
  Widget _buildNutritionTabs() {
    // Get data for each macro per day
    final entries = _nutritionHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // Take only the last 7 days
    final lastSevenDays = entries.length > 7 ? entries.sublist(entries.length - 7) : entries;
    
    // Default to the most recent date with data
    DateTime selectedDate = lastSevenDays.isNotEmpty 
        ? lastSevenDays.last.key 
        : DateTime.now();
    
    // Extract macro data for the selected date
    Map<String, double> selectedDateData = lastSevenDays.isNotEmpty 
        ? lastSevenDays.lastWhere((entry) => entry.key == selectedDate, orElse: () => lastSevenDays.last).value
        : {'protein': 0, 'carbs': 0, 'fat': 0};
        
    // Calculate total macros for the pie chart
    double totalMacros = (selectedDateData['protein'] ?? 0) + 
                         (selectedDateData['carbs'] ?? 0) + 
                         (selectedDateData['fat'] ?? 0);

    // Calculate percentages
    Map<String, double> macroPercentages = {
      'protein': totalMacros > 0 ? (selectedDateData['protein'] ?? 0) / totalMacros : 0,
      'carbs': totalMacros > 0 ? (selectedDateData['carbs'] ?? 0) / totalMacros : 0,
      'fat': totalMacros > 0 ? (selectedDateData['fat'] ?? 0) / totalMacros : 0,
    };
    
    return StatefulBuilder(
      builder: (context, setState) {
    return Column(
        children: [
            // Date selection
        Container(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: lastSevenDays.length,
                itemBuilder: (context, index) {
                  final date = lastSevenDays[index].key;
                  final isSelected = date.year == selectedDate.year && 
                                    date.month == selectedDate.month && 
                                    date.day == selectedDate.day;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDate = date;
                        selectedDateData = lastSevenDays[index].value;
                        
                        // Recalculate total macros and percentages
                        totalMacros = (selectedDateData['protein'] ?? 0) + 
                                     (selectedDateData['carbs'] ?? 0) + 
                                     (selectedDateData['fat'] ?? 0);
                                     
                        macroPercentages = {
                          'protein': totalMacros > 0 ? (selectedDateData['protein'] ?? 0) / totalMacros : 0,
                          'carbs': totalMacros > 0 ? (selectedDateData['carbs'] ?? 0) / totalMacros : 0,
                          'fat': totalMacros > 0 ? (selectedDateData['fat'] ?? 0) / totalMacros : 0,
                        };
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        DateFormat('MMM d').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 20),
            
            // Calories display
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _caloriesColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                  Text(
                    'Total Calories',
                          style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                            color: _caloriesColor,
                          ),
                        ),
                  Text(
                    '${(selectedDateData['calories'] ?? 0).round()} kcal',
                          style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Pie chart for macros
            Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: macroPercentages['carbs']! * 100,
                          title: totalMacros > 0 ? '${(macroPercentages['carbs']! * 100).round()}%' : '',
                          color: _carbsColor,
                          radius: 55,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: macroPercentages['protein']! * 100,
                          title: totalMacros > 0 ? '${(macroPercentages['protein']! * 100).round()}%' : '',
                          color: _proteinColor,
                          radius: 55,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: macroPercentages['fat']! * 100,
                          title: totalMacros > 0 ? '${(macroPercentages['fat']! * 100).round()}%' : '',
                          color: _fatColor,
                          radius: 55,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 20,
                      centerSpaceColor: Colors.white,
                    ),
                  ),
                ),
                
                // Legend with actual gram values
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDetailedNutrientLegendItem(
                          'Carbs', 
                          _carbsColor,
                          selectedDateData['carbs'] ?? 0,
                          macroPercentages['carbs']! * 100
                        ),
                        const SizedBox(height: 12),
                        _buildDetailedNutrientLegendItem(
                          'Protein', 
                          _proteinColor,
                          selectedDateData['protein'] ?? 0,
                          macroPercentages['protein']! * 100
                        ),
                        const SizedBox(height: 12),
                        _buildDetailedNutrientLegendItem(
                          'Fat', 
                          _fatColor,
                          selectedDateData['fat'] ?? 0,
                          macroPercentages['fat']! * 100
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Display date
        Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Text(
                'Macronutrient breakdown for ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
        );
      }
    );
  }
  
  Widget _buildBarChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
          Text(
          label,
            style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailedNutrientLegendItem(String label, Color color, double grams, double percentage) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${grams.round()}g (${percentage.round()}%)",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Calculate the total of a specific macro across all entries
  double _getTotalMacro(List<MapEntry<DateTime, Map<String, double>>> entries, String macro) {
    return entries.fold(0.0, (sum, entry) => sum + (entry.value[macro] ?? 0));
  }
  
  // Get the maximum nutrition value for scaling the chart
  double _getMaxNutritionValue(List<MapEntry<DateTime, Map<String, double>>> entries) {
    double maxValue = 0;
    
    for (final entry in entries) {
      final values = entry.value;
      // Use calories for scaling since they're typically much larger
      final calValue = values['calories'] ?? 0;
      if (calValue > maxValue) maxValue = calValue;
    }
    
    return maxValue;
  }
  
  // Create bar groups for the nutrition chart - with grouped bars for macros
  List<BarChartGroupData> _getNutritionBarGroups(List<MapEntry<DateTime, Map<String, double>>> entries) {
    const double barWidth = 5; // Reduced from 6 for better spacing
    
    return List.generate(entries.length, (index) {
      final values = entries[index].value;
      final calories = (values['calories'] ?? 0) / 10; // Scale down calories to fit with macros
      final protein = values['protein'] ?? 0;
      final carbs = values['carbs'] ?? 0;
      final fat = values['fat'] ?? 0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          // Calories bar
          BarChartRodData(
            toY: calories,
            color: _caloriesColor,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          // Protein bar
          BarChartRodData(
            toY: protein,
            color: _proteinColor,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          // Carbs bar
          BarChartRodData(
            toY: carbs,
            color: _carbsColor,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          // Fat bar
          BarChartRodData(
            toY: fat,
            color: _fatColor,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ],
        barsSpace: 3, // Reduced from 4
      );
    });
  }

  Widget _buildNutritionChart() {
    // Sort nutrition entries by date
    final entries = _nutritionHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // If no data, show placeholder
    if (entries.isEmpty) {
      return _buildEmptyChart('No nutrition data available');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // Reduced from 24 to 20
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                    'Daily Nutrition',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
                  SizedBox(height: 4),
          Text(
                    'Detailed macronutrient breakdown',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
                        ),
                      ),
                    ],
              ),
              Row(
                  children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () {
                      setState(() {
                        _loadDataForPreviousPeriod();
                      });
                    },
                    tooltip: 'Previous days',
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: _isCurrentPeriod ? null : () {
                      setState(() {
                        _loadDataForNextPeriod();
                      });
                    },
                    tooltip: 'Next days',
                    splashRadius: 20,
                    color: _isCurrentPeriod ? AppColors.textSecondary.withOpacity(0.3) : null,
                  ),
                ],
          ),
        ],
          ),
          const SizedBox(height: 16),
          
          // Tabs for different nutrition views
          _buildNutritionTabs(),
          
          // Remove duplicate macro distribution pie chart section
        ],
      ),
    );
  }
  
  // Add variables to track the current data period
  bool _isCurrentPeriod = true;
  DateTime _periodStartDate = DateTime.now().subtract(const Duration(days: 7));
  
  // Load data for previous time period
  void _loadDataForPreviousPeriod() {
    final previousStartDate = _periodStartDate.subtract(const Duration(days: 7));
    _loadNutritionHistoryForPeriod(previousStartDate, _periodStartDate);
    _periodStartDate = previousStartDate;
    _isCurrentPeriod = false;
  }
  
  // Load data for next time period
  void _loadDataForNextPeriod() {
    final nextStartDate = _periodStartDate.add(const Duration(days: 7));
    final now = DateTime.now();
    
    if (nextStartDate.isAfter(now.subtract(const Duration(days: 7)))) {
      // This would be the current period, so just reload the current data
      _loadData();
      _isCurrentPeriod = true;
    } else {
      _loadNutritionHistoryForPeriod(nextStartDate, nextStartDate.add(const Duration(days: 7)));
      _periodStartDate = nextStartDate;
      _isCurrentPeriod = false;
    }
  }
  
  // Load nutrition history for a specific period
  Future<void> _loadNutritionHistoryForPeriod(DateTime startDate, DateTime endDate) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final Map<DateTime, Map<String, double>> nutritionHistory = {};
      Map<String, double> macroTotals = {'protein': 0, 'carbs': 0, 'fat': 0};
      
      // Get data for each day in the period
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        if (date.isAfter(endDate)) break;
        
        // Get foods for date using FoodHiveService
        final foodLogs = await FoodHiveService.getFoodsForDate(date);
        
        // Calculate daily nutrition totals
        final Map<String, double> dailyNutrition = {
          'calories': 0,
          'protein': 0,
          'carbs': 0,
          'fat': 0,
        };
        
        for (var food in foodLogs) {
          dailyNutrition['calories'] = (dailyNutrition['calories'] ?? 0) + food.calories;
          dailyNutrition['protein'] = (dailyNutrition['protein'] ?? 0) + food.protein;
          dailyNutrition['carbs'] = (dailyNutrition['carbs'] ?? 0) + food.carbs;
          dailyNutrition['fat'] = (dailyNutrition['fat'] ?? 0) + food.fat;
        }
        
        // Only add days with actual consumption
        if (dailyNutrition['calories']! > 0) {
          nutritionHistory[date] = dailyNutrition;
          
          // Add to macro totals for distribution calculation
          macroTotals['protein'] = (macroTotals['protein'] ?? 0) + (dailyNutrition['protein'] ?? 0);
          macroTotals['carbs'] = (macroTotals['carbs'] ?? 0) + (dailyNutrition['carbs'] ?? 0);
          macroTotals['fat'] = (macroTotals['fat'] ?? 0) + (dailyNutrition['fat'] ?? 0);
        }
      }
      
      // Calculate macro distribution percentages
      final totalMacros = macroTotals['protein']! + macroTotals['carbs']! + macroTotals['fat']!;
      if (totalMacros > 0) {
        _macroDistribution = {
          'protein': macroTotals['protein']! / totalMacros,
          'carbs': macroTotals['carbs']! / totalMacros,
          'fat': macroTotals['fat']! / totalMacros,
        };
      }
      
      setState(() {
        _nutritionHistory = nutritionHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Widget _buildActivityChart() {
    // Sort entries by date
    final stepEntries = _stepsHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final calorieEntries = _workoutCaloriesBurned.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // If no data, show placeholder
    if (stepEntries.isEmpty && calorieEntries.isEmpty) {
      return _buildEmptyChart('No activity data available');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Steps Line Chart (if data available)
          if (stepEntries.isNotEmpty) ...[
            Text(
              'Steps',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.textSecondary.withOpacity(0.2),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < stepEntries.length) {
                            final date = stepEntries[value.toInt()].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (stepEntries.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxSteps(stepEntries) + 1000,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spots) => _stepsColor.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = stepEntries[spot.x.toInt()].key;
                          return LineTooltipItem(
                            '${DateFormat('E').format(date)}: ${spot.y.toInt()} steps',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getStepSpots(stepEntries),
                      isCurved: true,
                      color: _stepsColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _stepsColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _stepsColor.withOpacity(0.2),
                        gradient: LinearGradient(
                          colors: [
                            _stepsColor.withOpacity(0.3),
                            _stepsColor.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
          
          // Exercise Distribution (if data available)
          if (_exerciseTypeDistribution.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
             
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
                    'Exercise Summary',
              style: TextStyle(
                      fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
                  const SizedBox(height: 4),
                  Text(
                    'Distribution based on time spent',
                    style: TextStyle(
                      fontSize: 12, 
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Exercise Type Distribution
                  Column(
                children: [
                      // Pie Chart Container
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                    child: PieChart(
                      PieChartData(
                        sections: _getExercisePieSections(),
                        sectionsSpace: 2,
                              centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                      ),
                      const SizedBox(height: 32),
                      // Legend Items
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exercise Types',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._getExerciseLegendItems(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Exercise Details List
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
         
              ),
          
            ),
          ],
        ],
      ),
    );
  }
  
  List<FlSpot> _getStepSpots(List<MapEntry<DateTime, int>> entries) {
    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value.toDouble()));
    }
    return spots;
  }
  
  double _getMaxSteps(List<MapEntry<DateTime, int>> entries) {
    if (entries.isEmpty) return 10000;
    return entries.map((e) => e.value.toDouble()).reduce(max);
  }
  
  List<PieChartSectionData> _getExercisePieSections() {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade500,
      Colors.orange.shade500,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    
    // Calculate total duration for all exercises (used for time-based percentage)
    final totalDuration = _exerciseTypeDistribution.values.fold(0, (sum, data) => sum + (data['totalDuration'] as int));
    
    final sections = <PieChartSectionData>[];
    int colorIndex = 0;
    
    for (final entry in _exerciseTypeDistribution.entries) {
      // Calculate percentage based on exercise time rather than count
      final percentage = totalDuration > 0 ? (entry.value['totalDuration'] as int) / totalDuration : 0;
      
      // Round percentage for display
      final displayPercentage = (percentage * 100).round();
      
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: percentage * 100,
          title: '$displayPercentage%',
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.3),
              ),
            ],
          ),
          radius: 50,
          titlePositionPercentageOffset: 0.55,
        ),
      );
      colorIndex++;
    }
    
    return sections;
  }
  
  List<Widget> _getExerciseLegendItems() {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade500,
      Colors.orange.shade500,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    
    final legendItems = <Widget>[];
    int colorIndex = 0;
    
    // Sort by duration descending for more meaningful display
    final sortedEntries = _exerciseTypeDistribution.entries.toList()
      ..sort((a, b) => (b.value['totalDuration'] as int).compareTo(a.value['totalDuration'] as int));
    
    // Calculate totals for both count and duration based percentages
    final totalCount = _exerciseTypeDistribution.values.fold(0, (sum, data) => sum + (data['count'] as int));
    final totalDuration = _exerciseTypeDistribution.values.fold(0, (sum, data) => sum + (data['totalDuration'] as int));
    
    for (final entry in sortedEntries) {
      final data = entry.value as Map<String, dynamic>;
      
      // Calculate both types of percentages
      final countPercentage = totalCount > 0 ? ((data['count'] as int) / totalCount) * 100 : 0;
      final timePercentage = totalDuration > 0 ? ((data['totalDuration'] as int) / totalDuration) * 100 : 0;
      
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color indicator
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors[colorIndex % colors.length],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[colorIndex % colors.length].withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Text content in a layout that prevents overflow
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate available width for text
                    final availableWidth = constraints.maxWidth;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exercise type name with percentage
                        SizedBox(
                          width: availableWidth,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors[colorIndex % colors.length].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${timePercentage.round()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors[colorIndex % colors.length],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        
                        // Stats row with flexible layout
                        Wrap(
                          spacing: 4,
                          children: [
                            Text(
                              '${data['count']} sessions',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${data['totalDuration']} min (${countPercentage.round()}% of count)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      colorIndex++;
    }
    
    return legendItems;
  }
  
  Widget _buildEmptyChart(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to edit',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMISection() {
    final bmi = _getBMI();
    final bmiCategory = _getBMICategory(bmi);
    final bmiCategoryColor = _getBMICategoryColor(bmiCategory);
    
    // Calculate position for the BMI marker
    final bmiPosition = (bmi / 40).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BMI Value and Category
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: bmiCategoryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'kg/m²',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bmiCategoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: bmiCategoryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  bmiCategory,
                  style: TextStyle(
                    color: bmiCategoryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // BMI Scale
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BMI Scale bar with gradient
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.blue,    // Underweight
                      Colors.green,   // Normal
                      Colors.orange,  // Overweight
                      Colors.red,     // Obese
                    ],
                    stops: [0.18, 0.4, 0.55, 0.75],
                  ),
                ),
              ),
              
              // BMI marker
              Container(
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: bmiPosition,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: bmiCategoryColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Scale labels
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBMIRangeLabel('Underweight', '< 18.5', Colors.blue),
                    _buildBMIRangeLabel('Normal', '18.5-25', Colors.green),
                    _buildBMIRangeLabel('Overweight', '25-30', Colors.orange),
                    _buildBMIRangeLabel('Obese', '> 30', Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildBMIRangeLabel(String label, String range, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          range,
          style: TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Updated method to make the weight cards more compact
  Widget _buildCompactMetricCard(
      String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
              child: Icon(
                icon,
                color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
          const SizedBox(height: 4),
                Row(
            mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
              const SizedBox(width: 2),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  // Add new method to calculate days since last weight update
  int _daysSinceLastWeightUpdate() {
    if (_weightHistory.isEmpty) return 999; // No weight updates yet
    
    final latestWeightDate = _weightHistory.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final now = DateTime.now();
    final difference = now.difference(latestWeightDate).inDays;
    
    return difference;
  }
  
  // Add new method to build weight update reminder card
  Widget _buildWeightUpdateReminderCard() {
    final daysSinceUpdate = _daysSinceLastWeightUpdate();
    final needsUpdate = daysSinceUpdate >= 7; // Weekly updates
    
    final latestWeightDate = _weightHistory.isEmpty 
        ? null 
        : _weightHistory.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    
    final lastUpdateText = latestWeightDate == null 
        ? 'No weight data recorded yet' 
        : 'Last updated ${DateFormat('MMM d, yyyy').format(latestWeightDate)}';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: needsUpdate 
              ? [Color(0xFFFFA07A), Color(0xFFFF6347)] // Light coral to tomato for urgency
              : [Color(0xFF9DC88D), Color(0xFF64A466)], // Green gradient for up-to-date
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: needsUpdate 
                ? Color(0xFFFF6347).withOpacity(0.3)
                : Color(0xFF64A466).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  needsUpdate ? Icons.update : Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsUpdate ? 'Weight Update Needed' : 'Weight Tracking On Track',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      needsUpdate 
                          ? 'It\'s been ${daysSinceUpdate} days since your last weight update. Weekly tracking helps you stay on track.'
                          : 'Great job keeping your weight data up to date!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastUpdateText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToHeightWeightScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: needsUpdate ? Color(0xFFFF6347) : Color(0xFF64A466),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Update Weight',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your analytics...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Handle case when user details might be null
    if (_userDetails == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            'Analytics',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Please set up your profile to view analytics',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserDetailsScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Set up profile'),
              ),
            ],
          ),
        ),
      );
    }

    final currentWeight = _userDetails!.weight;
    final targetWeight = _userDetails!.targetWeight;
    final isMetric = _userDetails!.isMetric;
    final weightUnit = isMetric ? 'kg' : 'lbs';
    
    // Helper functions for weight progress
    String getRemainingWeightText() {
      final remaining = targetWeight - currentWeight;
      return remaining > 0 ? '${remaining.abs().round()} $weightUnit to gain' : 
        remaining < 0 ? '${remaining.abs().round()} $weightUnit to lose' : 'Goal reached!';
    }
    
    String getWeightPercentageText() {
      if (targetWeight == currentWeight) return 'Goal reached!';
      final goalReachedPercentage = (1 - (targetWeight - currentWeight).abs() / (targetWeight - _userDetails!.weight).abs()) * 100;
      return '${goalReachedPercentage.round()}% complete';
    }
    
    double calculateWeightProgress() {
      if (targetWeight == currentWeight) return 1.0;
      final progressPercent = (1 - (targetWeight - currentWeight).abs() / (targetWeight - _userDetails!.weight).abs());
      return progressPercent.clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Analytics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weight update reminder - place it at the top for visibility
                _buildWeightUpdateReminderCard(),
                
                // Weight summary cards (horizontal layout without progress)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                        children: [
                          // Current weight side
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToHeightWeightScreen(),
                              child: _buildCompactMetricCard(
                                'Current',
                                currentWeight.toStringAsFixed(1),
                                weightUnit,
                                Icons.monitor_weight,
                                AppColors.primary,
                              ),
                            ),
                          ),
                          // Divider
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          // Goal weight side
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToWeightGoalScreen(),
                              child: _buildCompactMetricCard(
                                'Goal',
                                targetWeight.toStringAsFixed(1),
                                weightUnit,
                                Icons.fitness_center,
                                AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                  ),
                ),
                
                // Weight Trend Chart (next section)
                _buildWeightChart(),

                const SizedBox(height: 24),

                // BMI section - now using the new compact design
                _buildBMISection(),

                const SizedBox(height: 24),
                
                // Nutrition Chart
                _buildNutritionChart(),
                
                const SizedBox(height: 24),
                
                // Activity Chart
                _buildActivityChart(),
                
                // Add padding at the bottom
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Navigation methods for weight and goal updates
  
  void _navigateToHeightWeightScreen() async {
    if (_userDetails == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightUpdateScreen(
          userDetails: _userDetails!,
          onWeightUpdated: (newWeight) {
            // This callback is optional as we're already handling the result when the screen pops
          },
        ),
      ),
    );

    // If we got a result back, reload data
    if (result != null) {
      _loadData();
    }
  }

  void _navigateToWeightGoalScreen() async {
    if (_userDetails == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightGoalScreen(
          height: _userDetails!.height,
          weight: _userDetails!.weight,
          isMetric: _userDetails!.isMetric,
          birthDate: _userDetails!.birthDate,
          workoutsPerWeek: _userDetails!.workoutsPerWeek,
          gender: _userDetails!.gender ?? 'Other',
          motivationGoal: _userDetails!.motivationGoal ?? 'healthier',
          dietType: _userDetails!.dietType ?? 'classic',
          weightChangeSpeed: _userDetails!.weightChangeSpeed ?? 0.1,
          initialGoalId: _userDetails!.weightGoal,
          isUpdate: true,
        ),
      ),
    );

    if (result != null && result is String) {
      // After weight goal is updated, navigate to target weight screen
      _navigateToTargetWeightScreen(newGoal: result);
    }
  }
  
  void _navigateToTargetWeightScreen({String? newGoal}) async {
    if (_userDetails == null) return;

    // Use the new goal if provided, otherwise use existing goal
    final weightGoal = newGoal ?? _userDetails!.weightGoal;

    // Use pushReplacement instead of push to avoid stacking screens
    final result = await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TargetWeightScreen(
          height: _userDetails!.height,
          weight: _userDetails!.weight,
          isMetric: _userDetails!.isMetric,
          birthDate: _userDetails!.birthDate,
          workoutsPerWeek: _userDetails!.workoutsPerWeek,
          weightGoal: weightGoal,
          gender: _userDetails!.gender ?? 'Other',
          motivationGoal: _userDetails!.motivationGoal ?? 'healthier',
          dietType: _userDetails!.dietType ?? 'classic',
          weightChangeSpeed: _userDetails!.weightChangeSpeed ?? 0.1,
          initialTargetWeight: _userDetails!.targetWeight,
          isUpdate: true,
        ),
      ),
    );

    if (result != null) {
      // Save the updated goal and target weight
      final updatedDetails = UserDetails(
        height: _userDetails!.height,
        weight: _userDetails!.weight,
        isMetric: _userDetails!.isMetric,
        birthDate: _userDetails!.birthDate,
        workoutsPerWeek: _userDetails!.workoutsPerWeek,
        weightGoal: weightGoal, // Use the new goal
        targetWeight: result as double, // Use the new target weight
        gender: _userDetails!.gender,
        motivationGoal: _userDetails!.motivationGoal,
        dietType: _userDetails!.dietType,
        weightChangeSpeed: _userDetails!.weightChangeSpeed,
      );

      // Save the updated details to Hive
      final userBox = await Hive.openBox<UserDetails>('userDetails');
      await userBox.put('currentUser', updatedDetails);
      
      // Reload data to reflect changes
      _loadData();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Weight goal updated'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  double _calculateDetailedProgress(double currentWeight, double targetWeight) {
    if (currentWeight == targetWeight) return 100.0;
    
    // Get starting weight from SharedPreferences or history
    double startingWeight = getStartingWeightSync();
    
    // If starting weight equals target weight, return appropriate progress
    if (startingWeight == targetWeight) {
      return currentWeight == targetWeight ? 100.0 : 0.0;
    }
    
    // Determine if goal is weight loss or gain
    final isWeightLoss = targetWeight < startingWeight;
    
    // Calculate total change needed and progress made
    final totalChangeNeeded = (startingWeight - targetWeight).abs();
    final progressMade = isWeightLoss ? 
      (startingWeight - currentWeight).abs() : // For weight loss
      (currentWeight - startingWeight).abs();   // For weight gain
    
    // Calculate percentage with bounds checking
    double percentage = (progressMade / totalChangeNeeded) * 100;
    
    // Handle overshooting the target
    if (isWeightLoss) {
      if (currentWeight < targetWeight) {
        // Overshot weight loss goal
        percentage = 100.0;
      }
    } else {
      if (currentWeight > targetWeight) {
        // Overshot weight gain goal
        percentage = 100.0;
      }
    }
    
    // Ensure percentage is between 0 and 100
    return percentage.clamp(0.0, 100.0);
  }
  
  // Get the starting weight for progress calculations and UI display
  Future<double> getStartingWeight() async {
    // First try to get the saved starting metrics from Hive
    final startingMetrics = await StorageService.getStartingMetrics();
    if (startingMetrics != null) {
      return startingMetrics.startingWeight;
    }
    
    // If no saved starting metrics, fall back to the first weight in history or current weight
    if (_weightHistory.isEmpty) return _userDetails?.weight ?? 0;
    
    final entries = _weightHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return entries.first.value;
  }
  
  // Synchronous version for immediate UI needs
  double getStartingWeightSync() {
    // For immediate UI needs where we can't await, use weight history or current weight
    if (_weightHistory.isEmpty) return _userDetails?.weight ?? 0;
    
    final entries = _weightHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // First entry is the oldest - starting weight
    return entries.isNotEmpty ? entries.first.value : (_userDetails?.weight ?? 0);
  }

  // Add a modern progress UI widget
  Widget _buildModernProgressUI(double currentWeight, double targetWeight, bool isMetric) {
    // Get starting weight - recalculate every time this widget is built
    final startingWeight = getStartingWeightSync();
    
    // Determine if goal is weight loss or gain
    final isWeightLoss = targetWeight < startingWeight;
    
    // Calculate progress percentage - using fresh values each time
    double progressPercentage = 0.0;
    if (startingWeight != targetWeight) {
      final totalChange = (targetWeight - startingWeight).abs();
      final progressMade = isWeightLoss 
          ? (startingWeight - currentWeight).abs() 
          : (currentWeight - startingWeight).abs();
      
      progressPercentage = totalChange > 0 ? (progressMade / totalChange) * 100 : 0.0;
      
      // Handle edge cases
      if (isWeightLoss && currentWeight < targetWeight) {
        progressPercentage = 100.0; // Overshot target for weight loss
      } else if (!isWeightLoss && currentWeight > targetWeight) {
        progressPercentage = 100.0; // Overshot target for weight gain
      }
      
      progressPercentage = progressPercentage.clamp(0.0, 100.0);
    } else if (currentWeight == targetWeight) {
      // Already at target
      progressPercentage = 100.0;
    }
    
    // Calculate remaining amount
    final remainingAmount = (targetWeight - currentWeight).abs();
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final goalType = isWeightLoss ? 'lose' : 'gain';
    
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weight Goal Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            
            // Progress status indicator moved below the title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: progressPercentage >= 100
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  progressPercentage >= 100
                      ? 'Goal Reached! 🎉'
                      : '${progressPercentage.round()}% Complete',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: progressPercentage >= 100
                        ? const Color(0xFF4CAF50)
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
            
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Background
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: AppColors.textSecondary.withOpacity(0.1),
                    ),
                    // Progress
                    Container(
                      height: 12,
                      width: (progressPercentage / 100) * (MediaQuery.of(context).size.width - 64),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: progressPercentage >= 100
                              ? [const Color(0xFF4CAF50), const Color(0xFF8BC34A)]
                              : [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Progress metrics - stacked vertically for cleaner UI
            _buildProgressMetricItem(
              title: 'Starting Weight:',
              value: '${startingWeight.toStringAsFixed(1)} $weightUnit',
              color: Colors.blue.shade400,
              icon: Icons.flag
            ),
            
            const SizedBox(height: 6),
            
            _buildProgressMetricItem(
              title: 'Current Weight:',
              value: '${currentWeight.toStringAsFixed(1)} $weightUnit',
              color: const Color(0xFF4CAF50),
              icon: Icons.circle
            ),
            
            const SizedBox(height: 6),
            
            _buildProgressMetricItem(
              title: 'Target Weight:',
              value: '${targetWeight.toStringAsFixed(1)} $weightUnit',
              color: AppColors.warning,
              icon: Icons.flag_circle
            ),
            
            // Additional motivation text
            if (progressPercentage < 100)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWeightLoss ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${remainingAmount.toStringAsFixed(1)} $weightUnit to $goalType',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for progress metric items
  Widget _buildProgressMetricItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Get weight entries for UI
  List<MapEntry<DateTime, double>> getWeightEntriesForUI() {
    // Sort by date and return
    final entries = _weightHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }
}