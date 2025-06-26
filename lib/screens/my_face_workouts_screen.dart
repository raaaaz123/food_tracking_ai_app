import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/workout_plan.dart' as workout_model;
import '../models/face_analysis.dart';
import '../services/workout_plan_service.dart';
import '../services/ai_workout_service.dart';
import '../services/subscription_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/workout_detail_screen.dart';
import '../constants/app_colors.dart';

class MyFaceWorkoutsScreen extends StatefulWidget {
  final FaceAnalysis? faceAnalysis;

  const MyFaceWorkoutsScreen({Key? key, this.faceAnalysis}) : super(key: key);

  @override
  State<MyFaceWorkoutsScreen> createState() => _MyFaceWorkoutsScreenState();
}

class _MyFaceWorkoutsScreenState extends State<MyFaceWorkoutsScreen> {
  // Design constants
  final double _cardElevation = 2.0;
  final double _cardBorderRadius = 16.0;
  final double _padMedium = 16.0;

  List<workout_model.WorkoutPlan> _workoutPlans = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
       Posthog().screen(
      screenName: 'My Face Workouts Screen',
    );
  }

  Future<void> _initializeAndLoadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await WorkoutPlanService.init();
      await _loadWorkoutPlans();
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading workout plans: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWorkoutPlans() async {
    try {
      final plans = await WorkoutPlanService.getAllPlans();
      setState(() {
        _workoutPlans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

    }
  }

  Future<void> _handleCreateNewWorkoutPlan() async {
    // First check if face analysis is available to avoid unnecessary subscription checks
    if (widget.faceAnalysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No face analysis available. Please complete a face scan first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
 await Posthog().capture(
      eventName: 'create_new_workout_plan',
    );
    try {
      // Check if user has premium subscription directly without using the navigation helper
      final isPremiumUser = await SubscriptionHandler.isPremium();
      
      if (!isPremiumUser) {
        // Show subscription screen directly
        await SubscriptionHandler.showSubscriptionScreen(
          context, 
          feature: Feature.faceWorkout,
          title: 'Premium Face Workout',
          subtitle: 'Create personalized face workout plans with AI technology',
        );
        return;
      }
      
      // User has premium, proceed with workout creation
      setState(() {
        _isLoading = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creating your personalized workout plan...'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );

      final workoutPlan = await AIWorkoutService.generateWorkoutPlanWithoutImages(widget.faceAnalysis!);
      
      await WorkoutPlanService.savePlan(workoutPlan);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout plan created successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      
      await _loadWorkoutPlans();
    } catch (e) {
      print('Error in workout plan creation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create workout plan. Please try again.'),
            backgroundColor: AppColors.error,
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

  Future<void> _generateImagesForExercise(workout_model.WorkoutPlan plan, workout_model.WorkoutExercise exercise) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generating images for ${exercise.name}...'))
      );
 await Posthog().capture(
      eventName: 'generate_images_for_exercise',
    );
      // Create a new instance of the workout plan
      final updatedPlan = workout_model.WorkoutPlan(
        id: plan.id,
        name: plan.name,
        description: plan.description,
        exercises: List.from(plan.exercises),
        isCompleted: plan.isCompleted,
        date: plan.date,
        difficultyLevel: plan.difficultyLevel,
        estimatedDurationMinutes: plan.estimatedDurationMinutes,
        estimatedCaloriesBurn: plan.estimatedCaloriesBurn,
        targetArea: plan.targetArea,
        pointsEarned: plan.pointsEarned,
        achievementsUnlocked: plan.achievementsUnlocked,
      );

      // Generate images for the exercise
      final updatedExercise = await AIWorkoutService.generateImagesForExercise(exercise);
      
      // Find and replace the exercise in the plan
      final exerciseIndex = updatedPlan.exercises.indexWhere((e) => e.name == exercise.name);
      if (exerciseIndex != -1) {
        updatedPlan.exercises[exerciseIndex] = updatedExercise;
        
        // Save the updated plan
        await WorkoutPlanService.updatePlan(updatedPlan);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully generated images for ${exercise.name}'))
        );
        
        // Refresh workout plans
        setState(() {
          _loadWorkoutPlans();
        });
      }
    } catch (e) {
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate images: ${e.toString()}'))
      );
    }
  }

  void _viewWorkoutDetails(workout_model.WorkoutPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(plan: plan),
      ),
    ).then((_) => _loadWorkoutPlans());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Face Workouts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_workoutPlans.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _showDeleteConfirmationDialog,
            ),
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: _isLoading ? null : _handleCreateNewWorkoutPlan,
          ),
        ],
      ),
      body: _isLoading
          ? _loadingPlaceholder()
          : _workoutPlans.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadWorkoutPlans,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _workoutPlans.length,
                    itemBuilder: (context, index) {
                      final plan = _workoutPlans[index];
                      return _buildWorkoutCard(plan);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.8), AppColors.primaryLight.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.fitness_center,
              size: 64,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Workout Plans Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Build your personalized facial exercises routine',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _handleCreateNewWorkoutPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.textLight,
                padding: EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Create New Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(workout_model.WorkoutPlan plan) {
    final completedExercises = plan.exercises.where((e) => e.isCompleted).length;
    final totalExercises = plan.exercises.length;
    final progress = totalExercises > 0 ? completedExercises / totalExercises : 0.0;
    final gradientColors = _getGradientForTargetArea(plan.targetArea);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _viewWorkoutDetails(plan),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with title and difficulty
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plan.difficultyLevel,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPremiumStat(
                        Icons.fitness_center,
                        '${plan.exercises.length}',
                        'Exercises',
                        gradientColors[0],
                      ),
                      _buildPremiumStat(
                        Icons.timer,
                        '${plan.estimatedDurationMinutes}',
                        'Minutes',
                        gradientColors[0],
                      ),
                      _buildPremiumStat(
                        Icons.local_fire_department,
                        '${plan.estimatedCaloriesBurn}',
                        'Calories',
                        gradientColors[0],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // Progress section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getProgressColor(progress),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(3),
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
        ),
      ),
    );
  }

  Widget _buildPremiumStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2),
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
  
  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return AppColors.success;
    if (progress >= 0.5) return AppColors.warning;
    return AppColors.error;
  }
  
  List<Color> _getGradientForTargetArea(String targetArea) {
    switch (targetArea.toLowerCase()) {
      case 'forehead':
      case 'brow':
        return [AppColors.info, AppColors.info.withOpacity(0.7)]; // Purple to Blue
      case 'eyes':
      case 'eyelid':
        return [AppColors.info, AppColors.info.withOpacity(0.7)]; // Blue
      case 'cheeks':
        return [AppColors.error.withOpacity(0.7), AppColors.error.withOpacity(0.5)]; // Pink
      case 'jaw':
      case 'jawline':
        return [AppColors.success, AppColors.success.withOpacity(0.7)]; // Green
      case 'lips':
      case 'mouth':
        return [AppColors.error, AppColors.error.withOpacity(0.7)]; // Red
      case 'neck':
        return [AppColors.warning, AppColors.warning.withOpacity(0.7)]; // Amber
      default:
        return [AppColors.primary, AppColors.primaryLight]; // Default
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete All Workouts',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete all your workout plans? This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllWorkouts();
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await WorkoutPlanService.deleteAllPlans();
      setState(() {
        _workoutPlans = [];
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All workout plans have been deleted'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete workout plans: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Show snackbar for status updates
  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError 
          ? AppColors.error 
          : isSuccess 
              ? AppColors.success 
              : AppColors.primary,
    ));
  }

  // Widget to show loading state as nice placeholder
  Widget _loadingPlaceholder() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
} 