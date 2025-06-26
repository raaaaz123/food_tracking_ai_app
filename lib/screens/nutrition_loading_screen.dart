import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../models/user_details.dart';
import '../services/storage_service.dart';
import '../services/nutrition_service.dart';
import '../constants/app_colors.dart';
import 'diet_plan_result_screen.dart';
import 'main_app_screen.dart';

class NutritionLoadingScreen extends StatefulWidget {
  final UserDetails userDetails;
  final double targetWeight;
  final Function(String)? onError;

  const NutritionLoadingScreen({
    Key? key,
    required this.userDetails,
    required this.targetWeight,
    this.onError,
  }) : super(key: key);

  @override
  State<NutritionLoadingScreen> createState() => _NutritionLoadingScreenState();
}

class _NutritionLoadingScreenState extends State<NutritionLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Loading state
  bool _userDetailsSaved = false;
  bool _nutritionCalculated = false;
  bool _nutritionSaved = false;
  bool _dataVerified = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Progress value from 0.0 to 1.0
  double _progress = 0.0;
  
  // Loading messages
  final List<String> _loadingMessages = [
    "Analyzing your goals...",
    "Calculating your metabolic rate...",
    "Personalizing your nutrition plan...",
    "Optimizing macronutrient ratios...",
    "Finalizing your personalized plan...",
  ];
  
  int _currentMessageIndex = 0;
  
  // Food facts to show during loading
  final List<String> _foodFacts = [
    "Eating protein helps build muscle and keeps you feeling full longer.",
    "Healthy fats are essential for hormone production and brain health.",
    "Complex carbs provide sustained energy throughout the day.",
    "Staying hydrated improves performance and helps with weight management.",
    "Colorful fruits and vegetables provide a wide range of vitamins and antioxidants.",
    "Consistency is more important than perfection when following a nutrition plan.",
    "Small, sustainable changes lead to better long-term results.",
    "Meal prepping can help you stay on track with your nutrition goals.",
  ];
  
  String get _currentFoodFact {
    final random = Random();
    return _foodFacts[random.nextInt(_foodFacts.length)];
  }

  @override
  void initState() {
    super.initState();
    Posthog().screen(screenName: 'Nutrition Loading Screen');
    
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Start the calculation process
    _calculateNutrition();
    
    // Change loading message every 3 seconds
    _startMessageCycle();
  }
  
  void _startMessageCycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isComplete && !_hasError) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
        });
        _startMessageCycle();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _calculateNutrition() async {
    try {

      
      // Create user details with target weight
      final userDetails = UserDetails(
        height: widget.userDetails.height,
        weight: widget.userDetails.weight,
        birthDate: widget.userDetails.birthDate,
        isMetric: widget.userDetails.isMetric,
        workoutsPerWeek: widget.userDetails.workoutsPerWeek,
        weightGoal: widget.userDetails.weightGoal,
        targetWeight: widget.targetWeight,
        gender: widget.userDetails.gender,
        motivationGoal: widget.userDetails.motivationGoal,
        dietType: widget.userDetails.dietType,
        weightChangeSpeed: widget.userDetails.weightChangeSpeed,
      );

      // Update progress
      setState(() {
        _progress = 0.2;
      });
      
      // Save user details

      await StorageService.saveUserDetails(userDetails);

      
      // Update progress
      setState(() {
        _userDetailsSaved = true;
        _progress = 0.4;
      });
      
      // Calculate nutrition plan with a small delay to show the progress
      await Future.delayed(const Duration(milliseconds: 500));

      final nutritionData = await NutritionService.calculateNutrition(
        height: userDetails.height,
        weight: userDetails.weight,
        birthDate: userDetails.birthDate,
        isMetric: userDetails.isMetric,
        workoutsPerWeek: userDetails.workoutsPerWeek,
        weightGoal: userDetails.weightGoal,
        targetWeight: widget.targetWeight,
        gender: userDetails.gender,
        motivationGoal: userDetails.motivationGoal,
        dietType: userDetails.dietType,
        weightChangeSpeed: userDetails.weightChangeSpeed,
      );
      
      // Update progress
      setState(() {
        _nutritionCalculated = true;
        _progress = 0.6;
      });
      
      // Add a small delay to show progress
      await Future.delayed(const Duration(milliseconds: 500));

      // Process nutrition data
      final processedNutritionData = {
        'dailyCalories': (nutritionData['dailyCalories'] as num).toInt(),
        'protein': (nutritionData['protein'] as num).toInt(),
        'carbs': (nutritionData['carbs'] as num).toInt(),
        'fats': (nutritionData['fats'] as num).toInt(),
      };

      // Save nutrition plan

    
      await StorageService.saveNutritionPlan(processedNutritionData);

      
      // Update progress
      setState(() {
        _nutritionSaved = true;
        _progress = 0.8;
      });
      
      // Add a small delay to show progress
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify that data was saved correctly

      final savedUserDetails = await StorageService.getUserDetails();
      final savedNutritionPlan = await StorageService.getNutritionPlan();
      
    
      
      if (savedUserDetails == null || savedNutritionPlan == null) {

        // Try saving again if something is missing
        if (savedUserDetails == null) {

          await StorageService.saveUserDetails(userDetails);
        }
        
        if (savedNutritionPlan == null) {

          await StorageService.saveNutritionPlan(processedNutritionData);
        }
      }
      
      // Update progress
      setState(() {
        _dataVerified = true;
        _progress = 1.0;
      });
      
      // Add a delay for completion animation
      await Future.delayed(const Duration(milliseconds: 700));
      
      setState(() {
        _isComplete = true;
      });
      
  
      // Navigate to main app screen after a short delay to show completion
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Navigate to diet plan result screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => DietPlanResultScreen(
          userDetails: userDetails,
          nutritionPlan: processedNutritionData,
        )),
      );
      
    } catch (e) {

      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        if (widget.onError != null) {
          widget.onError!(e.toString());
        }
      }
    }
  }

  Widget _buildAnimatedLoader() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating gradient ring
              Transform.rotate(
                angle: _controller.value * 2 * pi,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.0),
                        AppColors.primary.withOpacity(0.5),
                        AppColors.primary,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      startAngle: 0,
                      endAngle: pi * 2,
                      transform: GradientRotation(_controller.value * 2 * pi),
                    ),
                  ),
                ),
              ),
              
              // Inner glossy circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      AppColors.background,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _hasError 
                              ? Colors.red.shade300 
                              : (_isComplete ? Colors.green.shade300 : AppColors.primary.withOpacity(0.3)),
                          _hasError 
                              ? Colors.red.shade500 
                              : (_isComplete ? Colors.green.shade500 : AppColors.primary.withOpacity(0.7)),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _hasError 
                            ? Icons.error_outline 
                            : (_isComplete ? Icons.check_circle : Icons.restaurant_menu),
                        size: 45,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Extra glossy highlight
              Positioned(
                top: 40,
                left: 40,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressStep({
    required String title,
    required bool isCompleted,
    bool isCurrent = false,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCompleted 
                  ? [Colors.green.shade300, Colors.green.shade600]
                  : (isCurrent 
                      ? [AppColors.primary.withOpacity(0.7), AppColors.primary]
                      : [AppColors.textSecondary.withOpacity(0.2), AppColors.textSecondary.withOpacity(0.4)]),
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted 
                    ? Colors.green.withOpacity(0.4)
                    : (isCurrent ? AppColors.primary.withOpacity(0.4) : Colors.transparent),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : isCurrent
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      )
                    : null,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            color: isCompleted 
                ? Colors.green.shade600
                : (isCurrent ? AppColors.textPrimary : AppColors.textSecondary),
            fontWeight: isCompleted || isCurrent ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top spacer
                    const SizedBox(height: 40),
                    
                    // Animated loader
                    _buildAnimatedLoader()
                        .animate(onComplete: (controller) => controller.repeat())
                        .shimmer(duration: const Duration(seconds: 2), curve: Curves.easeInOut),
                    
                    // Status text
                    const SizedBox(height: 50),
                    
                    if (_hasError)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.red.shade50, Colors.red.shade100],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.3, end: 0)
                    else if (_isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.green.shade50, Colors.green.shade100],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          'All Set!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.3, end: 0)
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.05),
                              AppColors.primary.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _loadingMessages[_currentMessageIndex],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate()
                        .fadeIn(duration: const Duration(milliseconds: 300))
                        .then()
                        .fadeOut(delay: const Duration(milliseconds: 2700)),
                    
                    // Progress indicator
                    const SizedBox(height: 40),
                    if (!_hasError && !_isComplete)
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              width: MediaQuery.of(context).size.width * 0.9 * _progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _progress > 0.2 ? Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ) : null,
                              ),
                            ),
                          ],
                        ),
                      ).animate().slideX(begin: -1, end: 0, curve: Curves.easeOut),
                    
                    // Process steps
                    const SizedBox(height: 50),
                    if (!_isComplete)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        shadowColor: Colors.black.withOpacity(0.1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProgressStep(
                                title: 'Saving your details',
                                isCompleted: _userDetailsSaved,
                                isCurrent: !_userDetailsSaved,
                              ),
                              const SizedBox(height: 20),
                              _buildProgressStep(
                                title: 'Calculating your nutrition',
                                isCompleted: _nutritionCalculated,
                                isCurrent: _userDetailsSaved && !_nutritionCalculated,
                              ),
                              const SizedBox(height: 20),
                              _buildProgressStep(
                                title: 'Saving your nutrition plan',
                                isCompleted: _nutritionSaved,
                                isCurrent: _nutritionCalculated && !_nutritionSaved,
                              ),
                              const SizedBox(height: 20),
                              _buildProgressStep(
                                title: 'Verifying all data',
                                isCompleted: _dataVerified,
                                isCurrent: _nutritionSaved && !_dataVerified,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.3, end: 0),
                    
                    // Error message
                    if (_hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Error: $_errorMessage',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                shadowColor: AppColors.primary.withOpacity(0.4),
                                elevation: 8,
                              ),
                              child: const Text(
                                'Go Back',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                    
                    // Food fact
                    if (!_hasError && !_isComplete)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.05),
                                AppColors.primary.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Did you know?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _currentFoodFact,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary.withOpacity(0.8),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: const Duration(milliseconds: 800)),
                    
                    // Success message
                    if (_isComplete)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.green.shade50],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.green.shade300, Colors.green.shade500],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Your personalized nutrition plan is ready!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Taking you to your dashboard...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: const Duration(milliseconds: 300)).slideY(begin: 0.2, end: 0),
                    
                    // Bottom spacer
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 