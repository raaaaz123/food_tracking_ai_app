import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../constants/app_colors.dart';
import '../models/user_details.dart';
import '../services/storage_service.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';
import '../widgets/free_trial_offer_dialog.dart';
import 'main_app_screen.dart';
import 'dart:async';

class DietPlanResultScreen extends StatefulWidget {
  final UserDetails userDetails;
  final Map<String, dynamic> nutritionPlan;

  const DietPlanResultScreen({
    Key? key,
    required this.userDetails,
    required this.nutritionPlan,
  }) : super(key: key);

  @override
  State<DietPlanResultScreen> createState() => _DietPlanResultScreenState();
}

class _DietPlanResultScreenState extends State<DietPlanResultScreen> with SingleTickerProviderStateMixin {
  DateTime _projectedDate = DateTime.now().add(const Duration(days: 90)); // Default 90 days
  bool _isLoading = true;
  bool _isCheckingPremium = false; // Add loading state for premium check
  int _totalWeeks = 0;
  double _weightChangePerWeek = 0;
  
  // For editing nutrition values with default values
  int _dailyCalories = 1800;
  int _proteinGrams = 90;
  int _carbsGrams = 225;
  int _fatsGrams = 60;
  bool _isEditingNutrition = false;
  
  // Controllers for text editing
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Add to class fields
  int _currentTestimonialIndex = 0;
  Timer? _carouselTimer;
  final PageController _testimonialPageController = PageController();
  
  @override
  void initState() {
    super.initState();
    Posthog().screen(screenName: 'Diet Plan Results Screen');
    
    // Safely initialize nutrition values from the plan
    try {
      if (widget.nutritionPlan != null) {
        if (widget.nutritionPlan.containsKey('dailyCalories') && widget.nutritionPlan['dailyCalories'] != null) {
          _dailyCalories = widget.nutritionPlan['dailyCalories'] as int;
        }
        if (widget.nutritionPlan.containsKey('protein') && widget.nutritionPlan['protein'] != null) {
          _proteinGrams = widget.nutritionPlan['protein'] as int;
        }
        if (widget.nutritionPlan.containsKey('carbs') && widget.nutritionPlan['carbs'] != null) {
          _carbsGrams = widget.nutritionPlan['carbs'] as int;
        }
        if (widget.nutritionPlan.containsKey('fats') && widget.nutritionPlan['fats'] != null) {
          _fatsGrams = widget.nutritionPlan['fats'] as int;
        }
      }
    } catch (e) {
     
      // Keep the default values
    }
    
    // Initialize controllers with current values
    _caloriesController = TextEditingController(text: _dailyCalories.toString());
    _proteinController = TextEditingController(text: _proteinGrams.toString());
    _carbsController = TextEditingController(text: _carbsGrams.toString());
    _fatsController = TextEditingController(text: _fatsGrams.toString());
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    
    // Start carousel timer
    _startCarouselTimer();
    
    _loadTimelineData();
  }
  
  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _animationController.dispose();
    _testimonialPageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadTimelineData() async {
    // Try to load the AI timeline data from storage
    final timelineData = await StorageService.getTimelineProjection();
    
    if (timelineData != null) {
      setState(() {
        // Use the saved AI timeline data
        _projectedDate = DateTime.parse(timelineData['projectedDate']);
        _totalWeeks = timelineData['totalWeeks'];
        _weightChangePerWeek = timelineData['weightChangePerWeek'];
        _isLoading = false;
      });
    } else {
      // Fall back to calculating it manually if no saved data
    final double weightDifferenceAbs = (widget.userDetails.targetWeight - widget.userDetails.weight).abs();
    final double weeklyChange = widget.userDetails.weightChangeSpeed; // kg per week
    final int totalWeeks = (weightDifferenceAbs / weeklyChange).ceil();
      
      setState(() {
    _projectedDate = DateTime.now().add(Duration(days: totalWeeks * 7));
        _totalWeeks = totalWeeks;
        _weightChangePerWeek = weeklyChange;
        _isLoading = false;
      });
    }
  }
  
