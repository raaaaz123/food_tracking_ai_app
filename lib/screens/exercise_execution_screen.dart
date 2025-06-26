import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/workout_plan.dart' as workout_model;
import '../services/workout_plan_service.dart';
import '../widgets/exercise_image.dart';
import '../constants/app_colors.dart';
import 'package:flutter/services.dart';

class ExerciseExecutionScreen extends StatefulWidget {
  final workout_model.WorkoutPlan plan;
  
  const ExerciseExecutionScreen({Key? key, required this.plan}) : super(key: key);

  @override
  State<ExerciseExecutionScreen> createState() => _ExerciseExecutionScreenState();
}

class _ExerciseExecutionScreenState extends State<ExerciseExecutionScreen> with TickerProviderStateMixin {
  // Camera controller
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  
  // Exercise tracking
  int currentExerciseIndex = 0;
  workout_model.WorkoutExercise? currentExercise;
  int currentSet = 1;
  int currentRep = 0;
  Timer? exerciseTimer;
  int timerSeconds = 0;
  bool isExerciseStarted = false;
  bool isExerciseCompleted = false;
  bool isRestPeriod = false;
  int restTimeRemaining = 10; // 10 second rest between sets
  Timer? restTimer;
  
  // Workout state persistence
  String? workoutStateKey;
  
