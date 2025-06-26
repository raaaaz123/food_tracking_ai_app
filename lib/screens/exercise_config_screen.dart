import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_utils.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class ExerciseConfigScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Exercise) onSave;

  const ExerciseConfigScreen({
    super.key,
    required this.exercise,
    required this.onSave,
  });

  @override
  State<ExerciseConfigScreen> createState() => _ExerciseConfigScreenState();
}

class _ExerciseConfigScreenState extends State<ExerciseConfigScreen> {
  late IntensityLevel _selectedIntensity;
  late int _durationMinutes;
  late String _notes;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with values from the passed exercise
    _selectedIntensity = widget.exercise.intensity;
    _durationMinutes = widget.exercise.durationMinutes;
    _notes = widget.exercise.notes ?? '';
    _notesController.text = _notes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Calculate estimated calories based on intensity and duration
  int _calculateCalories() {
    // Base calories per minute based on intensity
    int caloriesPerMinute;
    switch (_selectedIntensity) {
      case IntensityLevel.low:
        caloriesPerMinute = 4;
        break;
      case IntensityLevel.medium:
        caloriesPerMinute = 8;
        break;
      case IntensityLevel.high:
        caloriesPerMinute = 12;
        break;
    }
    return caloriesPerMinute * _durationMinutes;
  }

  // Calculate nutrition data based on current settings
  Map<String, double> _getNutritionData() {
    final caloriesBurned = _calculateCalories();
    final exerciseService = ExerciseService();
    return exerciseService.calculateNutritionBurned(
      exerciseType: widget.exercise.type.name,
      intensity: _selectedIntensity,
      caloriesBurned: caloriesBurned,
    );
  }

  void _saveExercise() async {
    // Calculate calories based on updated values
    await Posthog().capture(
  eventName: 'user_saved_exercise',
);
    int caloriesBurned = _calculateCalories();
    
    // Get nutrition data for the exercise
    final nutritionData = _getNutritionData();

    // Validate the exercise date using AppDateUtils
    final exerciseDate = AppDateUtils.validateDate(widget.exercise.date);
    
   

    // Create a new exercise with updated values
    final updatedExercise = Exercise(
      id: widget.exercise.id,
      type: widget.exercise.type,
      intensity: _selectedIntensity,
      durationMinutes: _durationMinutes,
      date: exerciseDate, // Use validated date
      caloriesBurned: caloriesBurned,
      notes: _notes,
      proteinBurned: nutritionData['protein'] ?? 0.0,
      carbsBurned: nutritionData['carbs'] ?? 0.0,
      fatBurned: nutritionData['fat'] ?? 0.0,
    );

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving exercise...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Call the onSave callback
      await widget.onSave(updatedExercise);
      
      // If we reached here, saving was successful
   
      
      // Short delay to ensure saving completes
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Only pop the screen if we're still mounted
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Handle any errors during saving
     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save exercise: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format date for display using AppDateUtils
    final String dateDisplay = AppDateUtils.formatDateForDisplay(widget.exercise.date);
        
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configure ${widget.exercise.type.name}', 
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'for $dateDisplay',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // Show help dialog or tooltip
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configure your exercise details before adding'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.help_outline, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Exercise info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.exercise.type.icon,
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
                              widget.exercise.type.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.exercise.type.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Nutrition summary
                _buildNutritionSummary(),
                
                const SizedBox(height: 24),
                
                // Intensity selector
                _buildIntensitySelector(),
                
                const SizedBox(height: 24),
                
                // Duration selector
                _buildDurationSelector(),
                
                const SizedBox(height: 24),
                
                // Notes
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
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
                  child: TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'Add any notes about this exercise...',
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      _notes = value;
                    },
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Add exercise button
                ElevatedButton(
                  onPressed: _saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Exercise',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntensitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Intensity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildIntensityOption(
                title: 'Low',
                icon: Icons.directions_walk,
                color: AppColors.info,
                intensity: IntensityLevel.low,
                description: 'Light effort',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildIntensityOption(
                title: 'Medium',
                icon: Icons.directions_run,
                color: AppColors.success,
                intensity: IntensityLevel.medium,
                description: 'Moderate effort',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildIntensityOption(
                title: 'High',
                icon: Icons.flash_on,
                color: AppColors.warning,
                intensity: IntensityLevel.high,
                description: 'Maximum effort',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntensityOption({
    required String title,
    required IconData icon,
    required Color color,
    required IntensityLevel intensity,
    required String description,
  }) {
    final isSelected = _selectedIntensity == intensity;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIntensity = intensity;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
                color: isSelected ? null : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _durationMinutes <= 5 
                          ? Colors.grey.withOpacity(0.1) 
                          : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _durationMinutes <= 5
                          ? null
                          : () {
                              setState(() {
                                _durationMinutes -= 5;
                              });
                            },
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppColors.primary,
                      disabledColor: Colors.grey.withOpacity(0.3),
                      iconSize: 18,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_durationMinutes min',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _durationMinutes += 5;
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      color: AppColors.primary,
                      iconSize: 18,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.grey.withOpacity(0.1),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    elevation: 3,
                  ),
                  overlayColor: AppColors.primary.withOpacity(0.2),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                ),
                child: Slider(
                  value: _durationMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  onChanged: (value) {
                    setState(() {
                      _durationMinutes = value.round();
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('5 min', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('120 min', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionSummary() {
    final nutritionData = _getNutritionData();
    final calories = _calculateCalories();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Estimated Burn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNutrientInfo(
                icon: Icons.local_fire_department,
                value: '$calories',
                label: 'Calories',
                color: AppColors.warning,
              ),
              _buildNutrientInfo(
                icon: Icons.fitness_center,
                value: '${nutritionData['protein']?.toStringAsFixed(1) ?? "0.0"}g',
                label: 'Protein',
                color: AppColors.error,
              ),
              _buildNutrientInfo(
                icon: Icons.grain,
                value: '${nutritionData['carbs']?.toStringAsFixed(1) ?? "0.0"}g',
                label: 'Carbs',
                color: AppColors.warning,
              ),
              _buildNutrientInfo(
                icon: Icons.water_drop,
                value: '${nutritionData['fat']?.toStringAsFixed(1) ?? "0.0"}g',
                label: 'Fat',
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutrientInfo({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 