  // Save updated nutrition values
  Future<void> _saveNutritionPlan() async {
    // Validate and parse input values
    int calories = int.tryParse(_caloriesController.text) ?? _dailyCalories;
    int protein = int.tryParse(_proteinController.text) ?? _proteinGrams;
    int carbs = int.tryParse(_carbsController.text) ?? _carbsGrams;
    int fats = int.tryParse(_fatsController.text) ?? _fatsGrams;
    
    // Apply minimum values 
    calories = calories < 800 ? 800 : calories;
    protein = protein < 10 ? 10 : protein;
    carbs = carbs < 10 ? 10 : carbs;
    fats = fats < 10 ? 10 : fats;
    
    // Update state
    setState(() {
      _dailyCalories = calories;
      _proteinGrams = protein;
      _carbsGrams = carbs;
      _fatsGrams = fats;
      _isEditingNutrition = false;
    });
    
    // Save to storage
    final updatedPlan = {
      'dailyCalories': _dailyCalories,
      'protein': _proteinGrams,
      'carbs': _carbsGrams,
      'fats': _fatsGrams,
    };
    
    await StorageService.saveNutritionPlan(updatedPlan);
    
    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nutrition plan updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
  
  Future<void> _handleGetStarted() async {
    HapticFeedback.mediumImpact();
    
    print('🚀 Get Started button pressed');
    
    // Set loading state
    setState(() {
      _isCheckingPremium = true;
    });
    
    // Track button click in PostHog
    try {
      await Posthog().capture(
        eventName: 'get_started_button_clicked',
        properties: {
          'screen': 'diet_plan_result',
          'user_weight': widget.userDetails.weight,
          'target_weight': widget.userDetails.targetWeight,
          'is_weight_loss': widget.userDetails.targetWeight < widget.userDetails.weight,
        }
      );
    } catch (e) {
      print('❌ Error tracking event: $e');
    }
    
    print('🔍 Checking premium status...');
    
    // Check if user has premium subscription with timeout and error handling
    bool isPremium = false;
    try {
      // Add timeout to prevent UI from hanging
      isPremium = await SubscriptionHandler.isPremium().timeout(
        Duration(seconds: 3), // Reduced timeout to 3 seconds
        onTimeout: () {
          print('❌ Premium status check timed out, defaulting to false');
          return false;
        },
      );
      print('✅ Premium status: $isPremium');
    } catch (e) {
      print('❌ Error checking premium status: $e');
      // Default to false if there's an error
      isPremium = false;
    }
    
    // Clear loading state
    if (mounted) {
      setState(() {
        _isCheckingPremium = false;
      });
    }
    
    // Always show free trial dialog for non-premium users (or if check failed)
    if (!isPremium) {
      print('🎁 User is not premium, showing free trial dialog');
      // Show free trial offer dialog with celebration effects
      if (mounted) {
        try {
          print('📱 Attempting to show free trial dialog...');
          await showFreeTrialOfferDialog(
            context,
            onDismiss: () {
              print('🚪 Free trial dialog dismissed');
              // If user dismisses the dialog, fall back to main app screen
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainAppScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          );
          print('✅ Free trial dialog shown successfully');
        } catch (e) {
          print('❌ Error showing free trial dialog: $e');
          // Fallback: navigate directly to main app screen
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainAppScreen(),
              ),
              (route) => false,
            );
          }
        }
      }
    } else {
      print('👑 User is premium, navigating to main app');
      // If premium, navigate directly to main app screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainAppScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  // Test method to verify free trial dialog works
  Future<void> _testFreeTrialDialog() async {
    print('🧪 Testing free trial dialog...');
    try {
      await showFreeTrialOfferDialog(
        context,
        onDismiss: () {
          print('🧪 Test dialog dismissed');
        },
      );
      print('✅ Test dialog shown successfully');
    } catch (e) {
      print('❌ Test dialog failed: $e');
    }
  }

  // Simple test method to verify dialog system works
  Future<void> _testSimpleDialog() async {
    print('🧪 Testing simple dialog...');
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Test Dialog'),
          content: Text('This is a test dialog to verify the dialog system works.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      print('✅ Simple test dialog shown successfully');
    } catch (e) {
      print('❌ Simple test dialog failed: $e');
    }
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentTestimonialIndex < 4) {
        _currentTestimonialIndex++;
      } else {
        _currentTestimonialIndex = 0;
      }
      
      if (_testimonialPageController.hasClients) {
        _testimonialPageController.animateToPage(
          _currentTestimonialIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 700;
    
    // Use global app colors instead of local definitions
    final Color primaryColor = AppColors.primary;
    final Color accentColor = AppColors.accent;
    final Color backgroundLight = AppColors.background;
    final Color cardColor = AppColors.cardBackground;
    final Color textPrimary = AppColors.textPrimary;
    final Color textSecondary = AppColors.textSecondary;
    final Color successColor = AppColors.success;
    
    // Calculate macronutrient percentages with safety checks
    int totalCaloriesFromMacros = (_proteinGrams * 4) + (_carbsGrams * 4) + (_fatsGrams * 9);
    
    // Safety check to avoid division by zero
    if (totalCaloriesFromMacros <= 0) {
      totalCaloriesFromMacros = 1;  // Avoid division by zero
    }
    
    final int proteinPercent = ((_proteinGrams * 4 * 100) ~/ totalCaloriesFromMacros).clamp(0, 100);
    final int carbsPercent = ((_carbsGrams * 4 * 100) ~/ totalCaloriesFromMacros).clamp(0, 100);
    final int fatsPercent = ((_fatsGrams * 9 * 100) ~/ totalCaloriesFromMacros).clamp(0, 100);
    
    // Determine weight goal
    final bool isWeightLoss = widget.userDetails.targetWeight < widget.userDetails.weight;
    final String weightUnit = widget.userDetails.isMetric ? 'kg' : 'lbs';
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                "Preparing your plan...",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
              child: Column(
                children: [
                    // Congratulations section with modern design
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.2),
                            primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background decoration elements
                          Positioned(
                            top: -15,
                            right: -15,
                            child: Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -20,
                            left: -20,
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          
                          // Main content
                          Padding(
                            padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                                // Header with badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                          Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                          colors: [primaryColor, Color.lerp(primaryColor, Colors.black, 0.3)!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                                        borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                            color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                              Icons.workspace_premium,
                              color: AppColors.textLight,
                                            size: 18,
                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            "PREMIUM PLAN",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textLight,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Congratulations text
                          GestureDetector(
                            onLongPress: _testFreeTrialDialog,
                            child: Text(
                              "Congratulations!",
                              style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                                const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  "Your personalized health plan is ready",
                                  style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Debug button for testing
                              GestureDetector(
                                onTap: _testSimpleDialog,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.bug_report,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                                
                                const SizedBox(height: 20),
                                
                                // Goal card
                          Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                                  child: Column(
                                    children: [
                                      // Weight goal
                                      Row(
                              children: [
                                Container(
                                            padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isWeightLoss ? Icons.trending_down : Icons.trending_up,
                                              color: primaryColor,
                                              size: 18,
                                  ),
                                ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                                  "Weight Goal",
                                      style: TextStyle(
                                                    fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                                    color: textSecondary,
                                      ),
                                    ),
                                                Row(
                                                  children: [
                                    Text(
                                                      "${isWeightLoss ? 'Lose' : 'Gain'} ",
                                      style: TextStyle(
                                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${(widget.userDetails.weight - widget.userDetails.targetWeight).abs().toStringAsFixed(1)} $weightUnit",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: successColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "Achievable",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: successColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(),
                                      ),
                                      
                                      // Timeline
                          Row(
                            children: [
                              Container(
                                            padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                              color: successColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                              color: successColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                                  "Expected Completion",
                                      style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: textSecondary,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_projectedDate),
                                      style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$_totalWeeks weeks",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                                color: primaryColor,
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
                          ),
                        ],
                    ),
                  ),
                  
                  // Nutritional recommendations section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Section header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      Color.lerp(primaryColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Your nutritional recommendations",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _isEditingNutrition
                                          ? "Adjust values to match your goals"
                                          : "Personalized based on your body and goals",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit button
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_isEditingNutrition) {
                                      _saveNutritionPlan();
                                    } else {
                                      _isEditingNutrition = true;
                                    }
                                  });
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _isEditingNutrition 
                                        ? successColor.withOpacity(0.1) 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _isEditingNutrition ? Icons.check : Icons.edit,
                                    color: _isEditingNutrition ? successColor : textSecondary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                                // Calories display
                                Container(
                                  width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  decoration: BoxDecoration(
                              color: backgroundLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                color: primaryColor.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.local_fire_department,
                                      color: primaryColor,
                                            size: 18
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Daily Calories",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (_isEditingNutrition)
                                        Container(
                                          width: 120,
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: TextField(
                                            controller: _caloriesController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              border: InputBorder.none,
                                              suffixText: "kcal",
                                            ),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(4),
                                            ],
                                          ),
                                        )
                                      else
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              _dailyCalories.toString(),
                                              style: TextStyle(
                                          fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "kcal",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                
                          const SizedBox(height: 16),
                                
                          // Macros distribution
                                _isEditingNutrition
                              ? _buildEditableMacros(primaryColor, cardColor, textPrimary, textSecondary)
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildMacroCircle(
                                            percent: carbsPercent,
                                            label: "Carbs",
                                      color: accentColor,
                                            value: "$_carbsGrams g",
                                          ),
                                          _buildMacroCircle(
                                            percent: proteinPercent,
                                            label: "Protein",
                                      color: primaryColor,
                                            value: "$_proteinGrams g",
                                          ),
                                          _buildMacroCircle(
                                            percent: fatsPercent,
                                            label: "Fat",
                                            color: AppColors.info,
                                            value: "$_fatsGrams g",
                                          ),
                                        ],
                                      ),
                              ],
                    ),
                  ),
                  
                  // Timeline projection card
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      Color.lerp(primaryColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Your Journey Timeline",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      "100% achievable with your plan",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Weight Progress Visual Graph
                          Container(
                            height: 150,
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: backgroundLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: CustomPaint(
                              painter: WeightProgressPainter(
                                startWeight: widget.userDetails.weight,
                                currentWeight: widget.userDetails.weight,
                                targetWeight: widget.userDetails.targetWeight,
                                progressPercentage: 0, // Just starting
                                primaryColor: primaryColor,
                                accentColor: accentColor,
                                weightUnit: weightUnit,
                              ),
                              child: Container(), // Empty container as child for the CustomPaint
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Goal info card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildGoalWeightItem(
                                      "Starting",
                                      "${widget.userDetails.weight.toStringAsFixed(1)} $weightUnit",
                                primaryColor,
                                      Icons.scale,
                                    ),
                                    Container(
                                height: 40,
                                      width: 1,
                                color: primaryColor.withOpacity(0.2),
                                    ),
                                    _buildGoalWeightItem(
                                      "Goal",
                                      "${widget.userDetails.targetWeight.toStringAsFixed(1)} $weightUnit",
                                primaryColor,
                                      Icons.flag,
                                    ),
                                  ],
                                ),
                                
                          const SizedBox(height: 16),
                                
                                // Progress timeline
                                Container(
                            height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                  height: 6,
                                  width: 16, // Starting point indicator
                                        decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                          const SizedBox(height: 8),
                                
                                // Timeline markers
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                    size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM d').format(DateTime.now()),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                    size: 12,
                                    color: primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM d').format(_projectedDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                          ),
                        ],
                      ),
                                ),
                                
                    // Premium Features Preview
                                Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.15),
                            primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: AppColors.textLight,
                                        size: 18,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Premium Features",
                                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                                ),
                                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPremiumFeature(
                            "Personalized Meal Plans",
                            "Get custom meals based on your diet preferences"
                          ),
                          const SizedBox(height: 8),
                          _buildPremiumFeature(
                            "Advanced Progress Tracking",
                            "Detailed analytics to monitor your journey"
                          ),
                          const SizedBox(height: 8),
                          _buildPremiumFeature(
                            "Expert Nutrition Support",
                            "Get guidance from certified specialists"
                                              ),
                                            ],
                                          ),
                                        ),
                    