  // Animation controllers
  late AnimationController _animationController;
  AnimationController? _instructionsAnimationController;
  // Scrolling
  ScrollController _instructionsScrollController = ScrollController();
  int _lastHighlightedStep = -1;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupAnimations();
    _loadSavedWorkoutState();
       Posthog().screen(
      screenName: 'Execution Screen',
    );
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    if (mounted) {
      _instructionsAnimationController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      // Start the instructions animation immediately
      _instructionsAnimationController?.repeat(reverse: true);
    }
  }
  
  // Override didChangeDependencies to ensure animations are initialized after context is available
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Ensure animation controller is initialized
    if (_instructionsAnimationController == null && mounted) {
      _setupAnimations();
    }
  }
  
  // Override didUpdateWidget to scroll to the current step when rep changes
  @override
  void didUpdateWidget(ExerciseExecutionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-scroll to the current instruction step
    if (isExerciseStarted && currentExercise != null) {
      _scrollToCurrentInstruction();
    }
  }
  
  // Method to auto-scroll to the current instruction
  void _scrollToCurrentInstruction() {
    if (!mounted || currentExercise == null) return;
    
    // Get the instructions
    final instructions = currentExercise!.instructions;
    
    // Only scroll if we have instructions and the rep has changed
    if (instructions.isNotEmpty && _lastHighlightedStep != currentRep) {
      _lastHighlightedStep = currentRep;
      
      // Split instructions into steps
      List<String> steps = [];
      if (instructions.contains('\n')) {
        steps = instructions.split('\n').where((s) => s.trim().isNotEmpty).toList();
      } else if (instructions.contains('.')) {
        steps = instructions.split('.')
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim() + '.')
            .toList();
      } else {
        steps = [instructions];
      }
      
      // Calculate the current step index
      final currentStepIndex = steps.isEmpty ? 0 : (currentRep % steps.length);
      
      // Calculate approximate height of each step (this is an estimation)
      final stepHeight = 60.0; // Average height of a step
      
      // Scroll to the position
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted && _instructionsScrollController.hasClients) {
          _instructionsScrollController.animateTo(
            currentStepIndex * stepHeight,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        // Try to find the front camera
        CameraDescription? frontCamera;
        for (var camera in cameras!) {
          if (camera.lensDirection == CameraLensDirection.front) {
            frontCamera = camera;
            break;
          }
        }
        
        // If front camera is found, use it, otherwise use the first camera
        final cameraToUse = frontCamera ?? cameras![0];
        
        cameraController = CameraController(
          cameraToUse,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        await cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
     
    }
  }
  
  Future<void> _loadSavedWorkoutState() async {
    try {
      workoutStateKey = 'workout_state_${widget.plan.id}';
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString(workoutStateKey!);
      
      if (savedState != null) {
        try {
          final workoutData = jsonDecode(savedState);
          
          // Check if we have proper workout data
          if (workoutData is Map<String, dynamic>) {
            // Update exercise progress state
            setState(() {
              currentExerciseIndex = workoutData['currentExerciseIndex'] ?? 0;
              currentSet = workoutData['currentSet'] ?? 1;
              currentRep = workoutData['currentRep'] ?? 0;
              timerSeconds = workoutData['timerSeconds'] ?? 0;
            });
            
            bool exercisesRestored = false;
            
            // Check if we have a saved plan with exercises
            if (workoutData.containsKey('plan') && 
                workoutData['plan'] is Map<String, dynamic> &&
                workoutData['plan']['exercises'] is List) {
              
              final planData = workoutData['plan'] as Map<String, dynamic>;
              final exercisesData = planData['exercises'] as List;
              
              // Create a deep copy of original exercises for reference
              final List<workout_model.WorkoutExercise> originalExercises = List.from(widget.plan.exercises);
              
              // Always reconstruct exercises from saved data for consistency
              final exercises = exercisesData.map((exerciseData) {
                // Find the corresponding original exercise to ensure we have the latest visual instructions
                final originalExercise = originalExercises.firstWhere(
                  (e) => e.name == exerciseData['name'],
                  orElse: () => workout_model.WorkoutExercise(
                    name: exerciseData['name'] ?? 'Unknown Exercise',
                    description: exerciseData['description'] ?? '',
                    sets: exerciseData['sets'] ?? 3,
                    reps: exerciseData['reps'] ?? 10,
                    duration: exerciseData['duration'] ?? '1 minute',
                    targetMuscles: exerciseData['targetMuscles'] ?? 'Face',
                    instructions: exerciseData['instructions'] ?? '',
                    isCompleted: exerciseData['isCompleted'] ?? false,
                    pointsPerSet: exerciseData['pointsPerSet'] ?? 5,
                  ),
                );
                
                // Use visual instructions from original exercise if available, otherwise from saved data
                List<String>? visualInstructions = originalExercise.visualInstructions;
                if (visualInstructions == null || visualInstructions.isEmpty) {
                  visualInstructions = exerciseData['visualInstructions'] != null 
                    ? List<String>.from(exerciseData['visualInstructions']) 
                    : null;
                }
                
                return workout_model.WorkoutExercise(
                  name: exerciseData['name'] ?? 'Unknown Exercise',
                  description: exerciseData['description'] ?? '',
                  sets: exerciseData['sets'] ?? 3,
                  reps: exerciseData['reps'] ?? 10,
                  duration: exerciseData['duration'] ?? '1 minute',
                  targetMuscles: exerciseData['targetMuscles'] ?? 'Face',
                  instructions: exerciseData['instructions'] ?? '',
                  isCompleted: exerciseData['isCompleted'] ?? false,
                  pointsPerSet: exerciseData['pointsPerSet'] ?? 5,
                  visualInstructions: visualInstructions,
                  visualUrl: originalExercise.visualUrl ?? exerciseData['visualUrl'],
                  localImagePaths: originalExercise.localImagePaths ?? (exerciseData['localImagePaths'] != null 
                    ? List<String>.from(exerciseData['localImagePaths']) 
                    : null),
                );
              }).toList();
              
              // Update the workout plan with the reconstructed exercises
              if (exercises.isNotEmpty) {
                setState(() {
                  widget.plan.exercises.clear();
                  widget.plan.exercises.addAll(exercises.cast<workout_model.WorkoutExercise>());
                  exercisesRestored = true;
                });
              }
            }
            
            // Initialize the current exercise before showing dialog
            if (exercisesRestored && widget.plan.exercises.isNotEmpty) {
              // Make sure currentExerciseIndex is within bounds
              if (currentExerciseIndex >= widget.plan.exercises.length) {
                currentExerciseIndex = 0;
              }
              
              // Set the current exercise
              setState(() {
                currentExercise = widget.plan.exercises[currentExerciseIndex];
              });
              
              // Show dialog to resume workout
              Future.microtask(() => _showResumeWorkoutDialog());
            } else {
              _initializeExercise(); // This will handle the empty exercises case
            }
          } else {
            _initializeExercise();
          }
        } catch (e) {
          _initializeExercise();
        }
      } else {
        // Initialize new workout
        _initializeExercise();
      }
    } catch (e) {
      // Initialize new workout as fallback
      _initializeExercise();
    }
  }
  
  void _showResumeWorkoutDialog() {
    if (!mounted) return;

    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Resume Workout?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You have a workout in progress. Would you like to resume where you left off?'),
              SizedBox(height: 10),
              Text(
                'Progress will be saved automatically.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Make sure we have a valid exercise state before starting new
                if (widget.plan.exercises.isEmpty) {
                  return;
                }
                _initializeExercise(); // Start fresh
              },
              child: Text('Start New'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Check if we have a valid state before resuming
                if (widget.plan.exercises.isEmpty) {
                  return;
                }
                _resumeWorkout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Resume'),
            ),
          ],
        );
      },
    );
  }
  
  void _resumeWorkout() {
  
    // Make sure we have exercises to work with
    if (widget.plan.exercises.isEmpty) {
 
      setState(() {
        currentExercise = null;
      });
      return;
    }
    
    // Validate the current exercise index is within bounds
    if (currentExerciseIndex < 0 || currentExerciseIndex >= widget.plan.exercises.length) {
      // Reset to first exercise if index is out of bounds
    
      currentExerciseIndex = 0;
    }
    
    
    
    // Debug visual instructions
    final exercise = widget.plan.exercises[currentExerciseIndex];
    if (exercise.visualInstructions != null && exercise.visualInstructions!.isNotEmpty) {
     
      if (exercise.visualInstructions!.length > 1) {
       
      }
    } else {
 
    }
    
    // Set the current exercise based on the saved index
    setState(() {
      currentExercise = widget.plan.exercises[currentExerciseIndex];
      isExerciseStarted = false;
      isExerciseCompleted = false;
      isRestPeriod = false;
    });
    
    // Initialize timer for the exercise
    if (exerciseTimer != null) {
      exerciseTimer!.cancel();
    }
    
    exerciseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (isExerciseStarted && !isRestPeriod) {
        setState(() {
          timerSeconds++;
        });
      }
    });
    
    // Save the workout state to ensure it's up to date
    _saveWorkoutState();
  }
  
  void _initializeExercise() {

  
    
    // Make sure we have exercises to work with
    if (widget.plan.exercises.isEmpty) {
    
      setState(() {
        currentExercise = null;
      });
      return;
    }
    
    // Cancel any existing timers
    if (exerciseTimer != null) {
      exerciseTimer!.cancel();
      exerciseTimer = null;
    }
    
    if (restTimer != null) {
      restTimer!.cancel();
      restTimer = null;
    }

    
    setState(() {
      currentExerciseIndex = 0;
      currentSet = 1;
      currentRep = 0;
      timerSeconds = 0;
      currentExercise = widget.plan.exercises[currentExerciseIndex];
      isExerciseStarted = false;
      isExerciseCompleted = false;
      isRestPeriod = false;
    });
    
    // Initialize timer for the exercise
    exerciseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (isExerciseStarted && !isRestPeriod) {
        setState(() {
          timerSeconds++;
        });
      }
    });
    
    // Save the workout state to ensure it's up to date
    _saveWorkoutState();
  }
  
  Future<void> _saveWorkoutState() async {
    if (workoutStateKey == null) return;
    
    try {
      // Do not save if there are no exercises
      if (widget.plan.exercises.isEmpty) {

        return;
      }
      
      // Save both the progress state and a copy of the workout plan
      final workoutData = {
        'currentExerciseIndex': currentExerciseIndex,
        'currentSet': currentSet,
        'currentRep': currentRep,
        'timerSeconds': timerSeconds,
        'lastUpdated': DateTime.now().toIso8601String(),
        'plan': {
          'id': widget.plan.id,
          'name': widget.plan.name,
          'description': widget.plan.description,
          'targetArea': widget.plan.targetArea,
          'exercises': widget.plan.exercises.map((exercise) => {
            'name': exercise.name,
            'description': exercise.description,
            'sets': exercise.sets,
            'reps': exercise.reps,
            'duration': exercise.duration,
            'targetMuscles': exercise.targetMuscles,
            'instructions': exercise.instructions,
            'isCompleted': exercise.isCompleted,
            'pointsPerSet': exercise.pointsPerSet,
            'visualInstructions': exercise.visualInstructions,
            'visualUrl': exercise.visualUrl,
            'localImagePaths': exercise.localImagePaths,
          }).toList(),
        }
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(workoutStateKey!, jsonEncode(workoutData));

    } catch (e) {

    }
  }
  
  void _startExercise() {
    setState(() {
      isExerciseStarted = true;
      timerSeconds = 0;
      currentRep = 0;
      _lastHighlightedStep = -1; // Reset the step tracking for auto-scrolling
    });
    
    // Scroll to the first instruction step
    _scrollToCurrentInstruction();
    
    // Save the workout state
    _saveWorkoutState();
    
    // Start animation
    _animationController.forward();
    
    // Simulate the exercise detection with a timer for demo purposes
    // In a real app, this would use Firebase ML or other facial recognition
    Timer.periodic(Duration(seconds: 3), (timer) {
      if (!isExerciseStarted || isRestPeriod || isExerciseCompleted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        currentRep++;
        
        // Trigger auto-scrolling to current step
        _scrollToCurrentInstruction();
        
        // Save the workout state after each rep
        _saveWorkoutState();
        
        // Trigger animation for successful rep
        _animationController.reset();
        _animationController.forward();
        
        // Check if set is completed
        if (currentRep >= currentExercise!.reps) {
          if (currentSet < currentExercise!.sets) {
            // Start rest period before next set
            _startRestPeriod();
            timer.cancel();
          } else {
            // Complete this exercise
            _completeExercise();
            timer.cancel();
          }
        }
      });
    });
  }
  
  void _startRestPeriod() {
    setState(() {
      isRestPeriod = true;
      restTimeRemaining = 10;
    });
    
    // Save the workout state
    _saveWorkoutState();
    
    restTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        restTimeRemaining--;
      });
      
      if (restTimeRemaining <= 0) {
        timer.cancel();
        setState(() {
          isRestPeriod = false;
          currentSet++;
          currentRep = 0;
        });
        
        // Save the workout state
        _saveWorkoutState();
        
        // Start the next set
        _startExercise();
      }
    });
  }
  
  void _completeExercise() {
    // Mark the current exercise as completed
    final exerciseIndex = widget.plan.exercises.indexWhere((e) => e.name == currentExercise!.name);
    if (exerciseIndex != -1) {
      setState(() {
        widget.plan.exercises[exerciseIndex] = workout_model.WorkoutExercise(
          name: currentExercise!.name,
          description: currentExercise!.description,
          sets: currentExercise!.sets,
          reps: currentExercise!.reps,
          duration: currentExercise!.duration,
          targetMuscles: currentExercise!.targetMuscles,
          instructions: currentExercise!.instructions,
          isCompleted: true,
          pointsPerSet: currentExercise!.pointsPerSet,
          visualInstructions: currentExercise!.visualInstructions,
          visualUrl: currentExercise!.visualUrl,
          localImagePaths: currentExercise!.localImagePaths,
        );
        
        isExerciseCompleted = true;
      });
      
      // Save progress
      WorkoutPlanService.updatePlan(widget.plan);
      
      // Save the workout state
      _saveWorkoutState();
      
      // Show completion dialog after a short delay
      Future.delayed(Duration(seconds: 2), () {
        _showExerciseCompletionDialog();
      });
    }
  }
  
  void _showExerciseCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 64,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Exercise Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '${currentExercise!.name}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${currentExercise!.sets} sets × ${currentExercise!.reps}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Points earned: ${currentExercise!.pointsPerSet * currentExercise!.sets}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentExerciseIndex < widget.plan.exercises.length - 1)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _moveToNextExercise();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Next Exercise'),
                      ),
                    if (currentExerciseIndex == widget.plan.exercises.length - 1)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _completeWorkout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Complete Workout'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _moveToNextExercise() {
    // Save current exercise state
    _saveWorkoutState();
    
    final nextExerciseIndex = currentExerciseIndex + 1;
    if (nextExerciseIndex < widget.plan.exercises.length) {
      setState(() {
        // Reset exercise-specific state variables
        currentRep = 0;
        timerSeconds = 0;
        isExerciseStarted = false;
        isExerciseCompleted = false;
        isRestPeriod = false;

        // Advance to next exercise
        currentExerciseIndex = nextExerciseIndex;
        
        // Retrieve the next exercise
        final nextExercise = widget.plan.exercises[currentExerciseIndex];
        
        // Ensure we have a fresh reference to the exercise
        WorkoutPlanService.getExerciseById(widget.plan.id, nextExercise.name).then((freshExercise) {
          if (freshExercise != null) {
            setState(() {
              // Update the exercise in the plan
              widget.plan.exercises[currentExerciseIndex] = freshExercise;
              // Update current exercise reference
              currentExercise = freshExercise;
            });
          } else {
            // If we can't get a fresh reference, use the one we have
            setState(() {
              currentExercise = nextExercise;
            });
          }
        }).catchError((_) {
          // If we encounter an error, use the exercise we have
          setState(() {
            currentExercise = nextExercise;
          });
        });
      });
      
      // Trigger haptic feedback for exercise change
      HapticFeedback.mediumImpact();
      
      // Show a quick notification for the new exercise
      _showExerciseTransitionMessage();
    } else {
      _completeWorkout();
    }
  }
  
  // Show a transition message for the new exercise
  void _showExerciseTransitionMessage() {
    final exercise = widget.plan.exercises[currentExerciseIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Starting: ${exercise.name}"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green[700],
      ),
    );
  }
  
  Future<void> _completeWorkout() async {

    
    // Clear the saved workout state
    if (workoutStateKey != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(workoutStateKey!);

      } catch (e) {
   
      }
    }
    
    // Cancel any active timers
    if (exerciseTimer != null) {
      exerciseTimer!.cancel();
      exerciseTimer = null;
    }
    
    if (restTimer != null) {
      restTimer!.cancel();
      restTimer = null;
    }
    
    // Return true to indicate workout was completed
    Navigator.of(context).pop(true);
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
  void dispose() {
    // Save the current workout state before disposing
    if (isExerciseStarted && !isExerciseCompleted) {
      _saveWorkoutState();
    }
    
    cameraController?.dispose();
    exerciseTimer?.cancel();
    restTimer?.cancel();
    _animationController.dispose();
    _instructionsAnimationController?.dispose();
    _instructionsScrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // If currentExercise is null but plan has exercises, initialize it with the first one
    if (currentExercise == null && widget.plan.exercises.isNotEmpty) {
      // Use a future to fix state after this build cycle
      Future.microtask(() {
        setState(() {
          currentExerciseIndex = 0;
          currentExercise = widget.plan.exercises[0];
        });
      });
      
      // Show loading screen instead of "No exercises found"
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: 20),
              Text('Initializing workout...'),
            ],
          ),
        ),
      );
    }
    
    // Original null check
    if (currentExercise == null) {
      return Scaffold(
        body: Center(
          child: Text('No exercises found'),
        ),
      );
    }
    
    final gradientColors = _getGradientForTargetArea(currentExercise!.targetMuscles);
    final hasImages = currentExercise!.visualInstructions != null && 
                      currentExercise!.visualInstructions!.isNotEmpty;
    
    // Cache demo images to prevent rebuilding them when timer updates
    String? startImage, endImage;
    
    // Ensure we safely access the image data with proper error handling
    if (hasImages) {
      if (currentExercise!.visualInstructions!.isNotEmpty) {
        startImage = currentExercise!.visualInstructions![0];
      }
      
      if (currentExercise!.visualInstructions!.length > 1) {
        endImage = currentExercise!.visualInstructions![1];
      }
    }
        
    // Get bottom padding for navigation area
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Reduced camera height (40% of screen instead of 50%)
    final cameraHeight = screenHeight * 0.4;
    final faceGuideSize = screenWidth * 0.65; // Circular face guide size
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top bar with timer and progress - fixed height
            Container(
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => _showExitConfirmationDialog(),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Timer - extract to separate widget to prevent full rebuild
                  _buildTimerWidget(),
                  
                  // Exercise progress
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Exercise ${currentExerciseIndex + 1}/${widget.plan.exercises.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Demo images area - improved layout with rounded corners and better alignment
            Container(
              height: 120, // Slightly increased height for better visibility
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.grey[900]!.withOpacity(0.3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDemoImage(
                    startImage,
                    "Start Position",
                  ),
                  Container(
                    height: 50,
                    child: VerticalDivider(
                      color: Colors.grey[800],
                      thickness: 1,
                      width: 30,
                    ),
                  ),
                  _buildDemoImage(
                    endImage,
                    "End Position",
                  ),
                ],
              ),
            ),
            
            // Exercise name and set info - enhanced design
            Container(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
               
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title with constrained height
                  Container(
                    height: 26,
                    child: Text(
                      currentExercise!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 2),
                  // Set/Rep info with constrained height
                  Container(
                    height: 18,
                    child: Text(
                      'Set $currentSet of ${currentExercise!.sets} • Rep $currentRep of ${currentExercise!.reps}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            // Camera view with circular face guide
            Container(
              height: cameraHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
               
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Camera preview with oval shape
                  ClipOval(
                    child: Container(
                      width: screenWidth * 0.85,
                      height: cameraHeight * 0.92,
                      child: isCameraInitialized && cameraController != null
                        ? OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: Container(
                                width: screenWidth,
                                height: screenWidth * cameraController!.value.aspectRatio,
                                child: CameraPreview(cameraController!),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: gradientColors[0],
                                    strokeWidth: 2,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Initializing camera...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                  ),
                  
                  // Animated oval border (pulsing)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.9, end: 1.0),
                    duration: Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: screenWidth * 0.85 * value,
                        height: cameraHeight * 0.92 * value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                       
                        ),
                      );
                    },
                    onEnd: () {
                      setState(() {
                        // Trigger rebuild to restart animation
                      });
                    },
                  ),
                  
                  // Face guide - additional subtle guidance
                  Positioned(
                    top: cameraHeight * 0.2,
                    child: Container(
                      width: screenWidth * 0.45,
                      height: 1,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  
                  // Instructions text below face guide with improved visibility
                  Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.face,
                              color: Colors.white70,
                              size: 14,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Position your face in the circle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Rest timer overlay
                  if (isRestPeriod)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        width: screenWidth * 0.7,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'REST',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Next set starts in',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 10),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$restTimeRemaining',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
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
            
            // Control buttons area - with improved gradient and better spacing
            Container(
              height: 90,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
               
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!isExerciseStarted)
                    _buildControlButton(
                      'Start',
                      Icons.play_arrow_rounded,
                      AppColors.success,
                      () => _startExercise(),
                    ),
                  if (isExerciseStarted && !isRestPeriod)
                    _buildControlButton(
                      'Rep Done',
                      Icons.check_circle_outline,
                      gradientColors[0],
                      () {
                        // Manually increment rep to simulate the timer-based increment
                        setState(() {
                          currentRep++;
                          // Save the workout state after each rep
                          _saveWorkoutState();
                          
                          // Check if set is completed
                          if (currentRep >= currentExercise!.reps) {
                            if (currentSet < currentExercise!.sets) {
                              // Start rest period before next set
                              _startRestPeriod();
                            } else {
                              // Complete this exercise
                              _completeExercise();
                            }
                          }
                        });
                      },
                    ),
                  if (isExerciseStarted && !isRestPeriod)
                    _buildControlButton(
                      'Skip Set',
                      Icons.skip_next,
                      AppColors.warning,
                      () => _startRestPeriod(),
                    ),
                  if (isExerciseStarted)
                    _buildControlButton(
                      'Finish',
                      Icons.stop_circle_outlined,
                      AppColors.error,
                      () => _showExerciseCompletionDialog(),
                    ),
                ],
              ),
            ),
            
            // Instructions area - improved with curved top corners
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle indicator
                    Container(
                      margin: EdgeInsets.only(top: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _instructionsScrollController,
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Instructions header
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: gradientColors[0].withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: gradientColors[0],
                                    size: 16,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Exercise Instructions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            
                            // Steps with animated dots
                            _buildInstructionSteps(currentExercise!.instructions),
                            
                            // Target muscles
                            SizedBox(height: 16),
                            Text(
                              'Target Muscles: ${currentExercise!.targetMuscles}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            
                            // Duration note
                            SizedBox(height: 8),
                            Text(
                              'Recommended Duration: ${currentExercise!.duration}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            
                            // Extra space at bottom for scrolling
                            SizedBox(height: 30),
                          ],
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
    );
  }
  
  // Add a new method to build the timer widget separately
  Widget _buildTimerWidget() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            _formatTime(timerSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build demo image - optimized for space
  Widget _buildDemoImage(String? imageSource, String label) {
    if (imageSource == null || imageSource.isEmpty) {
      return Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 24, color: Colors.grey[400]),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    try {
      // Safely decode the base64 image
      Uint8List? imageBytes;
      try {
        imageBytes = base64Decode(imageSource);
      } catch (e) {
        // If decoding fails, return placeholder
        return Container(
          width: 120,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 24, color: Colors.red[300]),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      
      return Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  width: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(Icons.error_outline, size: 24, color: Colors.red[300]),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 24, color: Colors.red[300]),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
  
  // Updated control button with better visuals
  Widget _buildControlButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    // Use green background for Start button
    final bool isStartButton = label == 'Start';
    final buttonColor = isStartButton ? AppColors.success : color;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              buttonColor,
              buttonColor.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build instruction steps with dot animation
  Widget _buildInstructionSteps(String instructions) {
    // Split instructions by new lines or periods to create steps
    List<String> steps = [];
    
    // First try to split by line breaks
    if (instructions.contains('\n')) {
      steps = instructions.split('\n').where((s) => s.trim().isNotEmpty).toList();
    } 
    // If no line breaks, try splitting by periods
    else if (instructions.contains('.')) {
      steps = instructions.split('.')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim() + '.')
          .toList();
    }
    // If still no steps, just use the whole text
    else {
      steps = [instructions];
    }
    
    // Get accent color for dots
    final accentColor = currentExercise != null 
        ? _getGradientForTargetArea(currentExercise!.targetMuscles)[0]
        : AppColors.primary;
    
    // Check if animation controller is initialized
    if (_instructionsAnimationController == null) {
      // Return non-animated version if controller is not available
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final isCurrentStep = isExerciseStarted && index == currentRep % steps.length;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Non-animated dot
                Container(
                  margin: EdgeInsets.only(top: 4, right: 10),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentStep
                        ? accentColor
                        : Colors.grey[700],
                  ),
                ),
                // Step text
                Expanded(
                  child: Text(
                    steps[index].trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isCurrentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontWeight: isCurrentStep
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );
    }
    
    // With animation controller
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        // Calculate if this is the current active step
        final isCurrentStep = isExerciseStarted && index == currentRep % steps.length;
        
        // Create a pulsing animation for the active step
        final Animation<double> animation;
        
        try {
          animation = Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: _instructionsAnimationController!,
              curve: Interval(
                (index / steps.length), 
                (index / steps.length) + (1 / steps.length),
                curve: Curves.easeInOut,
              ),
            ),
          );
        } catch (e) {
          // If animation fails, return the step without animation
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Non-animated dot
                Container(
                  margin: EdgeInsets.only(top: 4, right: 10),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentStep
                        ? accentColor
                        : Colors.grey[700],
                  ),
                ),
                // Step text
                Expanded(
                  child: Text(
                    steps[index].trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isCurrentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontWeight: isCurrentStep
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Unique key for each instruction step for auto-scrolling
        final stepKey = GlobalKey();
        
        return Padding(
          key: isCurrentStep ? stepKey : null,
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated dot with pulsing effect
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Container(
                    margin: EdgeInsets.only(top: 4, right: 10),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isExerciseStarted
                          ? accentColor.withOpacity(isCurrentStep ? animation.value : 0.7)
                          : Colors.grey[700],
                      boxShadow: isExerciseStarted && isCurrentStep ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3 * animation.value),
                          blurRadius: 4 * animation.value,
                          spreadRadius: 1 * animation.value,
                        )
                      ] : null,
                    ),
                  );
                }
              ),
              // Step text
              Expanded(
                child: Text(
                  steps[index].trim(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isCurrentStep
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontWeight: isCurrentStep
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
  
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Exit Workout'),
          content: Text('Your progress will be saved. You can resume the workout later.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit workout screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save & Exit'),
            ),
          ],
        );
      },
    );
  }
} 