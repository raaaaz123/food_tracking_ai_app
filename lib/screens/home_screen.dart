import 'package:flutter/material.dart';
import 'package:nutrizen_ai/models/workout_plan.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/nutrition_service.dart' hide NutritionInfo;
import '../services/preferences_service.dart';
import '../services/food_hive_service.dart';
import '../services/exercise_service.dart';
import '../services/google_health_service.dart';
import '../models/nutrition_info.dart';
import '../models/exercise.dart';
import 'scan_food_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'food_database_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'workout_plans_screen.dart';
import 'dart:math' as math;
import 'exercise_logging_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logged_exercise_detail_screen.dart';
import '../services/exercise_hive_service.dart';
import '../services/nutrition_plan_service.dart';
import 'package:hive/hive.dart';
import '../models/user_details.dart';
import '../utils/date_utils.dart';
import 'dart:async';
import '../services/widget_service.dart';
import '../dialogs/widget_promo_dialog.dart';
import '../utils/date_utils.dart';
import 'package:flutter/services.dart';
import '../utils/streak_util.dart';
import '../dialogs/streak_dialog.dart';
import 'package:provider/provider.dart';
import '../services/workout_plan_service.dart';
import 'face_workout_screen.dart';
import 'food_detail_screen.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';
import '../widgets/nutrition_card.dart';
import 'subscription_screen.dart';
import '../services/subscription_handler.dart';
import 'settings_screen.dart';
import '../widgets/special_offer_dialog.dart';


// Add a global flag to control animations based on device capability
bool useSimplifiedAnimations = false;

class HomeScreen extends StatefulWidget {
  final GlobalKey<_HomeScreenState>? stateKey;
  
  const HomeScreen({Key? key, this.stateKey}) : super(key: key);
  
  // Public method to refresh data
  void refreshData() {

    _HomeScreenState.instance?.refreshData();
  }

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // User data
  Map<String, dynamic>? _userDetails;
  Map<String, dynamic>? _nutritionPlan;
  bool _isLoading = true;
  
  // Initialize _selectedDate properly to avoid future dates
  DateTime _selectedDate = DateTime.now();

  // Food data
  List<NutritionInfo> _recentlyEaten = [];
  Map<String, double> _consumedNutrition = {
    'calories': 0.0,
    'protein': 0.0,
    'carbs': 0.0,
    'fat': 0.0,
  };

  // Exercise data
  List<Exercise> _recentExercises = [];
  double _caloriesBurned = 0.0;
  Map<String, double> _nutritionBurned = {
    'protein': 0.0,
    'carbs': 0.0,
    'fat': 0.0,
  };

  // Google Health data
  bool _isGoogleHealthConnected = false;
  Map<String, dynamic> _healthData = {
    'steps': 0,
    'activeMinutes': 0,
    'caloriesBurned': 0,
    'distanceKm': 0.0,
    'heartRate': 0,
  };
  Map<String, dynamic> _aiActivityAnalysis = {
    'caloriesBurned': 0,
    'proteinBurned': 0,
    'fatBurned': 0,
    'carbsBurned': 0,
    'activityLevel': 'Unknown',
    'hydrationNeeded': 0.0,
  };
  Map<DateTime, int> _weeklySteps = {};
  bool _isLoadingHealthData = false;

  // Services
  // Remove FoodLogService instance since we'll use FoodHiveService directly

