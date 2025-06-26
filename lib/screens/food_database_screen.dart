import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/popular_food.dart';
import '../models/nutrition_info.dart';
import '../services/food_nutrition_ai_service.dart';
import '../services/food_hive_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../dialogs/widget_promo_dialog.dart';
import 'package:intl/intl.dart';
import '../utils/date_utils.dart';
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Constants for scan limit
const String _freeAnalysisCountKey = 'free_analysis_count';
const int _maxFreeAnalysis = 2;

class FoodDatabaseScreen extends StatefulWidget {
  final DateTime? selectedDate;
  
  const FoodDatabaseScreen({super.key, this.selectedDate});

  @override
  State<FoodDatabaseScreen> createState() => _FoodDatabaseScreenState();
}

class _FoodDatabaseScreenState extends State<FoodDatabaseScreen>
    with SingleTickerProviderStateMixin {
  final List<PopularFood> _popularFoods = PopularFood.getPopularFoods();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _portionsController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = false;
  NutritionInfo? _analysisResult;
  bool _isEditMode = false;
  
  // Add scan count tracking
  int _remainingFreeAnalysis = _maxFreeAnalysis;
  bool _isPremium = false;
  
  // Store effective date to be used for logging food - initialize with today as fallback
  DateTime _effectiveDate = AppDateUtils.getToday();

  // For editing nutrition values
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();

  // Design constants are now using AppColors instead of local variables
  // final Color _primaryColor = const Color(0xFF6C63FF);
  // final Color _backgroundColor = const Color(0xFFF8F9FD);
  // final Color _cardColor = Colors.white;
  // final Color _textColor = const Color(0xFF2D3142);
  // final Color _lightTextColor = const Color(0xFF9E9EAB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
        Posthog().screen(
      screenName: 'Food Database Screen',
    );
    // Initialize date loading
    _initializeDate();
    
    // Load remaining free analysis count and premium status
    _loadAnalysisCount();
    _checkPremiumStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _foodNameController.dispose();
    _ingredientsController.dispose();
    _portionsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingSizeController.dispose();
    super.dispose();
  }

  Future<void> _initializeDate() async {
    try {
      // Always use today's date as the selected date
      final today = AppDateUtils.getToday();
      
      if (mounted) {
        setState(() {
          _effectiveDate = today;
        });
        
        // Ensure the date is saved to SharedPreferences for consistency across screens
        AppDateUtils.saveSelectedDate(_effectiveDate);
      }
    } catch (e) {
      // In case of any error, use today's date
      final today = AppDateUtils.getToday();
      
      if (mounted) {
        setState(() {
          _effectiveDate = today;
        });
      }
    }
  }
  
  
  // Show notification about selected date (similar to HomeScreen)
  void _showDateNotification() {
    if (!mounted) return;
    
    String dateDisplay = AppDateUtils.formatDateForDisplay(_effectiveDate);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing food data for $dateDisplay'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue.shade700,
      ),
    );
    
   
  }

  // Load remaining free scan count from shared preferences
  Future<void> _loadAnalysisCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _remainingFreeAnalysis = prefs.getInt(_freeAnalysisCountKey) ?? _maxFreeAnalysis;
      });
    } catch (e) {
      // If there's an error, default to max free scans
      setState(() {
        _remainingFreeAnalysis = _maxFreeAnalysis;
      });
    }
  }
  
  // Check if user has premium subscription
  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await SubscriptionHandler.isPremium();
      setState(() {
        _isPremium = isPremium;
      });
    } catch (e) {
      // If there's an error, assume user is not premium
      setState(() {
        _isPremium = false;
      });
    }
  }
  
  // Decrement free analysis count
  Future<bool> _useFreeAnalysis() async {
    // Skip the check if user is premium
    if (_isPremium) return true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_freeAnalysisCountKey) ?? _maxFreeAnalysis;
      
      // If no free scans left, show special offer dialog immediately
      if (currentCount <= 0) {
        if (mounted) {
          showSpecialOfferDialog(
            context,
            feature: Feature.foodDatabase,
            title: 'Upgrade to Premium',
            subtitle: 'You\'ve used all your free AI analyses. Upgrade to Premium for unlimited food analysis and premium features!',
            forceShow: true, // Force show the dialog
          );
        }
        return false;
      }
      
      // Decrement count
      currentCount--;
      await prefs.setInt(_freeAnalysisCountKey, currentCount);
      
      if (mounted) {
        setState(() {
          _remainingFreeAnalysis = currentCount;
        });
      }
      
      // If this was the last scan, show special offer dialog but still allow analysis
      if (currentCount == 0 && mounted) {
        // Delay showing dialog until after analysis is complete
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            showSpecialOfferDialog(
              context,
              feature: Feature.foodDatabase,
              title: 'Last Analysis Used',
              subtitle: 'You\'ve used all your free AI analyses. Upgrade to Premium for unlimited access!',
              forceShow: true, // Force show the dialog
            );
          }
        });
      }
      
      return true;
    } catch (e) {
      // In case of error, allow the analysis but don't modify counter
      return true;
    }
  }

  void _analyzeCustomFood() async {
    await Posthog().capture(
  eventName: 'user_click_analyse_withai',
);
    
    if (_foodNameController.text.isEmpty || _portionsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user can use AI analysis
    final canUseAnalysis = await _useFreeAnalysis();
    if (!canUseAnalysis) return;

    setState(() {
      _isLoading = true;
      _analysisResult = null;
      _isEditMode = false;
    });

    try {
      final result = await FoodNutritionAIService.analyzeIngredients(
        foodName: _foodNameController.text,
        ingredients: _ingredientsController.text.isEmpty
            ? _foodNameController.text
            : _ingredientsController.text,
        portions: _portionsController.text,
      );

      setState(() {
        _analysisResult = result;
        _isLoading = false;

        // Set up controllers for editing
        _caloriesController.text = result.calories.toString();
        _proteinController.text = result.protein.toString();
        _carbsController.text = result.carbs.toString();
        _fatController.text = result.fat.toString();
        _servingSizeController.text = result.servingSize;
      });
      
      // Show bottom sheet with results
      _showAddToLogBottomSheet();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showAddToLogBottomSheet() {
    // Create local copy of controllers to edit values
    final caloriesEditController = TextEditingController(text: _caloriesController.text);
    final proteinEditController = TextEditingController(text: _proteinController.text);
    final carbsEditController = TextEditingController(text: _carbsController.text);
    final fatEditController = TextEditingController(text: _fatController.text);
    final servingSizeEditController = TextEditingController(text: _servingSizeController.text);
    
    // Use this to track edit state within the dialog
    bool isEditing = false;
    
    // Define the macro field widget builder function locally
    Widget buildMacroField({
      required BuildContext context,
      required String label,
      required TextEditingController controller,
      required double value,
      required IconData icon,
      required Color color,
      required bool isEditing,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label row with integrated value for more compact UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Label with icon
                Row(
          children: [
            Icon(
              icon,
              color: color,
                      size: 16,
            ),
                    const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                        fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
                  ],
                ),
                // Value display
            isEditing
                  ? Container(
                      width: 65,
                      height: 30,
                  child: TextField(
                    controller: controller,
                        decoration: InputDecoration(
                          suffixText: 'g',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color.withOpacity(0.3)),
                          ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                )
                  : Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${value.toInt()}g',
                  style: TextStyle(
                          fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                        ),
                  ),
                    ),
              ],
                ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Calculate if this is a small screen
          final isSmallScreen = MediaQuery.of(context).size.height < 700;
          
          return Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 
                     MediaQuery.of(context).padding.bottom,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content with scrolling
                SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 90), // Extra bottom padding for the fixed action button
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // Handle
                        Align(
                          alignment: Alignment.center,
                    child: Container(
                            width: 40,
                            height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                        
                        // Page title
                        Padding(
                          padding: const EdgeInsets.only(right: 40, bottom: 20),
                          child: Text(
                            isEditing ? 'Edit Nutrition Values' : 'Food Analysis Results',
                        style: TextStyle(
                              fontSize: isSmallScreen ? 22 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                        ),
                        
                        // Food header card
                  Container(
                          padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade300,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade300.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                              // Food icon
                        Container(
                          padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                                child: Icon(
                                  Icons.restaurant,
                            color: Colors.white,
                                  size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                              
                              // Food name and serving
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _analysisResult!.foodName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              isEditing 
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TextField(
                                    controller: servingSizeEditController,
                                            decoration: InputDecoration(
                                              hintText: 'Serving size',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: InputBorder.none,
                                      isDense: true,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.green.shade700,
                                            ),
                                    ),
                                  )
                                : Text(
                                    'Serving: ${_analysisResult!.servingSize}',
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
                  
                        // Calories card
                  Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                          child: Column(
                      children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                          Icons.local_fire_department,
                                      color: Colors.orange.shade700,
                                      size: 20,
                        ),
                                  ),
                                  const SizedBox(width: 12),
                        Text(
                          'Calories',
                          style: TextStyle(
                                      fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        isEditing
                                    ? Container(
                                        width: 100,
                              child: TextField(
                                controller: caloriesEditController,
                                          decoration: InputDecoration(
                                  isDense: true,
                                            suffixText: 'kcal',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                                            ),
                                ),
                                keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                              ),
                            )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                              '${_analysisResult!.calories.toInt()} kcal',
                              style: TextStyle(
                                            fontSize: 16,
                                fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800,
                                          ),
                              ),
                                      ),
                                ],
                            ),
                      ],
                    ),
                  ),
                  
                        // Macronutrients title
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 4),
                          child: Text(
                    'Macronutrients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                        ),
                  
                        // Macronutrients grid
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.5, // Make grid items more compact
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                  buildMacroField(
                    context: context,
                    label: 'Protein',
                    controller: proteinEditController,
                    value: _analysisResult!.protein,
                    icon: Icons.fitness_center,
                    color: Color(0xFFE91E63),
                    isEditing: isEditing,
                  ),
                  buildMacroField(
                    context: context,
                    label: 'Carbs',
                    controller: carbsEditController,
                    value: _analysisResult!.carbs,
                    icon: Icons.grain,
                    color: Color(0xFFFF9800),
                    isEditing: isEditing,
                  ),
                  buildMacroField(
                    context: context,
                    label: 'Fat',
                    controller: fatEditController,
                    value: _analysisResult!.fat,
                    icon: Icons.water_drop,
                    color: Color(0xFF2196F3),
                    isEditing: isEditing,
                            ),
                            // Empty placeholder to balance grid
                            if (_analysisResult!.ingredients.isEmpty && !isEditing)
                              Container(),
                          ],
                  ),
                  
                  // Ingredients section if available
                        if (_analysisResult!.ingredients.isNotEmpty || isEditing) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                            padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                        children: _analysisResult!.ingredients.map((ingredient) {
                          return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                    color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                        spreadRadius: 0,
                              ),
                                    ],
                            ),
                            child: Text(
                              ingredient,
                              style: TextStyle(
                                      fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  
                        // Extra space at bottom for the fixed button
                        SizedBox(height: 0),
                      ],
                    ),
                  ),
                ),
                
                // Close button positioned at top right
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                
                // Edit/Save button positioned at top right
                Positioned(
                  top: 10,
                  right: 56,
                  child: GestureDetector(
                    onTap: () {
                      if (isEditing) {
                        // Save the edited values
                        try {
                          final calories = double.parse(caloriesEditController.text);
                          final protein = double.parse(proteinEditController.text);
                          final carbs = double.parse(carbsEditController.text);
                          final fat = double.parse(fatEditController.text);
                          
                          // Update the main controllers
                          _caloriesController.text = caloriesEditController.text;
                          _proteinController.text = proteinEditController.text;
                          _carbsController.text = carbsEditController.text;
                          _fatController.text = fatEditController.text;
                          _servingSizeController.text = servingSizeEditController.text;
                          
                          // Update the analysis result
                          _analysisResult = NutritionInfo(
                            foodName: _analysisResult!.foodName,
                            brandName: _analysisResult!.brandName,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            servingSize: servingSizeEditController.text,
                            ingredients: _analysisResult!.ingredients,
                            additionalInfo: _analysisResult!.additionalInfo,
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nutrition values updated'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating values: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          // Don't exit edit mode if there's an error
                          return;
                        }
                      }
                      
                      setSheetState(() {
                        isEditing = !isEditing;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isEditing ? Colors.green : AppColors.primary).withOpacity(0.1),
                        shape: BoxShape.circle,
                          ),
                      child: Icon(
                        isEditing ? Icons.check : Icons.edit,
                        size: 20,
                        color: isEditing ? Colors.green : AppColors.primary,
                      ),
                        ),
                      ),
                ),
                
                // Fixed "Add to Food Log" button at the bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? 
                                           MediaQuery.of(context).padding.bottom : 8),
                        child: ElevatedButton(
                          onPressed: () {
                            // If we're in edit mode, first save the changes
                            if (isEditing) {
                              try {
                                final calories = double.parse(caloriesEditController.text);
                                final protein = double.parse(proteinEditController.text);
                                final carbs = double.parse(carbsEditController.text);
                                final fat = double.parse(fatEditController.text);
                                
                                // Update the main controllers
                                _caloriesController.text = caloriesEditController.text;
                                _proteinController.text = proteinEditController.text;
                                _carbsController.text = carbsEditController.text;
                                _fatController.text = fatEditController.text;
                                _servingSizeController.text = servingSizeEditController.text;
                                
                                // Update the analysis result
                                _analysisResult = NutritionInfo(
                                  foodName: _analysisResult!.foodName,
                                  brandName: _analysisResult!.brandName,
                                  calories: calories,
                                  protein: protein,
                                  carbs: carbs,
                                  fat: fat,
                                  servingSize: servingSizeEditController.text,
                                  ingredients: _analysisResult!.ingredients,
                                  additionalInfo: _analysisResult!.additionalInfo,
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error updating values: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }
                            
                            Navigator.pop(context);
                            _addFoodToLog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                      child: Text(
                        isEditing ? 'Save & Add to Food Log' : 'Add to Food Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                        ),
                      ),
                    ],
            ),
          );
        },
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  void _updateNutritionValues() {
    if (_analysisResult == null) return;

    try {
      // Parse edited values
      final double calories = double.parse(_caloriesController.text);
      final double protein = double.parse(_proteinController.text);
      final double carbs = double.parse(_carbsController.text);
      final double fat = double.parse(_fatController.text);
      final String servingSize = _servingSizeController.text;

      // Create updated nutrition info
      final updatedResult = NutritionInfo(
        foodName: _analysisResult!.foodName,
        brandName: _analysisResult!.brandName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        servingSize: servingSize,
        additionalInfo: _analysisResult!.additionalInfo,
        ingredients: _analysisResult!.ingredients,
      );

      setState(() {
        _analysisResult = updatedResult;
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nutrition values updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update values: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addFoodToLog() async {
    if (_analysisResult == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate date using AppDateUtils
      final validatedDate = AppDateUtils.validateDate(_effectiveDate);
      final dateDisplay = AppDateUtils.formatDateForDisplay(validatedDate);

      
      // Add timestamp and meal type to additionalInfo
      _analysisResult!.additionalInfo['timestamp'] = DateTime.now().toIso8601String();
      _analysisResult!.additionalInfo['mealType'] = 'Other'; // Default meal type
      
      // Add to Hive with proper date
      await FoodHiveService.addFood(
        _analysisResult!,
        logDate: validatedDate
      );
      
   
      setState(() {
        _isLoading = false;
      });

      // Update widget data if available
      try {
        await WidgetService.updateNutritionWidget();
      } catch (e) {

      }

      // Show widget promo dialog if applicable
      if (mounted) {
        WidgetPromoDialog.showWidgetPromoDialog(context);
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Food added to ${dateDisplay}'),
          backgroundColor: Colors.green,
        ),
      );

      // Return success to previous screen
        Navigator.pop(context, true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showSuccessBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Food Added Successfully!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your food has been added to your daily log.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Add Another Food',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to format date for display
  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    // Debug output to verify the date comparison

    
    if (dateToCheck.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  // Load food logs for the selected date - called when date is changed
  Future<void> _loadFoodLogsForDate(DateTime date) async {

    
    // Get food logs from Hive
    final foodLogs = await FoodHiveService.getFoodsForDate(date);
    

    
  
    


    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${foodLogs.length} food logs for ${_getFormattedDate(date)}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _populateFormWithFood(PopularFood food) {
    _foodNameController.text = food.name;
    _ingredientsController.text = food.commonIngredients.join(', ');
    _portionsController.text = food.servingSize;

    // Switch to Custom tab
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    // Format the date for display
    final String dateText = _getFormattedDate(_effectiveDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Food Database',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Adding to: $dateText',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Free analysis counter moved here - only show for non-premium users
          if (!_isPremium)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.analytics,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_maxFreeAnalysis - _remainingFreeAnalysis}/$_maxFreeAnalysis Free AI Analysis Used',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.info_outline,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upgrade to Premium for unlimited AI analysis',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to subscription screen or show upgrade dialog
                      SubscriptionHandler.showSubscriptionScreen(
                        context,
                        feature: Feature.foodDatabase,
                        title: "Unlimited Food Analysis",
                        subtitle: "Get unlimited AI-powered food analysis and nutrition tracking with premium.",
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(0, 30),
                    ),
                    child: Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate()
             .fadeIn(duration: Duration(milliseconds: 400))
             .slideY(begin: 0.1, end: 0, duration: Duration(milliseconds: 300)),

          // New modern tab design
          Container(
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                      AppColors.primary,
                      Color(0xFF8E64FF), // A complementary purple shade
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                  borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
                dividerColor: Colors.transparent,
              labelColor: Colors.white,
                unselectedLabelColor: AppColors.textPrimary.withOpacity(0.7),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                fontSize: 15,
                  letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                  fontSize: 15,
              ),
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
              tabs: [
                  Tab(
                      child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
              children: [
                          Icon(Icons.restaurant_menu, size: 18),
                          SizedBox(width: 8),
                          Flexible(child: Text('Popular Foods', overflow: TextOverflow.ellipsis)),
                        ],
                            ),
                          ),
                  ),
                  Tab(
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.add_circle_outline, size: 18),
                        SizedBox(width: 8),
                          Flexible(child: Text('Custom Food', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
          ).animate()
           .fadeIn(duration: Duration(milliseconds: 400))
           .slideY(begin: 0.05, end: 0, duration: Duration(milliseconds: 300)),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPopularFoodsTab(),
                _buildCustomAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularFoodsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _popularFoods.length,
      itemBuilder: (context, index) {
        final food = _popularFoods[index];
        return _buildModernFoodCard(food)
            .animate()
            .fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 50 * index))
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildModernFoodCard(PopularFood food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _populateFormWithFood(food),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Food icon in a circle with gradient background
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.7),
                        AppColors.primary.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    food.icon,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food name
                      Text(
                        food.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Category and calories
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              food.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${food.nutritionPreview['calories']} cal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Nutrients in pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildNutrientPill('P: ${food.nutritionPreview['protein']}g', Color(0xFFE91E63)),
                          _buildNutrientPill('C: ${food.nutritionPreview['carbs']}g', Color(0xFFFF9800)),
                          _buildNutrientPill('F: ${food.nutritionPreview['fat']}g', Color(0xFF2196F3)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon with rounded background
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNutrientPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCustomAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input form
          _buildInputForm(),

          const SizedBox(height: 24),

          // Results section
          if (_isLoading)
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Analyzing your food with AI...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will just take a moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ).animate()
               .fadeIn(duration: Duration(milliseconds: 400)),
            )
          else if (_analysisResult != null)
            _isEditMode ? _buildEditForm() : _buildResultsCard(),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.food_bank_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Custom Food',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter details for nutrition analysis',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Food name
              TextField(
                controller: _foodNameController,
                decoration: InputDecoration(
                  labelText: 'Food Name*',
                  hintText: 'e.g., Homemade Chicken Salad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 16, right: 10),
                    child: Icon(Icons.fastfood, color: AppColors.primary),
                  ),
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                  floatingLabelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.04),
                ),
              ),
              const SizedBox(height: 20),

              // Ingredients - Optional
              TextField(
                controller: _ingredientsController,
                decoration: InputDecoration(
                  labelText: 'Ingredients (Optional)',
                  hintText: 'e.g., Chicken breast, lettuce, tomatoes, olive oil',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 16, right: 10),
                    child: Icon(Icons.list, color: AppColors.primary),
                  ),
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                  floatingLabelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.04),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Portions
              TextField(
                controller: _portionsController,
                decoration: InputDecoration(
                  labelText: 'Portion Size*',
                  hintText: 'e.g., 1 cup, 250g, 2 servings',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 16, right: 10),
                    child: Icon(Icons.restaurant, color: AppColors.primary),
                  ),
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                  floatingLabelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.04),
                ),
              ),
              const SizedBox(height: 28),

              // Analyze button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _analyzeCustomFood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isLoading ? Icons.hourglass_top : Icons.analytics_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _isLoading ? 'Analyzing...' : 'Analyze with AI',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(target: _isLoading ? 0 : 1)
                .fadeIn(duration: Duration(milliseconds: 300))
                .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1)),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  '* Required fields',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: Duration(milliseconds: 500))
      .slideY(begin: 0.05, end: 0, duration: Duration(milliseconds: 400));
  }

  Widget _buildResultsCard() {
    if (_analysisResult == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with edit button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade500,
                              Colors.green.shade300,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analysis Results',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'AI-powered nutrition analysis',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    onPressed: _toggleEditMode,
                    tooltip: 'Edit nutrition values',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Food name and portion
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.12),
                      AppColors.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _analysisResult!.foodName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Serving size: ${_analysisResult!.servingSize}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade500,
                            Colors.orange.shade300,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Calories counter
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.15),
                      Colors.orange.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_fire_department,
                                color: Colors.orange.shade700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Calories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_analysisResult!.calories.round()} kcal',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar for calories
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.7, // This would ideally be calculated based on daily goal
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                        minHeight: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Nutrition breakdown
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.pie_chart_outline,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nutrition breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Macronutrients
              Row(
                children: [
                  Expanded(
                    child: _buildMacronutrientCard(
                      'Protein',
                      '${_analysisResult!.protein.round()}g',
                      Icons.fitness_center,
                      Color(0xFFE91E63),
                      _analysisResult!.protein / 100, // Mock percentage
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMacronutrientCard(
                      'Carbs',
                      '${_analysisResult!.carbs.round()}g',
                      Icons.grain,
                      Color(0xFFFF9800),
                      _analysisResult!.carbs / 200, // Mock percentage
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMacronutrientCard(
                      'Fat',
                      '${_analysisResult!.fat.round()}g',
                      Icons.water_drop,
                      Color(0xFF2196F3),
                      _analysisResult!.fat / 70, // Mock percentage
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Ingredients section
              if (_analysisResult!.ingredients.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.eco_outlined,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Ingredients',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: _analysisResult!.ingredients.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            ingredient,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // Add to log button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addFoodToLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _isLoading ? 'Adding...' : 'Add to Food Log',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate()
                .fadeIn(duration: Duration(milliseconds: 400))
                .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1)),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: Duration(milliseconds: 600))
      .slideY(begin: 0.05, end: 0, duration: Duration(milliseconds: 500));
  }

  Widget _buildMacronutrientCard(
      String label, String value, IconData icon, Color color, double percentage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    if (_analysisResult == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Nutrition Values',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleEditMode,
                  tooltip: 'Cancel editing',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Food name (non-editable)
            Text(
              _analysisResult!.foodName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Serving size
            TextField(
              controller: _servingSizeController,
              decoration: InputDecoration(
                labelText: 'Serving Size',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calories
            TextField(
              controller: _caloriesController,
              decoration: InputDecoration(
                labelText: 'Calories',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.local_fire_department),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Protein
            TextField(
              controller: _proteinController,
              decoration: InputDecoration(
                labelText: 'Protein (g)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.fitness_center),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Carbs
            TextField(
              controller: _carbsController,
              decoration: InputDecoration(
                labelText: 'Carbs (g)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.grain),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Fat
            TextField(
              controller: _fatController,
              decoration: InputDecoration(
                labelText: 'Fat (g)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.water_drop),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _updateNutritionValues,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // Debug utility function to show all food logs
  Future<void> _debugShowFoodLogs() async {
    try {
      final foodLogs = await FoodHiveService.getFoodsForDate(_effectiveDate);
      

      
 
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${foodLogs.length} food logs for ${_getFormattedDate(_effectiveDate)}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting food logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
