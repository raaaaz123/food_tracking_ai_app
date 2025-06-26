import 'package:flutter/material.dart';
import '../services/nutrition_service.dart';
import '../constants/app_colors.dart';

class AdjustGoalsScreen extends StatefulWidget {
  const AdjustGoalsScreen({super.key});

  @override
  State<AdjustGoalsScreen> createState() => _AdjustGoalsScreenState();
}

class _AdjustGoalsScreenState extends State<AdjustGoalsScreen> {
  Map<String, dynamic>? _nutritionPlan;
  bool _isLoading = true;
  bool _hasChanges = false;

  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Add listeners to track changes
    _caloriesController.addListener(_onFieldChanged);
    _proteinController.addListener(_onFieldChanged);
    _carbsController.addListener(_onFieldChanged);
    _fatsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!mounted) return;

    // Compare current values with original values to detect changes
    if (_nutritionPlan != null) {
      final currentCalories = int.tryParse(_caloriesController.text) ?? 0;
      final currentProtein = int.tryParse(_proteinController.text) ?? 0;
      final currentCarbs = int.tryParse(_carbsController.text) ?? 0;
      final currentFats = int.tryParse(_fatsController.text) ?? 0;

      final originalCalories = _nutritionPlan!['dailyCalories'] as int? ?? 0;
      final originalProtein = _nutritionPlan!['protein'] as int? ?? 0;
      final originalCarbs = _nutritionPlan!['carbs'] as int? ?? 0;
      final originalFats = _nutritionPlan!['fats'] as int? ?? 0;

      final hasChanged = currentCalories != originalCalories ||
          currentProtein != originalProtein ||
          currentCarbs != originalCarbs ||
          currentFats != originalFats;

      if (hasChanged != _hasChanges) {
        setState(() {
          _hasChanges = hasChanged;
        });
      }
    }
  }

  @override
  void dispose() {
    _caloriesController.removeListener(_onFieldChanged);
    _proteinController.removeListener(_onFieldChanged);
    _carbsController.removeListener(_onFieldChanged);
    _fatsController.removeListener(_onFieldChanged);

    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nutritionPlan = await NutritionService.getNutritionPlan();

      if (!mounted) return;

      setState(() {
        _nutritionPlan = nutritionPlan;
        _isLoading = false;
      });

      if (nutritionPlan != null) {
        _caloriesController.text =
            (nutritionPlan['dailyCalories'] as int? ?? 0).toString();
        _proteinController.text =
            (nutritionPlan['protein'] as int? ?? 0).toString();
        _carbsController.text =
            (nutritionPlan['carbs'] as int? ?? 0).toString();
        _fatsController.text = (nutritionPlan['fats'] as int? ?? 0).toString();
      }
    } catch (e) {
   
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading nutrition plan: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  bool get _isValid {
    // Check that all values are valid numbers greater than 0
    final calories = int.tryParse(_caloriesController.text) ?? 0;
    final protein = int.tryParse(_proteinController.text) ?? 0;
    final carbs = int.tryParse(_carbsController.text) ?? 0;
    final fats = int.tryParse(_fatsController.text) ?? 0;

    return calories > 0 && protein > 0 && carbs > 0 && fats > 0;
  }

  Future<void> _saveGoals() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _nutritionPlan ??= {};

      final updatedNutrition = Map<String, dynamic>.from(_nutritionPlan!);
      updatedNutrition['dailyCalories'] =
          int.tryParse(_caloriesController.text) ?? 0;
      updatedNutrition['protein'] = int.tryParse(_proteinController.text) ?? 0;
      updatedNutrition['carbs'] = int.tryParse(_carbsController.text) ?? 0;
      updatedNutrition['fats'] = int.tryParse(_fatsController.text) ?? 0;

      // Convert to Map<String, int> for saveNutritionPlan
      final processedData = {
        'dailyCalories': int.tryParse(_caloriesController.text) ?? 0,
        'protein': int.tryParse(_proteinController.text) ?? 0,
        'carbs': int.tryParse(_carbsController.text) ?? 0,
        'fats': int.tryParse(_fatsController.text) ?? 0,
      };

      await NutritionService.saveNutritionPlan(processedData);

      if (!mounted) return;

      setState(() {
        _nutritionPlan = updatedNutrition;
        _isLoading = false;
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nutrition goals updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
     
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goals: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _autoGenerateGoals() async {
    // Show confirmation dialog
    final shouldRecalculate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Auto Generate Goals',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will recalculate your nutrition goals based on your profile information. Continue?',
          style: TextStyle(
            color: AppColors.textPrimary,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldRecalculate != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get previously calculated nutritional plan from NutritionService
      final nutritionPlan = await NutritionService.recalculateNutrition();

      if (!mounted) return;

      if (nutritionPlan != null) {
        _caloriesController.text =
            (nutritionPlan['dailyCalories'] as int? ?? 0).toString();
        _proteinController.text =
            (nutritionPlan['protein'] as int? ?? 0).toString();
        _carbsController.text =
            (nutritionPlan['carbs'] as int? ?? 0).toString();
        _fatsController.text = (nutritionPlan['fats'] as int? ?? 0).toString();

        setState(() {
          _nutritionPlan = nutritionPlan;
          _hasChanges = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Goals auto-generated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
 

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error auto-generating goals: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive adjustments
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSmallScreen = screenSize.height < 700;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Adjust Goals',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isSmallScreen ? 20 : 24, // Smaller font on small screens
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
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
                    'Loading nutrition plan...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              // Use SafeArea to respect system UI
              bottom: false, // Don't pad bottom since we'll handle it manually
              child: Column(
                children: [
                  // Main content with scrolling
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isSmallScreen ? 12 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              'Customize Your Goals',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 4 : 8),
                            Text(
                              'Adjust your daily nutrition targets',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Goal items
                            _buildGoalItem(
                              title: 'Calorie goal',
                              icon: Icons.local_fire_department,
                              color: AppColors.warning,
                              controller: _caloriesController,
                              unit: 'kcal',
                            ),
                            _buildGoalItem(
                              title: 'Protein goal',
                              icon: Icons.fitness_center,
                              color: AppColors.error,
                              controller: _proteinController,
                            ),
                            _buildGoalItem(
                              title: 'Carb goal',
                              icon: Icons.grain,
                              color: AppColors.warning,
                              controller: _carbsController,
                            ),
                            _buildGoalItem(
                              title: 'Fat goal',
                              icon: Icons.water_drop,
                              color: AppColors.info,
                              controller: _fatsController,
                            ),
                            SizedBox(height: isSmallScreen ? 20 : 32),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom buttons container - fixed at bottom
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 20, 
                      right: 20,
                      top: 12,
                      // Add extra padding at the bottom to account for system navigation
                      bottom: 12 + bottomPadding + 8, // Extra 8px safety margin
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withOpacity(0.05),
                          offset: const Offset(0, -2),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: isSmallScreen ? 48 : 54,
                          child: OutlinedButton(
                            onPressed: _autoGenerateGoals,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                              ),
                            ),
                            child: Text(
                              'Auto Generate Goals',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 14 : 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        SizedBox(
                          width: double.infinity,
                          height: isSmallScreen ? 48 : 54,
                          child: ElevatedButton(
                            onPressed:
                                (_isValid && _hasChanges) ? _saveGoals : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                              ),
                              disabledBackgroundColor:
                                  AppColors.textSecondary.withOpacity(0.3),
                            ),
                            child: Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 14 : 16,
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
    );
  }

  Widget _buildGoalItem({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    String unit = 'g',
    double progress = 0.7,
  }) {
    // Check screen size for responsive adjustments
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 50 : 60,
            height: isSmallScreen ? 50 : 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 24 : 28,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title == 'Calorie goal' ? 'kcal' : unit,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
