import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../services/exercise_hive_service.dart';
import 'exercise_config_screen.dart';
import 'custom_exercise_screen.dart';
import 'package:intl/intl.dart';
import '../utils/date_utils.dart';

// Debug utility function to show all exercises 


// Debug utility function to clear all exercises
Future<void> _debugClearAllExercises() async {
  try {
    await ExerciseHiveService.clearAllExercises();
   
  } catch (e) {
   
  }
}

class ExerciseLoggingScreen extends StatefulWidget {
  final VoidCallback? onExerciseAdded;
  final DateTime? selectedDate;
  
  const ExerciseLoggingScreen({
    Key? key, 
    this.onExerciseAdded,
    this.selectedDate,
  }) : super(key: key);

  @override
  _ExerciseLoggingScreenState createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<ExerciseLoggingScreen> {
  // Initialize with default value to avoid late initialization error
  DateTime _effectiveDate = AppDateUtils.getToday();
  
  @override
  void initState() {
    super.initState();
    _initializeDate();

       Posthog().screen(
      screenName: 'Exercise logging Screen',
    );
  }
  
  Future<void> _initializeDate() async {
    try {
      DateTime selectedDate;
      
      // Priority 1: Use widget.selectedDate if provided
      if (widget.selectedDate != null) {
        selectedDate = AppDateUtils.validateDate(widget.selectedDate!);
         
        }
      // Priority 2: Load from SharedPreferences
      else {
        selectedDate = await AppDateUtils.getSelectedDate();
            
      }
      
      if (mounted) {
      setState(() {
        _effectiveDate = selectedDate;
      });
        
        // Save the date to SharedPreferences for consistency
        AppDateUtils.saveSelectedDate(_effectiveDate).then((success) {
         
        });
      }
      
    } catch (e) {
      final today = AppDateUtils.getToday();
      setState(() {
        _effectiveDate = today;
      });

    }
  }
  
  final List<ExerciseType> _exerciseTypes = [
    ExerciseType(
      name: 'Run',
      description: 'Jogging, running, or sprinting',
      icon: Icons.directions_run,
    ),
    ExerciseType(
      name: 'Weight lifting',
      description: 'Strength training with weights',
      icon: Icons.fitness_center,
    ),
    ExerciseType(
      name: 'Swimming',
      description: 'Swimming in pool or open water',
      icon: Icons.pool,
    ),
    ExerciseType(
      name: 'Cycling',
      description: 'Biking outdoors or stationary',
      icon: Icons.directions_bike,
    ),
    ExerciseType(
      name: 'Yoga',
      description: 'Yoga, stretching, and mindfulness',
      icon: Icons.self_improvement,
    ),

  ];

  @override
  Widget build(BuildContext context) {
    // Format the date for display
    final String dateText = AppDateUtils.formatDateForDisplay(_effectiveDate);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Exercise Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'For: $dateText',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
       
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                
                const SizedBox(width: 12),
               
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _exerciseTypes.length,
                itemBuilder: (context, index) {
                  // Check if this is the last item (custom exercise)
                  final bool isLastItem = index == _exerciseTypes.length - 1;
                  
                  // Add a divider before the custom exercise item
                  if (isLastItem) {
                    return Column(
                      children: [
                        const SizedBox(height: 4),
                        Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildExerciseTypeCard(_exerciseTypes[index], isCustom: true),
                        ),
                      ],
                    );
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildExerciseTypeCard(_exerciseTypes[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTypeCard(ExerciseType exerciseType, {bool isCustom = false}) {
    final bool isCustomType = exerciseType.isCustom;
    final Color cardColor = isCustomType 
        ? const Color(0xFFF06292) 
        : Theme.of(context).primaryColor;
    
    // Enhanced styling for the custom exercise card
    if (isCustom) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: cardColor.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomExerciseScreen(),
              ),
            );
            
            if (result == true && widget.onExerciseAdded != null) {
              widget.onExerciseAdded!();
            }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cardColor,
                          cardColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      exerciseType.icon,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Custom Exercise',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: cardColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Define your own exercise type and details',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 14,
                      color: cardColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Original styling for regular exercise cards
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Get user's weight for calculations
            final prefs = await SharedPreferences.getInstance();
            final userWeight = prefs.getDouble('user_weight') ?? 70.0;
            
            final exerciseService = ExerciseHiveService();
            
            // Default values
            final intensity = IntensityLevel.medium;
            final durationMinutes = 30;
            
            // Create an exercise with the validated effective date
            final exerciseDate = AppDateUtils.validateDate(_effectiveDate);
            
            // Calculate calories burned
            final caloriesBurned = ExerciseHiveService.calculateCaloriesBurned(
              exerciseType: exerciseType.name,
              intensity: intensity,
              durationMinutes: durationMinutes,
              weightKg: userWeight,
            );
            
            // Calculate nutrition data
            final nutritionData = ExerciseHiveService.calculateNutritionBurned(
              exerciseType: exerciseType.name,
              intensity: intensity,
              caloriesBurned: caloriesBurned,
            );

            // Create an exercise with default values and nutrition data
            final exercise = Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: exerciseType,
              intensity: intensity,
              durationMinutes: durationMinutes,
              date: exerciseDate,
              caloriesBurned: caloriesBurned,
              proteinBurned: nutritionData['protein'] ?? 0.0,
              carbsBurned: nutritionData['carbs'] ?? 0.0,
              fatBurned: nutritionData['fat'] ?? 0.0,
            );

            // Format date for snackbar message
            final dateText = AppDateUtils.formatDateForDisplay(exerciseDate);

            // Navigate to exercise config screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExerciseConfigScreen(
                  exercise: exercise,
                  onSave: _saveExercise,
                ),
              ),
            );
            
            // If exercise was saved successfully, call the callback and pop the screen
            if (result == true) {
             
              // Delay slightly to ensure callback completes
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Return to the previous screen (MainAppScreen) with success
              if (mounted) {
                Navigator.pop(context, true);
              }
            } else {
             
          }
        },
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cardColor.withOpacity(0.8),
                        cardColor.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                ),
                child: Icon(
                  exerciseType.icon,
                    size: 22,
                    color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseType.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exerciseType.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                          fontSize: 12,
                          height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                Icons.arrow_forward_ios,
                    size: 14,
                    color: cardColor,
                  ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _saveExercise(Exercise exercise) async {
    try {
     
      
      await ExerciseHiveService.addExercise(exercise);
      
    
      if (widget.onExerciseAdded != null) {
        widget.onExerciseAdded!();

      }
      
      return true;
    } catch (e) {
     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save exercise: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
