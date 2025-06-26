import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import '../models/workout_plan.dart' as workout_model;
import '../services/workout_plan_service.dart';
import '../widgets/exercise_image.dart';
import '../services/ai_workout_service.dart';
import '../screens/exercise_execution_screen.dart';
import '../constants/app_colors.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final workout_model.WorkoutPlan plan;
  const WorkoutDetailScreen({Key? key, required this.plan}) : super(key: key);
  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _isGeneratingImage = false;
  bool _isStartingWorkout = false;
  workout_model.WorkoutExercise? _currentGeneratingExercise;
  
  // Track expanded state of each exercise
  Map<String, bool> _expandedExercises = {};
  
  @override
  void initState() {
    super.initState();
    // Initialize all exercises as collapsed
    for (var exercise in widget.plan.exercises) {
      _expandedExercises[exercise.name] = false;
    }
  }
  
  // Toggle expansion state of an exercise
  void _toggleExerciseExpansion(String exerciseName) {
    setState(() {
      _expandedExercises[exerciseName] = !(_expandedExercises[exerciseName] ?? false);
    });
  }

  Future<void> _startWorkout() async {
    setState(() {
      _isStartingWorkout = true;
    });

    try {
      // Navigate to a new screen for exercise execution
      final completed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseExecutionScreen(plan: widget.plan),
        ),
      );
      
      // If the workout was completed successfully
      if (completed == true) {
        // Mark the workout as completed
        widget.plan.isCompleted = true;
        
        // Calculate points earned
        int totalPoints = 0;
        for (var exercise in widget.plan.exercises) {
          if (exercise.isCompleted) {
            totalPoints += exercise.pointsPerSet * exercise.sets;
          }
        }
        widget.plan.pointsEarned = totalPoints;
        
        // Save the updated plan
        await WorkoutPlanService.updatePlan(widget.plan);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout completed! You earned $totalPoints points.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start workout: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isStartingWorkout = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientForTargetArea(widget.plan.targetArea);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.plan.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Header with plan info
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientColors[0].withOpacity(0.1), gradientColors[1].withOpacity(0.1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: gradientColors[0],
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plan.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInfoBadge(
                                Icons.timer,
                                '${widget.plan.estimatedDurationMinutes} min',
                                gradientColors[0],
                              ),
                              _buildInfoBadge(
                                Icons.local_fire_department,
                                '${widget.plan.estimatedCaloriesBurn} cal',
                                gradientColors[0],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.plan.difficultyLevel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Quick stats - exercises pending
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        'Exercises',
                        '${widget.plan.exercises.length}',
                        Icons.fitness_center_rounded,
                        gradientColors[0],
                      ),
                      _buildQuickStat(
                        'With Images',
                        '${widget.plan.exercises.where((e) => e.visualInstructions != null && e.visualInstructions!.isNotEmpty).length}',
                        Icons.image,
                        gradientColors[0],
                      ),
                      _buildQuickStat(
                        'Completed',
                        '${widget.plan.exercises.where((e) => e.isCompleted).length}',
                        Icons.check_circle_outline,
                        AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Exercise list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.plan.exercises.length,
              itemBuilder: (context, index) {
                final exercise = widget.plan.exercises[index];
                return _buildExerciseCard(exercise, gradientColors);
              },
            ),
          ),
          
          // Start workout button
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 52),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.05),
                  offset: Offset(0, -3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isStartingWorkout ? null : _startWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradientColors[0],
                  foregroundColor: AppColors.textLight,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isStartingWorkout
                    ? SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(
                          color: AppColors.textLight,
                          strokeWidth: 2,
                        )
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Start Workout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
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

  Widget _buildExerciseCard(workout_model.WorkoutExercise exercise, List<Color> gradientColors) {
    // Get expansion state for this exercise (default to false if not found)
    final isExpanded = _expandedExercises[exercise.name] ?? false;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with exercise name and completion status - now clickable
          InkWell(
            onTap: () => _toggleExerciseExpansion(exercise.name),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: isExpanded ? Radius.zero : Radius.circular(16),
              bottomRight: isExpanded ? Radius.zero : Radius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientColors[0].withOpacity(0.1), gradientColors[1].withOpacity(0.1)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isExpanded ? Radius.zero : Radius.circular(16),
                  bottomRight: isExpanded ? Radius.zero : Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (exercise.isCompleted)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppColors.textPrimary.withOpacity(0.6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (isExpanded)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildExerciseStat(
                        Icons.fitness_center,
                        '${exercise.sets} sets',
                        gradientColors[0],
                      ),
                      _buildExerciseStat(
                        Icons.repeat,
                        '${exercise.reps} reps',
                        gradientColors[0],
                      ),
                      _buildExerciseStat(
                        Icons.timer,
                        exercise.duration,
                        gradientColors[0],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${exercise.pointsPerSet * exercise.sets} pts',
                              style: TextStyle(
                                color: AppColors.accent.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    exercise.instructions,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (exercise.visualInstructions != null && exercise.visualInstructions!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Visual Guide:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Position',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: exercise.visualInstructions != null && exercise.visualInstructions!.length > 0
                                  ? Image.memory(
                                      base64Decode(exercise.visualInstructions![0]),
                                      fit: BoxFit.cover,
                                      height: 120,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error rendering start position image: $error');
                                        return Container(
                                          height: 120,
                                          color: AppColors.surfaceColor,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.broken_image, color: AppColors.textSecondary),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Failed to load image',
                                                  style: TextStyle(color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      height: 120,
                                      color: AppColors.surfaceColor,
                                      child: Center(
                                        child: Text(
                                          'No image available',
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Position',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: exercise.visualInstructions != null && exercise.visualInstructions!.length > 1
                                  ? Image.memory(
                                      base64Decode(exercise.visualInstructions![1]),
                                      fit: BoxFit.cover,
                                      height: 120,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error rendering end position image: $error');
                                        return Container(
                                          height: 120,
                                          color: AppColors.surfaceColor,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.broken_image, color: AppColors.textSecondary),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Failed to load image',
                                                  style: TextStyle(color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      height: 120,
                                      color: AppColors.surfaceColor,
                                      child: Center(
                                        child: Text(
                                          'No image available',
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isGeneratingImage && _currentGeneratingExercise == exercise
                        ? null
                        : () => _generateVisualGuide(exercise),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gradientColors[0],
                      foregroundColor: AppColors.textLight,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isGeneratingImage && _currentGeneratingExercise == exercise
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.textLight,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Generate Visual Guide',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          // If not expanded, show a small preview of exercise details
          if (!isExpanded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center, size: 14, color: gradientColors[0]),
                      SizedBox(width: 4),
                      Text(
                        '${exercise.sets} sets × ${exercise.reps} reps',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${exercise.pointsPerSet * exercise.sets} pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseStat(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateVisualGuide(workout_model.WorkoutExercise exercise) async {
    setState(() {
      _isGeneratingImage = true;
      _currentGeneratingExercise = exercise;
    });

    try {
      print('Step 1: Starting image generation for ${exercise.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating visual guide for ${exercise.name}...'),
          backgroundColor: AppColors.primary,
        )
      );

      print('Step 2: Calling AI service to generate images');
      // Generate images for the exercise
      final updatedExercise = await AIWorkoutService.generateImagesForExercise(exercise);
      
      print('Step 3: Received response from AI service');
      print('Step 4: Image data received: ${updatedExercise.visualInstructions != null ? "${updatedExercise.visualInstructions!.length} images" : "No images"}');
      
      if (updatedExercise.visualInstructions == null || updatedExercise.visualInstructions!.isEmpty) {
        print('Step 5: No images were generated');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate images for ${exercise.name}. Please try again.'),
            backgroundColor: AppColors.error,
          )
        );
        return;
      }
      
      // Find and replace the exercise in the plan
      final exerciseIndex = widget.plan.exercises.indexWhere((e) => e.name == exercise.name);
      if (exerciseIndex != -1) {
        print('Step 6: Updating exercise in workout plan');
        setState(() {
          widget.plan.exercises[exerciseIndex] = updatedExercise;
        });
        
        // Save the updated plan
        print('Step 7: Saving updated plan to storage');
        await WorkoutPlanService.updatePlan(widget.plan);
        
        // Show success message
        print('Step 8: Successfully generated and saved images');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated visual guide for ${exercise.name}'), 
            backgroundColor: AppColors.success,
          )
        );
      }
    } catch (e) {
      print('Error in image generation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate visual guide: ${e.toString()}'),
          backgroundColor: AppColors.error,
        )
      );
    } finally {
      setState(() {
        _isGeneratingImage = false;
        _currentGeneratingExercise = null;
      });
    }
  }
} 