  // Design constants
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final double _cardElevation = 0.5; // Subtle elevation
  final EdgeInsets _cardPadding = const EdgeInsets.all(16);
  final BoxShadow _boxShadow = BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 10,
    spreadRadius: 0,
    offset: const Offset(0, 4),
  );

  // Add page controller for swipable nutrition/health activity
  late PageController _pageController;
  int _currentPage = 0;

  // Static instance for accessing state from the widget
  static _HomeScreenState? instance;

  // Add this new state variable
  bool _isNutritionCardExpanded = false;

  double _userWeight = 70.0;
  double _userHeight = 170.0;
  int _userAge = 25;
  String _userGender = 'male';
  String _userActivityLevel = 'moderate';
  String _userGoal = 'maintain';

  List<NutritionInfo> _foodLogs = [];
  List<Exercise> _exerciseLogs = [];

  // Add somewhere near the top of class state declarations
  int _currentStreak = 0;
  List<bool> _weeklyLogging = List.filled(7, false);

  final FoodHiveService _foodHiveService = FoodHiveService();
  late String _formattedDate;
  String _greeting = '';

  // Using AppColors instead of local color variables
  // IMPORTANT: This file needs to be updated to use global AppColors instead of local color constants
  // For now keeping local variables for compatibility, but they should be replaced with:
  // _primaryColor → AppColors.primary
  // _textColor → AppColors.textPrimary  
  // _lightTextColor → AppColors.textSecondary
  // _backgroundColor → AppColors.background
  // _cardColor → AppColors.cardBackground
  // _accentColor → AppColors.primary or AppColors.warning
  
  // Define local color variables to maintain compatibility for now
  final Color _primaryColor = AppColors.primary;
  final Color _accentColor = AppColors.warning;
  final Color _backgroundColor = AppColors.background;
  final Color _cardColor = AppColors.cardBackground;
  final Color _textColor = AppColors.textPrimary;
  final Color _lightTextColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
       Posthog().screen(
      screenName: 'Home Screen',
    );
    // Register the static instance for external refresh
    _HomeScreenState.instance = this;
    
    // Initialize loading state
    _isLoading = true;
    
    // Create tab controller for the nutrition details
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Initialize page controller
    _pageController = PageController();

    // Initialize date and load data
    _initializeSelectedDate().then((_) {
      _loadData();
      _detectHardwareCapabilities();
      _loadStreakData().then((_) {
        _checkAndShowStreakDialog(); // Add this line to check and show streak dialog
      });
    });

    _setGreeting();
    _formattedDate = DateFormat('EEEE, MMMM d').format(_selectedDate);
  }

  // Initialize _selectedDate from SharedPreferences using AppDateUtils
  Future<void> _initializeSelectedDate() async {
    try {
      // Always set the initial date to today when app opens
      final today = AppDateUtils.getToday();

      setState(() {
        _selectedDate = today;
      });

      // Save today's date to preferences
      await AppDateUtils.saveSelectedDate(today);

  

      // Ensure ExerciseHiveService is initialized
      await ExerciseHiveService.init();

      // Load initial exercise data for the selected date
      final exercises = ExerciseHiveService.getExercisesForDate(today);

    } catch (e) {
      final today = AppDateUtils.getToday();
      setState(() {
        _selectedDate = today;
      });

    }
  }

  void _detectHardwareCapabilities() {
    try {
      // Try to detect if the device has OpenGL issues based on platform
      if (Platform.isWindows || Platform.isLinux) {
        // More likely to have OpenGL issues on these platforms
        setState(() {
          useSimplifiedAnimations = true;
        });
      }
    } catch (e) {

      useSimplifiedAnimations = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // This method adds animation only if device capabilities allow it
  Widget _animateIfPossible(Widget child,
      {double begin = 0.05, double end = 0}) {
    if (useSimplifiedAnimations) {
      return child;
    } else {
      return child.animate().fadeIn().slideX(
            begin: begin,
            end: end,
            curve: Curves.easeOutQuad,
          );
    }
  }

  // Load app data
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

      // Convert UserDetails to map for easier access
      final userMap = {
        'height': userDetails.height,
        'weight': userDetails.weight,
        'birthDate': userDetails.birthDate,
        'isMetric': userDetails.isMetric,
        'workoutsPerWeek': userDetails.workoutsPerWeek,
        'weightGoal': userDetails.weightGoal,
        'targetWeight': userDetails.targetWeight,
        'gender': userDetails.gender,
        'motivationGoal': userDetails.motivationGoal,
        'dietType': userDetails.dietType,
        'weightChangeSpeed': userDetails.weightChangeSpeed,
      };

      // Load nutrition plan from Hive
      final nutritionPlan = await NutritionService.getNutritionPlan();

      final foodLogs = await FoodHiveService.getFoodsForDate(_selectedDate);
     

      // Debug print all food logs to verify data
      if (foodLogs.isNotEmpty) {
 
        for (int i = 0; i < foodLogs.length; i++) {
          final food = foodLogs[i];
          final timestamp = food.additionalInfo['timestamp'] ?? 'unknown';

        }
      } else {

      }


      final exerciseLogs =
          await ExerciseHiveService.getExercisesForDate(_selectedDate);
     

      // Debug print all exercise logs to verify data
      if (exerciseLogs.isNotEmpty) {

        for (int i = 0; i < exerciseLogs.length; i++) {
          final exercise = exerciseLogs[i];
        }

      }

      // Calculate total calories and macronutrients burned from exercises
      final totalCaloriesBurned = exerciseLogs.fold(
          0.0, (sum, exercise) => sum + exercise.caloriesBurned);
          
      final totalProteinBurned = exerciseLogs.fold(
          0.0, (sum, exercise) => sum + exercise.proteinBurned);
          
      final totalCarbsBurned = exerciseLogs.fold(
          0.0, (sum, exercise) => sum + exercise.carbsBurned);
          
      final totalFatBurned = exerciseLogs.fold(
          0.0, (sum, exercise) => sum + exercise.fatBurned);

      // Store burned nutrients for display
      final nutritionBurned = {
        'protein': totalProteinBurned,
        'carbs': totalCarbsBurned,
        'fat': totalFatBurned,
      };

      // Calculate net nutrition (consumed - burned) for the day
      final totalNutrition = {
        'calories':
            foodLogs.fold(0.0, (sum, food) => sum + (food.calories ?? 0)) - totalCaloriesBurned,
        'protein': 
            foodLogs.fold(0.0, (sum, food) => sum + (food.protein ?? 0)) - totalProteinBurned,
        'carbs': 
            foodLogs.fold(0.0, (sum, food) => sum + (food.carbs ?? 0)) - totalCarbsBurned,
        'fat': 
            foodLogs.fold(0.0, (sum, food) => sum + (food.fat ?? 0)) - totalFatBurned,
      };

      if (mounted) {
        setState(() {
          _userDetails = userMap;
          _nutritionPlan = nutritionPlan;
          _recentlyEaten = foodLogs;
          _recentExercises = exerciseLogs;
          _consumedNutrition = totalNutrition;
          _caloriesBurned = totalCaloriesBurned;
          _nutritionBurned = nutritionBurned;
          _isLoading = false;
        });

        
        // Update widget data and show widget promo after loading data
        _updateWidgetAndShowPromo();
      }

      // Force update the home screen widget with latest data
      _updateHomeScreenWidget();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
   

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Method to update the widget
  Future<void> _updateHomeScreenWidget() async {
    try {
      // Update widget with latest nutrition data
      final result = await WidgetService.forceRefreshWidget();
      
      if (result && mounted) {
        _showWidgetUpdateSuccess();
      }
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }
  
  // Show a temporary success message when widget is updated
  void _showWidgetUpdateSuccess() {

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh data if we haven't loaded it already
    if (_isLoading) {
      _loadData();
    }
  }

  Future<void> _checkGoogleHealthConnection() async {
    try {
      final isConnected = await GoogleHealthService.isConnected();

      setState(() {
        _isGoogleHealthConnected = isConnected;
      });

      if (isConnected) {
        _loadGoogleHealthData();
      }
    } catch (e) {
      debugPrint('Error checking Google Health connection: $e');
    }
  }

  Future<void> _connectGoogleHealth() async {
    setState(() {
      _isLoadingHealthData = true;
    });

    try {
      // Use the real GoogleHealthService implementation with Sahha
      final success = await GoogleHealthService.connect();

      setState(() {
        _isGoogleHealthConnected = success;
      });

      if (success) {
        await _loadGoogleHealthData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to health services successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to connect to health services. Please check app permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error connecting to health services: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to health services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingHealthData = false;
      });
    }
  }

  Future<void> _loadGoogleHealthData() async {
    setState(() {
      _isLoadingHealthData = true;
    });

    try {
      // Get today's health data from Sahha integration
      final healthData = await GoogleHealthService.getTodayHealthData();

      // Get weekly steps data
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weeklySteps =
          await GoogleHealthService.getStepsForDateRange(weekStart, weekEnd);

      // Use AI to analyze activity impact on nutrition
      final aiAnalysis = await GoogleHealthService.analyzeActivityWithAI(
          healthData, _userDetails);

      setState(() {
        _healthData = healthData;
        _weeklySteps = weeklySteps;
        _aiActivityAnalysis = aiAnalysis;
        _isLoadingHealthData = false;
      });
    } catch (e) {
      debugPrint('Error loading health data: $e');
      setState(() {
        _isLoadingHealthData = false;
      });
    }
  }

  bool _hasRequiredUserDetails() {
    return _userDetails != null &&
        _userDetails!['height'] != null &&
        _userDetails!['weight'] != null &&
        _userDetails!['birthDate'] != null &&
        _userDetails!['workoutsPerWeek'] != null &&
        _userDetails!['weightGoal'] != null &&
        _userDetails!['targetWeight'] != null;
  }

  Future<void> _recalculateNutrition() async {
    if (!_hasRequiredUserDetails()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cannot calculate nutrition plan: missing user details'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get nutrition plan from Hive instead of calculating again
      final nutritionData = await NutritionService.getNutritionPlan();

      if (nutritionData == null) {
        // If no nutrition plan exists, calculate a new one
        final newNutritionData = await NutritionService.recalculateNutrition();
        if (newNutritionData != null) {
          // Convert to Map<String, int> for proper type handling
          final processedData = {
            'dailyCalories': (newNutritionData['dailyCalories'] as num).toInt(),
            'protein': (newNutritionData['protein'] as num).toInt(),
            'carbs': (newNutritionData['carbs'] as num).toInt(),
            'fats': (newNutritionData['fats'] as num).toInt(),
          };

          // Save the processed data
          await NutritionService.saveNutritionPlan(processedData);

          setState(() {
            _nutritionPlan = processedData;
            _isLoading = false;
          });
        } else {
          throw Exception('Failed to calculate nutrition plan');
        }
      } else {
      setState(() {
        _nutritionPlan = nutritionData;
        _isLoading = false;
      });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition plan updated!')),
      );
    } catch (e) {
     
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating nutrition plan: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update _selectDate method to use AppDateUtils
  void _selectDate(DateTime date) async {
   // debugPrint('Date selected in HomeScreen: ${date.toIso8601String()}');
    
    // Validate and clean the date using AppDateUtils
    final cleanDate = AppDateUtils.validateDate(date);
    
    setState(() {
      _selectedDate = cleanDate;
    });
    
    // Save using AppDateUtils
    final success = await AppDateUtils.saveSelectedDate(cleanDate);

    if (success) {
    // Show toast notification with selected date
   
    }

    // Reload all data for the selected date
    _loadData();
  }

  String _getWeightGoalText() {
    if (_userDetails == null) return '';

    final goal = _userDetails!['weightGoal'] as String?;
    if (goal == 'gain') return 'Gain Weight';
    if (goal == 'lose') return 'Lose Weight';
    return 'Maintain Weight';
  }

  void _navigateToScanFood() async {
    // Directly navigate to ScanFoodScreen without checking premium status
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanFoodScreen(
          onFoodLogged: () {
            if (mounted) {
              _loadFoodData();
            }
          },
        ),
      ),
    );
  }

  void _navigateToFoodDatabase() async {
    // Directly navigate to FoodDatabaseScreen without checking premium status
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDatabaseScreen(
          selectedDate: _selectedDate,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadFoodData();
      }
    });
  }

  void _navigateToWorkoutPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WorkoutPlansScreen()),
    ).then((_) {
      // Refresh data when returning from workout plans screen
      setState(() {});
    });
  }

  Future<void> _navigateToExerciseLogging() async {
    // Validate the selected date using AppDateUtils
    final validatedDate = AppDateUtils.validateDate(_selectedDate);

    // If the date changed (was in the future), update state and SharedPreferences
    if (validatedDate != _selectedDate) {
      setState(() {
        _selectedDate = validatedDate;
      });
      await AppDateUtils.saveSelectedDate(validatedDate);
    }
    

    
    // Display a toast with the date being used
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Using date: ${AppDateUtils.formatDateForDisplay(_selectedDate)}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
    
    // Navigate to exercise logging screen
    final bool? exerciseAdded = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseLoggingScreen(
          selectedDate: _selectedDate,
          onExerciseAdded: () {
            // This callback will be triggered when an exercise is added
            _loadData();
          },
        ),
      ),
    );
    
    // Refresh data when returning if exercise was added
    if (exerciseAdded == true) {
      _loadData();
    }
  }

  List<Widget> _buildDaySelectors() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Show current date, 1 upcoming date, and 6 previous dates (total 8 dates)
    final int daysBefore = 6; // 6 days before
    final int daysAfter = 1; // 1 day after
    final List<Widget> dayWidgets = [];

    // Previous days, current day, and one upcoming day
    for (int i = -daysBefore; i <= daysAfter; i++) {
      final date = today.add(Duration(days: i));
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      final isSelected = date.day == _selectedDate.day &&
          date.month == _selectedDate.month &&
          date.year == _selectedDate.year;
      
      // Identify future dates (will be shown but unselectable)
      final isFutureDate = date.isAfter(today);

      // Determine container colors based on state
      final containerColor = isSelected
          ? AppColors.primary
          : (isToday ? AppColors.primary.withOpacity(0.05) : Colors.white);

      final borderColor = isSelected
          ? AppColors.primary
          : (isToday
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15));

      final textColor = isSelected
          ? Colors.white
          : (isFutureDate
              ? AppColors.textSecondary.withOpacity(0.4)
              : (isToday ? AppColors.primary : AppColors.textPrimary));

      dayWidgets.add(
        Expanded(
          child: GestureDetector(
        onTap: isFutureDate ? null : () => _selectDate(date),
        child: Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 2), // Very small margin
          decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(8), // Smaller border radius
                border: Border.all(
                    color: borderColor,
                    width: isSelected || isToday ? 1.5 : 1.0),
          ),
          child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Ensure column takes minimum height
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  // Day of week - just first character
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 1),
                    child: Text(
                      DateFormat('E').format(date)[0], // Just first letter
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  // Day number
              Container(
                    width: 24,
                    height: 24,
                decoration: BoxDecoration(
                      shape: BoxShape.circle,
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                          : (isToday
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent),
                ),
                    child: Center(
                child: Text(
                        date.day.toString(),
                  style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
                  ),

                  // Minimal indicator for today or future
                  SizedBox(
                    height: 10,
                    child: isFutureDate
                        ? Icon(Icons.block,
                            size: 6, color: Colors.grey.withOpacity(0.3))
                        : (isToday
                            ? Container(
                                margin: const EdgeInsets.only(top: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                                  color:
                                      isSelected ? Colors.white : AppColors.primary,
                                ),
                              )
                            : const SizedBox()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return dayWidgets;
  }

  Widget _buildSwipableSection() {
    // Get screen height to make panel responsive
    final screenHeight = MediaQuery.of(context).size.height;

    return _buildNutritionPanel();
  }

  Widget _buildWorkoutPlanPanel() {
    return FutureBuilder<WorkoutPlan?>(
      future: WorkoutPlanService.getCurrentDayPlan(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildWorkoutPlanLoading();
        }

        // Check if we need to generate a new plan (for demo purposes)
        if (!snapshot.hasData) {
          return _buildEmptyWorkoutPlanPanel();
        }

        // We have a workout plan
        final workoutPlan = snapshot.data!;

        return _buildWorkoutPlanView(workoutPlan);
      },
    );
  }

  Widget _buildWorkoutPlanLoading() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading your workout plan...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkoutPlanPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Workout Plan Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Let\'s create a personalized workout plan based on your goals and fitness level.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _isLoadingHealthData = true;
                  });

                  try {
                    await WorkoutPlanService.generateAndSaveWorkoutPlan();
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error generating workout plan: $e')),
                    );
                  } finally {
                    setState(() {
                      _isLoadingHealthData = false;
                    });
                  }
                },
                icon: _isLoadingHealthData
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.fitness_center),
                label: Text(_isLoadingHealthData
                    ? 'Generating...'
                    : 'Generate Workout Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildWorkoutPlanView(WorkoutPlan plan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Workout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
                    Text(
                      'Complete your daily exercises',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.calendar_month, color: AppColors.primary),
                  onPressed: _navigateToWorkoutPlans,
                  tooltip: 'View all workout plans',
                ),
              ],
            ),
          ),
          _buildWorkoutSummaryCard(plan),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _navigateToWorkoutPlans,
              icon: Icon(Icons.fitness_center),
              label: Text('View All Exercises'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildWorkoutSummaryCard(WorkoutPlan plan) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 1.0,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.03),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.fitness_center,
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
                        plan.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              plan.difficultyLevel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (plan.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                plan.description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWorkoutStatItem(
                  icon: Icons.timer_outlined,
                  value: '${plan.estimatedDurationMinutes}',
                  label: 'Minutes',
                  color: Colors.blue.shade600,
                ),
                _buildWorkoutStatItem(
                  icon: Icons.local_fire_department_outlined,
                  value: '${plan.estimatedCaloriesBurn}',
                  label: 'Calories',
                  color: Colors.orange.shade600,
                ),
                _buildWorkoutStatItem(
                  icon: Icons.fitness_center_outlined,
                  value: '${plan.exercises.length}',
                  label: 'Exercises',
                  color: Colors.green.shade600,
                ),
                _buildWorkoutStatItem(
                  icon: Icons.emoji_events_outlined,
                  value: '+50',
                  label: 'Points',
                  color: Colors.amber.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildWorkoutStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesList(WorkoutPlan plan) {
    // Calculate whether we need to show all exercises or a limited number
    int exercisesToShow = _currentPage == 1
        ? plan.exercises.length // Show all when workout panel is active
        : math.min(2, plan.exercises.length); // Limit when in summary view

    return Column(
      children: [
        ...plan.exercises
            .take(exercisesToShow)
            .map((exercise) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildExerciseCard(exercise, plan.id),
                ))
            .toList(),

        // If we're limiting exercises and there are more, show a "See all" indicator
        if (_currentPage != 1 && plan.exercises.length > exercisesToShow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '+ ${plan.exercises.length - exercisesToShow} more exercises',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseCard(WorkoutExercise exercise, String planId) {
    final bool isCompleted = exercise.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.fitness_center,
            color: isCompleted ? Colors.green : AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          exercise.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${exercise.sets} sets',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${exercise.reps} reps',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (exercise.duration != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      exercise.duration!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isCompleted
            ? IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: Colors.orange,
                onPressed: () async {
                  await WorkoutPlanService.markExerciseCompleted(
                      planId, exercise.name, false);
                  setState(() {});
                },
                tooltip: 'Mark as incomplete',
              )
            : IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.green,
                onPressed: () async {
                  await WorkoutPlanService.markExerciseCompleted(
                      planId, exercise.name, true);
                  setState(() {});
                },
                tooltip: 'Mark as complete',
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  exercise.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to perform',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise.instructions,
                        style: TextStyle(
                          fontSize: 13,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern circular macro indicator with percentage
  Widget _buildMacroPieChart(
      String label, double consumed, double target, Color color) {
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            children: [
              // Background circle
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color.withOpacity(0.2)),
                ),
              ),
              // Progress circle
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(percentage * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 8,
                        color: _lightTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${consumed.toInt()} / ${target.toInt()}g',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionPanel() {
    if (_nutritionPlan == null || _nutritionPlan!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: _cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: _borderRadius,
            ),
            child: Padding(
              padding: _cardPadding,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No nutrition plan available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your profile to get personalized nutrition recommendations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _recalculateNutrition,
                    icon: Icon(Icons.refresh),
                    label: Text('Update Nutrition Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // Get goal values from nutrition plan
      final targetCalories = (_nutritionPlan!['dailyCalories'] as num).toInt();
      final targetProtein = (_nutritionPlan!['protein'] as num).toInt();
      final targetCarbs = (_nutritionPlan!['carbs'] as num).toInt();
      final targetFat = (_nutritionPlan!['fats'] as num).toInt();
      
      // Calculate raw consumed values (before subtracting burned nutrients)
      final consumedCalories = _recentlyEaten.fold(0.0, (sum, food) => sum + food.calories);
      final consumedProtein = _recentlyEaten.fold(0.0, (sum, food) => sum + food.protein);
      final consumedCarbs = _recentlyEaten.fold(0.0, (sum, food) => sum + food.carbs);
      final consumedFat = _recentlyEaten.fold(0.0, (sum, food) => sum + food.fat);

      // Calculate burned nutrients from exercises
      double totalBurnedCalories = _caloriesBurned;
      double totalBurnedProtein = _nutritionBurned['protein'] ?? 0.0;
      double totalBurnedCarbs = _nutritionBurned['carbs'] ?? 0.0;
      double totalBurnedFat = _nutritionBurned['fat'] ?? 0.0;
      
      // Return the nutrition card without any extra containers or padding
      return NutritionCard(
        calories: consumedCalories,
        caloriesGoal: targetCalories.toDouble(),
        carbs: consumedCarbs,
        carbsGoal: targetCarbs.toDouble(),
        protein: consumedProtein,
        proteinGoal: targetProtein.toDouble(),
        fat: consumedFat,
        fatGoal: targetFat.toDouble(),
        caloriesBurned: totalBurnedCalories,
        streak: _currentStreak,
        selectedDate: _selectedDate,
        onPreviousDate: () {
          // Go to previous day
          setState(() {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          });
          // Refresh data for the selected date
          _loadDataForDate(_selectedDate);
        },
        onNextDate: () {
          // Don't allow navigating to future dates
          final today = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          
          // Check if selected date is before today
          final selectedDayOnly = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );
          
          if (selectedDayOnly.isBefore(today)) {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            });
            // Refresh data for the selected date
            _loadDataForDate(_selectedDate);
          }
        },
        onStreakTap: _showStreakDialog,
        onTap: () {
          // Any tap action you want to implement
        },
      );
    } catch (e) {
      return Center(
        child: Text('Error loading nutrition data: $e'),
      );
    }
  }

  Widget _buildDetailItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getIntensityColor(IntensityLevel intensity) {
    switch (intensity) {
      case IntensityLevel.low:
        return Colors.green;
      case IntensityLevel.medium:
        return Colors.orange;
      case IntensityLevel.high:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Color _getExerciseColor(ExerciseType type) {
    final String typeName = type.name.toLowerCase();
    if (typeName.contains('run')) return Colors.green;
    if (typeName.contains('weight') || typeName.contains('lifting'))
      return Colors.deepPurple;
    if (typeName.contains('swim')) return Colors.cyan;
    if (typeName.contains('cycle') || typeName.contains('bike'))
      return Colors.blue;
    if (typeName.contains('yoga')) return Colors.indigo;
    if (typeName.contains('walk')) return Colors.teal;
    return _primaryColor;
  }

  // Add weekly steps chart widget
  Widget _buildWeeklyStepsChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
            color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Steps',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 16),
            // Placeholder for steps chart
            Container(
              height: 180,
              child: Center(
                child: Text('Step data will appear here'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Define responsive constants
    final bool isSmallScreen = screenWidth < 360;
    final bool isLargeScreen = screenWidth > 600;
    final bool isTablet = screenWidth > 768;
    
    return WillPopScope(
      onWillPop: () async {
        return false; // Prevent going back from home screen
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Row(
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _navigateToSettings,
                icon: Icon(Icons.person_rounded, color: AppColors.primary),
                tooltip: 'Settings',
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          toolbarHeight: 60,
        ),
        body: _isLoading
            ? _buildLoadingView()
            : SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Nutrition panel at the top with no padding
                    _buildNutritionPanel(),
                    
                    // Remove the date navigation bar
                    
                    // Face Workout Card
                    _buildFaceWorkoutCard(),

                    // Special offer card - only visible for non-premium users
                    FutureBuilder<bool>(
                      future: SubscriptionHandler.isPremium(),
                      builder: (context, snapshot) {
                        // If still loading or user has premium, don't show the card
                        if (snapshot.connectionState == ConnectionState.waiting ||
                            snapshot.data == true) {
                          return const SizedBox.shrink();
                        }
                        
                        // User doesn't have premium, show the special offer card
                        return _buildSpecialOfferCard();
                      },
                    ),

                    // Today's food section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM d').format(_selectedDate) ==
                                    DateFormat('MMMM d').format(DateTime.now())
                                ? 'Today\'s food'
                                : 'Food for ${DateFormat('MMMM d').format(_selectedDate)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _navigateToScanFood,
                            icon: Icon(Icons.camera_alt,
                                color: _primaryColor, size: 18),
                            label: Text(
                              'Add Food',
                              style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Food items or empty state
                    if (_recentlyEaten.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 0.0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 20),
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.restaurant_outlined,
                                    size: 35,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  DateFormat('MMMM d').format(_selectedDate) ==
                                          DateFormat('MMMM d')
                                              .format(DateTime.now())
                                          ? 'No meals logged today'
                                          : 'No meals logged for ${DateFormat('MMMM d').format(_selectedDate)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Track your nutrition by logging your meals and keeping your diet on target',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _lightTextColor,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _navigateToScanFood,
                                        icon: const Icon(Icons.camera_alt,
                                            size: 18),
                                        label: const Text('Take Photo'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _navigateToFoodDatabase,
                                        icon:
                                            const Icon(Icons.search, size: 18),
                                        label: const Text('Browse Foods'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: _primaryColor,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                                color: _primaryColor
                                                    .withOpacity(0.5),
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _recentlyEaten
                            .map((food) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _buildFoodItem(food),
                                ))
                            .toList(),
                      ),

                    // Recent exercises section
                    _buildRecentExercisesSection(),

                    // Bottom padding
                    SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
            width: 100,
            height: 100,
                    decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                            ),
                        ],
                      ),
                child: Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                        color: _primaryColor,
                  strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          Text(
            'Loading your health data...',
            style: TextStyle(
              color: _textColor,
                fontSize: 18,
              fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
            'Preparing your personalized dashboard',
                style: TextStyle(
                color: _lightTextColor,
            fontSize: 14,
          ),
        ),
      ],
      ),
    );
  }

  // Public method to refresh data
  void refreshData() {


    // Ensure we're not trying to update state if widget is unmounted
    if (mounted) {
      // Clear existing data to avoid stale info
      setState(() {
        _isLoading = true;
      });

      // Load fresh data
      _loadData();

    }
  }

  // Get a greeting based on the time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Get an icon based on the time of day
  IconData _getTimeBasedIcon() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return Icons.nightlight_round;
    } else if (hour < 12) {
      return Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      return Icons.wb_sunny;
    } else if (hour < 21) {
      return Icons.wb_twilight;
    } else {
      return Icons.nightlight_round;
    }
  }

  // Build a mini stat display for the dashboard
  Widget _buildMiniStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _lightTextColor,
          ),
        ),
      ],
    );
  }

  // Updates widget data without showing widget promo dialog
  Future<void> _updateWidgetAndShowPromo() async {
    // Update widget data if available
    try {
      await WidgetService.updateNutritionWidget();
      // No longer showing any widget promo dialog
    } catch (e) {

    }
  }

  // Add this method to the _HomeScreenState class
  Future<void> _loadStreakData() async {
    try {
      final streakData = await StreakUtil.getStreakData();
      setState(() {
        _currentStreak = streakData['currentStreak'];
        _weeklyLogging = List<bool>.from(streakData['weeklyLogging']);
      });
    } catch (e) {

    }
  }

  // Add this method to show streak dialog
  void _showStreakDialog() {
    showDialog(
      context: context,
      builder: (context) => StreakDialog(
        currentStreak: _currentStreak,
        weeklyLogging: _weeklyLogging,
      ),
    ).then((value) {
      if (value == 'add_food') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScanFoodScreen()),
        ).then((_) {
          // Refresh data after returning from food logging
          _loadData();
          _loadStreakData();
        });
      }
    });
  }

  // Add a streak indicator to the UI in the header section
  // Find and modify the header section in the build method where it makes sense to add the streak UI
  // For example, you could add it near the date selector or user stats area

  // Add this widget to your UI somewhere appropriate, like in the header area
  Widget _buildStreakIndicator() {
    return GestureDetector(
      onTap: _showStreakDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
              const Color(0xFFFF9966),
              const Color(0xFFFF5E62),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              '$_currentStreak',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Find the header section and add the streak indicator
  // For example, add it to the header row containing the date selector

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  // Face Workout Card UI implementation
  Widget _buildFaceWorkoutCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isNarrow = screenWidth < 340;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Updated to light blue gradient
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF82C8E6), // Light blue from image
            Color(0xFF3A95C8), // Darker blue from image
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => const FaceWorkoutScreen()
              ),
            );
          },
          // Reduce padding to make the card more compact
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Left side: Face icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Right side: Text and button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Text section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            "Face Workouts",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          
                          // Description - shorter
                          Text(
                            "Tone facial muscles",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      
                      // Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FaceWorkoutScreen()
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "SCAN",
                            style: TextStyle(
                              color: Color(0xFF3A95C8), // Updated to match blue theme
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  // Helper methods for face workout card
  Widget _buildFeatureBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        text,
          style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
    ),
  );
}

  // Add this new method to check and show streak dialog
  Future<void> _checkAndShowStreakDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString('last_streak_dialog_date');
    final today = DateTime.now().toString().split(' ')[0]; // Get just the date part

    if (lastShownDate != today) {
      // First time today, show dialog
      if (mounted) {
        await prefs.setString('last_streak_dialog_date', today);
        _showStreakDialog();
      }
    }
  }

  // Build the special offer card with green gradient
  Widget _buildSpecialOfferCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF9C4), // Light yellow
            Color(0xFFFFD54F), // Amber/gold color
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Show special offer dialog when clicked
            showSpecialOfferDialog(
              context,
              title: "50% OFF",
              subtitle: "Limited time offer! Upgrade now and save 50% on your premium subscription.",
              forceShow: true, // Always show regardless of when it was last shown
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Left side: Special offer icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Color(0xFFFF9800), // Orange
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Right side: Text and button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Text section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            "Special Offer",
                            style: TextStyle(
                              color: Color(0xFF955100), // Dark orange/brown
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          
                          // Description - shorter
                          const Text(
                            "Premium at 50% off",
                            style: TextStyle(
                              color: Color(0xFFAA6600), // Medium brown
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      
                      // Button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800), // Orange button
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextButton(
                          onPressed: () {
                            // Show special offer dialog when button is clicked
                            showSpecialOfferDialog(
                              context,
                              title: "50% OFF",
                              subtitle: "Limited time offer! Upgrade now and save 50% on your premium subscription.",
                              forceShow: true, // Always show regardless of when it was last shown
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "GET NOW",
                            style: TextStyle(
                              color: Colors.white, // White text for better contrast
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  Future<void> _loadFoodData() async {
    final foods = await FoodHiveService.getFoodsForDate(_selectedDate);
    setState(() {
      _recentlyEaten = foods;
      _updateConsumedNutrition();
    });
  }

  void _updateConsumedNutrition() {
    setState(() {
      _consumedNutrition = {
        'calories': _recentlyEaten.fold(0.0, (sum, food) => sum + food.calories),
        'protein': _recentlyEaten.fold(0.0, (sum, food) => sum + food.protein),
        'carbs': _recentlyEaten.fold(0.0, (sum, food) => sum + food.carbs),
        'fat': _recentlyEaten.fold(0.0, (sum, food) => sum + food.fat),
      };
    });
    
    // Also update the widget whenever consumption data changes
    WidgetService.updateNutritionWidget();
  }

  // Add this compact horizontal macro row
  Widget _buildCompactHorizontalMacroRow(String title, String valueText, int consumed, int target, Color color) {
    final double percentage = (consumed / target).clamp(0.0, 1.0);
    
    return Row(
      children: [
        // Title
        SizedBox(
          width: 45, // Even more compact
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11, // Even smaller font
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        
        // Progress bar
        Expanded(
          child: Container(
            height: 4, // Even shorter height
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * percentage,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Value text
        SizedBox(width: 5), // Even less spacing
        Text(
          valueText,
          style: TextStyle(
            fontSize: 10, // Even smaller font
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // New macro card widget
  Widget _buildMacroCard(String title, int consumed, int target, Color color, IconData icon) {
    final double percentage = (consumed / target).clamp(0.0, 1.0);
    final int percentDisplay = (percentage * 100).round();
    
    return Container(
      width: 70, // Reduced width from 85
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress indicator with icon and percentage
          Stack(
            alignment: Alignment.center,
            children: [
              // Circular progress
              Container(
                width: 46, // Reduced size from 56
                height: 46, // Reduced size from 56
                child: CircularProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 3, // Thinner stroke from 4
                ),
              ),
              // Icon container
              Container(
                width: 34, // Reduced size from 42
                height: 34, // Reduced size from 42
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: 14, // Reduced from 16
                    ),
                    SizedBox(height: 1),
                    Text(
                      "$percentDisplay%",
                      style: TextStyle(
                        fontSize: 7, // Reduced from 8
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3), // Reduced space from 4
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 8, // Reduced from 9
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 1),
          // Value
          Text(
            "0/${target}g",
            style: TextStyle(
              fontSize: 8, // Reduced from 9
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog before deleting food item
  void _showDeleteConfirmation(NutritionInfo food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Food Item'),
        content: Text('Are you sure you want to delete "${food.foodName}"?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), // Reduced corners
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (food.additionalInfo.containsKey('timestamp')) {
                await FoodHiveService.deleteFood(food.additionalInfo['timestamp']);
                _loadFoodData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${food.foodName} deleted'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(12), // Reduced margin
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Reduced corners
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Date navigation bar widget (extracted from nutrition panel)
  Widget _buildDateNavigationBar() {
    return Container(
      margin: EdgeInsets.only(top: 0, bottom: 8),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous day button
          IconButton(
            icon: Icon(Icons.chevron_left, color: _primaryColor.withOpacity(0.8), size: 24),
            onPressed: () {
              _selectDate(_selectedDate.subtract(Duration(days: 1)));
            },
          ),
          
          // Date display
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, color: _primaryColor, size: 16),
                SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMM').format(_selectedDate).toUpperCase(),
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Next day button
          IconButton(
            icon: Icon(Icons.chevron_right, color: _primaryColor.withOpacity(0.8), size: 24),
            onPressed: () {
              // Don't allow selecting future dates
              final tomorrow = DateTime.now().add(Duration(days: 1));
              if (_selectedDate.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
                _selectDate(_selectedDate.add(Duration(days: 1)));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(NutritionInfo food) {
    final timeString = food.additionalInfo.containsKey('timestamp')
        ? DateFormat('h:mm a')
            .format(DateTime.parse(food.additionalInfo['timestamp']))
        : 'Today';

    final String? imagePath = food.additionalInfo.containsKey('imagePath')
        ? food.additionalInfo['imagePath']
        : null;

    Widget foodItem = Container(
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12), // Reduced corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardColor, _cardColor.withOpacity(0.95)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12), // Reduced corners
        child: InkWell(
          borderRadius: BorderRadius.circular(12), // Reduced corners
          onTap: () {
            // View food details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailScreen(
                  food: food,
                  selectedDate: _selectedDate,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _loadFoodData();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(10), // Reduced padding
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10), // Reduced corners
                      child: imagePath != null && imagePath.isNotEmpty
                          ? Image.file(
                              File(imagePath),
                              width: 60, // Reduced size
                              height: 60, // Reduced size
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFoodImagePlaceholder();
                              },
                            )
                          : _buildFoodImagePlaceholder(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1), // Reduced padding
                      decoration: BoxDecoration(
                        color: _cardColor.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6), // Reduced radius
                          bottomRight: Radius.circular(10), // Reduced radius
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 8, // Reduced size
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10), // Reduced spacing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              food.foodName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                                fontSize: 14, // Reduced size
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, size: 16, color: _primaryColor), // Smaller icon
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FoodDetailScreen(
                                        food: food,
                                        selectedDate: _selectedDate,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _loadFoodData();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 2), // Reduced spacing
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 16, color: Colors.red), // Smaller icon
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _showDeleteConfirmation(food);
                                },
                              ),
                              const SizedBox(width: 2), // Reduced spacing
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2), // Reduced padding
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8), // Reduced corners
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${food.calories.round()} cal',
                                  style: TextStyle(
                                    fontSize: 10, // Reduced size
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5), // Reduced spacing
                      Row(
                        children: [
                          _buildNutrientBadge(Icons.fitness_center_outlined,
                              '${food.protein.round()}g', Colors.blue),
                          const SizedBox(width: 4), // Reduced spacing
                          _buildNutrientBadge(Icons.grain_outlined,
                              '${food.carbs.round()}g', Colors.green),
                          const SizedBox(width: 4), // Reduced spacing
                          _buildNutrientBadge(Icons.water_drop_outlined,
                              '${food.fat.round()}g', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return foodItem;
  }
  
  Widget _buildFoodImagePlaceholder() {
    return Container(
      width: 60, // Reduced size
      height: 60, // Reduced size
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10), // Reduced corners
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Icon(
        Icons.restaurant,
        color: _lightTextColor,
        size: 24, // Reduced size
      ),
    );
  }

  Widget _buildNutrientBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8), // Reduced corners
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(
            icon,
            size: 10, // Reduced size
            color: color,
          ),
          const SizedBox(width: 3), // Reduced spacing
          Text(
            text,
            style: TextStyle(
              fontSize: 9, // Reduced size
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExercisesSection() {
    // Get the date string to display in the title
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && 
                    _selectedDate.month == now.month && 
                    _selectedDate.day == now.day;
    
    final String dateText = isToday 
        ? 'Today\'s Exercises' 
        : 'Exercises - ${DateFormat('MMM d').format(_selectedDate)}';

    // Ensure _recentExercises is initialized
    if (_recentExercises == null) {
      _recentExercises = [];
    }

    // Filter exercises to show only those matching the selected date
    final exercisesForSelectedDate = _recentExercises.where((exercise) {
      return exercise.date.year == _selectedDate.year &&
             exercise.date.month == _selectedDate.month &&
             exercise.date.day == _selectedDate.day;
    }).toList();

    // Limit to 3 most recent exercises for display
    final displayExercises = exercisesForSelectedDate.length > 3
        ? exercisesForSelectedDate.sublist(0, 3)
        : exercisesForSelectedDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: _primaryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _navigateToExerciseLogging,
                  icon: Icon(
                    Icons.add,
                    color: _primaryColor,
                    size: 16,
                  ),
                  label: Text(
                    'Add Exercise',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (exercisesForSelectedDate.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: _borderRadius,
                boxShadow: [_boxShadow],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center_outlined,
                      size: 48,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      DateFormat('MMMM d').format(_selectedDate) ==
                              DateFormat('MMMM d').format(DateTime.now())
                          ? 'No exercises logged today'
                          : 'No exercises logged for ${DateFormat('MMMM d').format(_selectedDate)}',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _navigateToExerciseLogging,
                      child: Text(
                        'Add an exercise',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: displayExercises.map((exercise) {
                // Format date
                final dateFormatted = DateFormat('MMM d, yyyy').format(exercise.date);
                // Format intensity
                String intensityText = '';
                switch (exercise.intensity) {
                  case IntensityLevel.low:
                    intensityText = 'Low';
                    break;
                  case IntensityLevel.medium:
                    intensityText = 'Medium';
                    break;
                  case IntensityLevel.high:
                    intensityText = 'High';
                    break;
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: _borderRadius,
                    boxShadow: [_boxShadow],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: _borderRadius,
                    child: InkWell(
                      borderRadius: _borderRadius,
                      onTap: () {
                        // Navigate to exercise detail view
                        // Temporarily remove navigation to fix compile error
                        _loadData(); // Just refresh data for now
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row with icon, title, and date
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getExerciseColor(exercise.type).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    exercise.type.icon,
                                    color: _getExerciseColor(exercise.type),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.type.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateFormatted,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _lightTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getIntensityColor(exercise.intensity).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    intensityText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getIntensityColor(exercise.intensity),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Duration and calories row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.timer_outlined,
                                    '${exercise.durationMinutes} min',
                                    _primaryColor,
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.local_fire_department,
                                    '${exercise.caloriesBurned} cal',
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Nutrients burned row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.fitness_center,
                                    '${exercise.proteinBurned.toStringAsFixed(1)}g protein',
                                    Colors.red.shade400,
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    Icons.water_drop,
                                    '${exercise.fatBurned.toStringAsFixed(1)}g fat',
                                    Colors.blue.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 400))
                .slideY(
                  begin: 0.1,
                  end: 0,
                  curve: Curves.easeOutQuad,
                  duration: const Duration(milliseconds: 400),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Add this method to handle navigation to demo screen
  void _navigateToNutritionCardDemo() {
    Navigator.of(context).pushNamed('/nutrition_card_demo');
  }

  // Method to load data for the selected date
  Future<void> _loadDataForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load food logs for the specific date
      final foodLogs = await FoodHiveService.getFoodsForDate(date);
      
      // Load exercise logs for the specific date
      final exerciseLogs = await ExerciseHiveService.getExercisesForDate(date);
      
      // Calculate total nutrition for the day
      final totalNutrition = {
        'calories': foodLogs.fold(0.0, (sum, food) => sum + (food.calories ?? 0)),
        'protein': foodLogs.fold(0.0, (sum, food) => sum + (food.protein ?? 0)),
        'carbs': foodLogs.fold(0.0, (sum, food) => sum + (food.carbs ?? 0)),
        'fat': foodLogs.fold(0.0, (sum, food) => sum + (food.fat ?? 0)),
      };

      // Calculate total calories burned from exercises
      final totalCaloriesBurned = exerciseLogs.fold(
          0.0, (sum, exercise) => sum + exercise.caloriesBurned);

      if (mounted) {
        setState(() {
          _recentlyEaten = foodLogs;
          _recentExercises = exerciseLogs;
          _consumedNutrition = totalNutrition;
          _caloriesBurned = totalCaloriesBurned;
          _isLoading = false;
          
          // Update formatted date for display
          _formattedDate = DateFormat('EEEE, MMMM d').format(date);
          
          // Update greeting if date is today
          if (_isToday(date)) {
            _setGreeting();
          } else {
            _greeting = 'Historical Data';
          }
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Helper method to check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}