                    // Personalized Challenges Section based on user data
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
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
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.warning,
                                      AppColors.warning.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Your Health Challenges",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "Premium solves these",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          
                          // Dynamically show challenges based on user data
                          _buildHealthChallenge(
                            isWeightLoss 
                              ? "Difficulty sticking to diet plans" 
                              : "Struggling to gain healthy weight",
                            isWeightLoss
                              ? "82% of users struggle with maintaining their diet plan due to lack of proper guidance"
                              : "71% of people with your body type find it hard to gain healthy weight without expert guidance",
                            Icons.restaurant,
                            AppColors.warning
                          ),
                          
                          const SizedBox(height: 12),
                          _buildHealthChallenge(
                            DateTime.now().difference(widget.userDetails.birthDate).inDays > 365 * 40
                              ? "Age-related metabolism changes" 
                              : "Inconsistent energy levels",
                            DateTime.now().difference(widget.userDetails.birthDate).inDays > 365 * 40
                              ? "Your metabolism naturally slows by up to 10% after 40, requiring specialized nutrition"
                              : "Your current nutrition profile may lead to energy crashes throughout the day",
                            Icons.watch_later_outlined,
                            AppColors.error
                          ),
                          
                          const SizedBox(height: 12),
                          _buildHealthChallenge(
                            "Limited nutritional knowledge",
                            "People typically underestimate their daily calorie intake by 20-40%",
                            Icons.psychology,
                            AppColors.primary
                          ),
                        ],
                      ),
                    ),
                    
                    // Success Stories Section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
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
                                  gradient: LinearGradient(
                                    colors: [
                                      successColor,
                                      Color.lerp(successColor, Colors.black, 0.2)!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.people_alt_rounded,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Success Stories",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      "People just like you",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Dynamic testimonial based on user goals
                          _buildTestimonialCarousel(
                            isWeightLoss: isWeightLoss,
                            weightUnit: weightUnit,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Stats banner
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: successColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      "92%",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: successColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Success rate",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 35,
                                  width: 1,
                                  color: successColor.withOpacity(0.3),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      "30 days",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: successColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Average time",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
          
          // Get Started Button - Enhanced for better visibility
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundLight.withOpacity(0.8),
                    backgroundLight,
                  ],
                ),
              ),
            child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _isCheckingPremium ? null : _handleGetStarted,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.5),
                    ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isCheckingPremium)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        const Icon(
                          Icons.rocket_launch_rounded,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isCheckingPremium ? "Checking..." : "GET STARTED NOW",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
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
    );
  }
  
  Widget _buildPremiumFeature(String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check,
            color: AppColors.success,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget for editable macros
  Widget _buildEditableMacros(Color primaryColor, Color cardColor, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Protein input row
          _buildMacroInputRow(
            label: "Protein",
            controller: _proteinController,
            color: AppColors.primary,
            icon: Icons.fitness_center,
            cardColor: cardColor,
            textColor: textPrimary,
          ),
          const SizedBox(height: 16),
          
          // Carbs input row
          _buildMacroInputRow(
            label: "Carbs",
            controller: _carbsController,
            color: AppColors.accent,
            icon: Icons.grain,
            cardColor: cardColor,
            textColor: textPrimary,
          ),
          const SizedBox(height: 16),
          
          // Fats input row
          _buildMacroInputRow(
            label: "Fats",
            controller: _fatsController,
            color: AppColors.info,
            icon: Icons.opacity,
            cardColor: cardColor,
            textColor: textPrimary,
          ),
          
          const SizedBox(height: 8),
          
          // Help text
          Text(
            "Values are in grams. Tap save when done.",
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget for each editable macro row
  Widget _buildMacroInputRow({
    required String label,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
    required Color cardColor,
    required Color textColor,
  }) {
    return Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        
        // Label
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        
        // Input field
        Container(
          width: 100,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              border: InputBorder.none,
              suffixText: "g",
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
          ),
        ),
      ],
    );
  }

  // Widget for timeline detail item
  Widget _buildTimelineDetail({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.blue.shade700,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCircle({
    required int percent,
    required String label,
    required Color color,
    required String value,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
            ),
            
            // Progress circle
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 8,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            
            // Percentage text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$percent%",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalBullet(String text, {required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinusPoint(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, color: Colors.red.shade400, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlusPoint(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.textLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.add,
            color: AppColors.textLight,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper method for goal weight items
  Widget _buildGoalWeightItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // Helper method for milestone cards
  Widget _buildMilestoneCard(String week, String weight, String progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              week,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weight,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            progress,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate milestone weight based on weeks passed
  double _calculateMilestoneWeight(int weeks) {
    // Get starting and target weights
    final double startWeight = widget.userDetails.weight;
    final double targetWeight = widget.userDetails.targetWeight;
    final double weightDiff = targetWeight - startWeight;
    
    // Calculate how much weight should be lost/gained by this milestone
    final double progressRatio = _totalWeeks > 0 ? (weeks / _totalWeeks) : 0;
    final double milestoneProgress = weightDiff * progressRatio;
    
    // Return the projected weight at this milestone
    return startWeight + milestoneProgress;
  }

  // Calculate percentage of goal achieved at milestone
  int _calculatePercentage(int weeks) {
    if (_totalWeeks <= 0) return 0;
    
    // Calculate the percentage of time passed against total time
    final int percentage = ((weeks / _totalWeeks) * 100).round();
    
    // Ensure the percentage is between 0 and 100
    return percentage.clamp(0, 100);
  }

  Widget _buildMotivationalMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Your Path to Success",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Following this plan will help you reach your goal weight of ${widget.userDetails.targetWeight.toStringAsFixed(1)} kg by $_projectedDate.",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Why this works:",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildSuccessPoint("Nutritionally balanced for sustainable results"),
          const SizedBox(height: 8),
          _buildSuccessPoint("Personalized to your metabolic needs"),
          const SizedBox(height: 8),
          _buildSuccessPoint("Science-backed macronutrient proportions"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "92% success rate",
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessPoint(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.check,
            color: AppColors.success,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthChallenge(String title, String description, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTestimonialCarousel({required bool isWeightLoss, required String weightUnit}) {
    // Define testimonial data with network image URLs
    final List<Map<String, dynamic>> testimonials = [
      {
        'name': 'Jason Morrison, 42',
        'location': 'New York',
        'achievement': isWeightLoss 
          ? 'Lost 18 $weightUnit in 12 weeks' 
          : 'Gained 9 $weightUnit of lean muscle',
        'quote': 'The meal planning saved me so much time. I\'ve tried other apps but this one actually understands my schedule. The guidance was exactly what I needed!',
        'image': 'https://randomuser.me/api/portraits/men/32.jpg',
        'rating': 5,
        'verified': true,
      },
      {
        'name': 'Emma Wilson, 31',
        'location': 'London',
        'achievement': isWeightLoss 
          ? 'Lost 12 $weightUnit in 8 weeks' 
          : 'Gained 6 $weightUnit with proper nutrition',
        'quote': 'I\'ve struggled with portion control for years. The premium plan helped me understand what I was actually eating. The results came faster than expected.',
        'image': 'https://randomuser.me/api/portraits/women/44.jpg',
        'rating': 5,
        'verified': true,
      },
      {
        'name': 'Robert Chen, 38',
        'location': 'Chicago',
        'achievement': isWeightLoss 
          ? 'Lost 15 $weightUnit in 10 weeks' 
          : 'Gained 8 $weightUnit of healthy weight',
        'quote': 'As someone with a hectic work schedule, the customized meal options were a game-changer for me. I never felt like I was on a diet but saw results every week.',
        'image': 'https://randomuser.me/api/portraits/men/22.jpg',
        'rating': 4,
        'verified': true,
      },
      {
        'name': 'Sophia Martinez, 27',
        'location': 'Miami',
        'achievement': isWeightLoss 
          ? 'Lost 10 $weightUnit in 7 weeks' 
          : 'Gained 5 $weightUnit and better energy',
        'quote': 'The nutrition plan was perfect for my dietary restrictions. I finally found something that works with my lifestyle. The app made tracking progress actually fun!',
        'image': 'https://randomuser.me/api/portraits/women/29.jpg',
        'rating': 5,
        'verified': true,
      },
      {
        'name': 'David Thompson, 35',
        'location': 'Seattle',
        'achievement': isWeightLoss 
          ? 'Lost 22 $weightUnit in 14 weeks' 
          : 'Gained 11 $weightUnit of muscle',
        'quote': 'I was skeptical at first, but the premium plan really delivered results. The personalized approach made all the difference compared to one-size-fits-all diets I tried before.',
        'image': 'https://randomuser.me/api/portraits/men/52.jpg',
        'rating': 5,
        'verified': true,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Testimonial carousel
        Container(
          height: 180,
          child: PageView.builder(
            controller: _testimonialPageController,
            itemCount: testimonials.length,
            onPageChanged: (index) {
              setState(() {
                _currentTestimonialIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final testimonial = testimonials[index];
              return _buildModernTestimonial(
                testimonial['name'],
                testimonial['location'],
                testimonial['achievement'],
                testimonial['quote'],
                testimonial['image'],
                testimonial['rating'],
                testimonial['verified'],
              );
            },
          ),
        ),
        
        // Dots indicator
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              testimonials.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentTestimonialIndex == index
                    ? AppColors.primary
                    : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTestimonial(String name, String location, String achievement, 
      String quote, String imageUrl, int rating, bool verified) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info row
                Row(
                  children: [
                    // Profile image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.person, color: Colors.grey.shade400, size: 30),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey.shade100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Name and location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (verified)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.verified,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            location,
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
                
                const SizedBox(height: 12),
                
                // Achievement
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    achievement,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Quote
                Expanded(
                  child: Text(
                    quote,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          
          // Rating stars
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: index < rating ? AppColors.warning : Colors.grey.shade300,
                  size: 14,
                ),
              ),
            ),
          ),
          
          // "Premium Member" badge
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, Colors.purple, 0.3)!,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Premium",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
}

// Custom painter for weight progress visualization
class WeightProgressPainter extends CustomPainter {
  final double startWeight;
  final double currentWeight;
  final double targetWeight;
  final double progressPercentage;
  final Color primaryColor;
  final Color accentColor;
  final String weightUnit;

  WeightProgressPainter({
    required this.startWeight,
    required this.currentWeight,
    required this.targetWeight,
    required this.progressPercentage,
    required this.primaryColor,
    required this.accentColor,
    required this.weightUnit,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final bool isSmallCanvas = size.width < 300;
    final double pointRadius = isSmallCanvas ? 4.0 : 6.0;
    final double strokeWidth = isSmallCanvas ? 2.0 : 3.0;
    final double labelFontSize = isSmallCanvas ? 10.0 : 12.0;
    
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw grid lines
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical time markers
    for (int i = 0; i < 5; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Calculate if losing or gaining weight
    final bool isWeightLoss = targetWeight < startWeight;

    // Draw progress line with animated gradient
    final progressPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppColors.primary.withOpacity(0.8),
          isWeightLoss ? AppColors.success : AppColors.warning,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Starting point
    path.moveTo(0, isWeightLoss ? 0 : size.height);
    
    // Control points for curve
    final controlX1 = size.width * 0.3;
    final controlY1 = isWeightLoss ? size.height * 0.2 : size.height * 0.7;
    final controlX2 = size.width * 0.7;
    final controlY2 = isWeightLoss ? size.height * 0.7 : size.height * 0.3;
    
    // End point
    path.cubicTo(
      controlX1, controlY1,
      controlX2, controlY2,
      size.width, isWeightLoss ? size.height : 0,
    );
    
    canvas.drawPath(path, progressPaint);

    // Draw gradient fill under the curve with improved colors
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          isWeightLoss ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);

    // Draw points on the curve with improved styling
    final startPointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final startPointStroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Start weight point
    canvas.drawCircle(
      Offset(0, isWeightLoss ? 0 : size.height),
      pointRadius,
      startPointStroke,
    );
    canvas.drawCircle(
      Offset(0, isWeightLoss ? 0 : size.height),
      pointRadius - 2,
      startPointPaint,
    );

    // Target weight point
    canvas.drawCircle(
      Offset(size.width, isWeightLoss ? size.height : 0),
      pointRadius,
      Paint()..color = isWeightLoss ? AppColors.success : AppColors.warning,
    );
    canvas.drawCircle(
      Offset(size.width, isWeightLoss ? size.height : 0),
      pointRadius - 2,
      startPointPaint,
    );

    // Draw milestone points (25%, 50%, 75%)
    for (int i = 1; i < 4; i++) {
      final milestoneX = size.width * (i / 4);
      final milestoneY = _getYPositionOnCurve(milestoneX / size.width, path, size, isWeightLoss);
      
      canvas.drawCircle(
        Offset(milestoneX, milestoneY),
        pointRadius - 1,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(milestoneX, milestoneY),
        pointRadius - 2,
        Paint()..color = AppColors.primary.withOpacity(0.7),
      );
    }

    // Draw weight labels with improved styling
    _drawWeightLabel(
      canvas, 
      "${startWeight.toStringAsFixed(1)} $weightUnit", 
      Offset(10, isWeightLoss ? 10 : size.height - 25), 
      AppColors.primary,
      labelFontSize,
      isSmallCanvas
    );
    
    _drawWeightLabel(
      canvas, 
      "${targetWeight.toStringAsFixed(1)} $weightUnit", 
      Offset(size.width - 60, isWeightLoss ? size.height - 25 : 10), 
      isWeightLoss ? AppColors.success : AppColors.warning,
      labelFontSize,
      isSmallCanvas
    );
  }

  // Helper method to find Y position on the curve for milestone points
  double _getYPositionOnCurve(double t, Path path, Size size, bool isWeightLoss) {
    // This is a simplified approximation for a cubic bezier curve
    // Start and end points
    final double startY = isWeightLoss ? 0 : size.height;
    final double endY = isWeightLoss ? size.height : 0;
    
    // Control points (same as in the paint method)
    final double controlY1 = isWeightLoss ? size.height * 0.2 : size.height * 0.7;
    final double controlY2 = isWeightLoss ? size.height * 0.7 : size.height * 0.3;
    
    // Calculate point on cubic Bezier curve using the formula:
    // B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
    final double mt = 1 - t;
    return startY * (mt * mt * mt) + 
           controlY1 * (3 * mt * mt * t) + 
           controlY2 * (3 * mt * t * t) + 
           endY * (t * t * t);
  }

  void _drawWeightLabel(Canvas canvas, String text, Offset offset, Color color, double fontSize, bool isSmallCanvas) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    
    // Draw background with improved styling
    final paddingH = isSmallCanvas ? 6.0 : 8.0;
    final paddingV = isSmallCanvas ? 3.0 : 4.0;
    
    final rect = Rect.fromLTWH(
      offset.dx - paddingH,
      offset.dy - paddingV,
      textPainter.width + (paddingH * 2),
      textPainter.height + (paddingV * 2),
    );
    
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(isSmallCanvas ? 4.0 : 6.0),
    );
    
    // Draw shadow for depth
    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.1),
    );
    
    // Draw background
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white,
    );
    
    // Draw border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    
    textPainter.paint(canvas, offset);
  }
  
  @override
  bool shouldRepaint(WeightProgressPainter oldDelegate) =>
      oldDelegate.startWeight != startWeight ||
      oldDelegate.currentWeight != currentWeight ||
      oldDelegate.targetWeight != targetWeight ||
      oldDelegate.progressPercentage != progressPercentage ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
} 