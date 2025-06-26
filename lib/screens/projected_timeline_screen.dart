import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/ai_workout_service.dart';
import '../constants/app_colors.dart';
import '../models/user_details.dart';
import '../services/storage_service.dart';
import 'nutrition_loading_screen.dart';

class ProjectedTimelineScreen extends StatefulWidget {
  final UserDetails userDetails;
  
  const ProjectedTimelineScreen({
    Key? key,
    required this.userDetails,
  }) : super(key: key);

  @override
  State<ProjectedTimelineScreen> createState() => _ProjectedTimelineScreenState();
}

class _ProjectedTimelineScreenState extends State<ProjectedTimelineScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Timeline projection data
  late DateTime _projectedDate;
  late double _startWeight;
  late double _targetWeight;
  late double _weightChangePerWeek;
  late int _totalWeeks;
  
  @override
  void initState() {
    super.initState();
    Posthog().screen(screenName: 'Projected Timeline Screen');
    _loadProjection();
  }
  
  Future<void> _loadProjection() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Get the user details
      _startWeight = widget.userDetails.weight;
      _targetWeight = widget.userDetails.targetWeight;
      
      // Store the user's selected weight change speed
      _weightChangePerWeek = widget.userDetails.weightChangeSpeed;
      
      // Get AI-optimized projection based on user's selected pace
      final projectionData = await AIWorkoutService.getWeightGoalProjection(
        startWeight: _startWeight,
        targetWeight: _targetWeight,
        weightGoal: widget.userDetails.weightGoal,
        weightChangeSpeed: _weightChangePerWeek, // Pass user's selected speed to AI
      );
      
      setState(() {
        // Use AI's recommended timeline but keep user's selected pace
        _totalWeeks = projectionData['totalWeeks'];
        
        // Calculate projected end date
        _projectedDate = DateTime.now().add(Duration(days: _totalWeeks * 7));
        
        _isLoading = false;
      });
      
      // Save the projection data to local storage for other screens to use
      await StorageService.saveTimelineProjection({
        'projectedDate': _projectedDate.toIso8601String(),
        'startWeight': _startWeight,
        'targetWeight': _targetWeight,
        'weightChangePerWeek': _weightChangePerWeek,
        'totalWeeks': _totalWeeks,
        'isWeightLoss': _targetWeight < _startWeight,
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        
        // Fallback values if AI service fails
        // Calculate based on user selected pace
        final double weightDifference = (_targetWeight - _startWeight).abs();
        _totalWeeks = (weightDifference / _weightChangePerWeek).ceil();
        _projectedDate = DateTime.now().add(Duration(days: _totalWeeks * 7));
      });
      
      // Save fallback values to storage
      await StorageService.saveTimelineProjection({
        'projectedDate': _projectedDate.toIso8601String(),
        'startWeight': _startWeight,
        'targetWeight': _targetWeight,
        'weightChangePerWeek': _weightChangePerWeek,
        'totalWeeks': _totalWeeks,
        'isWeightLoss': _targetWeight < _startWeight,
      });
    }
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MMMM d yyyy').format(date);
  }
  
  void _handleNext() {
    HapticFeedback.mediumImpact();
    
    // Navigate to nutrition loading screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionLoadingScreen(
          userDetails: widget.userDetails,
          targetWeight: widget.userDetails.targetWeight,
          onError: (errorMessage) {
            // Handle error if needed
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 600;
    
    // Adjust sizes based on screen dimensions
    final horizontalPadding = screenWidth * 0.05;
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final titleFontSize = isSmallScreen ? 22.0 : 26.0;
    final subtitleFontSize = isSmallScreen ? 16.0 : 18.0;
    final bodyFontSize = isSmallScreen ? 14.0 : 16.0;
    final buttonHeight = isSmallScreen ? 48.0 : 56.0;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer animated circle
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: null,
                          strokeWidth: 3,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                    
                    // Icon in center
                    Icon(
                      Icons.fitness_center,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Creating your personalized timeline...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: bodyFontSize + 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Optimizing for maximum results',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: bodyFontSize,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Determine if weight goal is loss or gain
    final isWeightLoss = widget.userDetails.targetWeight < widget.userDetails.weight;
    
    // Weight format
    final String weightUnit = widget.userDetails.isMetric ? 'kg' : 'lbs';
    
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: Colors.black, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Journey progress steps
                    _buildGameProgressBar(context, 0.9),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    
                    // Achievement badge
                    _buildAchievementBadge(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    
                    // Journey title with animation
                    _buildAnimatedTitle(titleFontSize),
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    
                    // Projected progress card
                    _buildProjectedCard(context, isSmallScreen, subtitleFontSize, bodyFontSize, weightUnit),
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    
                    // Your pace section with gamified elements
                    _buildYourPaceSection(isSmallScreen, bodyFontSize, weightUnit),
                    
                    // Timeline visualization
                    _buildTimelineWithMilestones(isSmallScreen, bodyFontSize, isWeightLoss),
                    
                    SizedBox(height: isSmallScreen ? 16 : 24),
                  ],
                ),
              ),
            ),
          ),
          
          // Fixed position next button
          _buildNextButton(horizontalPadding, isSmallScreen, buttonHeight),
        ],
      ),
    );
  }
  
  Widget _buildGameProgressBar(BuildContext context, double progress) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "JOURNEY PROGRESS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Stack(
            children: [
              // Background track
              Container(
                height: 10,
                width: double.infinity,
                            decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              // Progress indicator
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * value * 0.9,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withBlue(150),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                          ),
                        );
                },
              ),
              // Milestone dots
              Positioned(
                top: 0,
                left: MediaQuery.of(context).size.width * 0.22 * 0.9,
                child: _buildMilestoneDot(true),
              ),
              Positioned(
                top: 0,
                left: MediaQuery.of(context).size.width * 0.45 * 0.9,
                child: _buildMilestoneDot(true),
              ),
              Positioned(
                top: 0,
                left: MediaQuery.of(context).size.width * 0.68 * 0.9,
                child: _buildMilestoneDot(true),
              ),
              Positioned(
                top: 0,
                left: MediaQuery.of(context).size.width * 0.9 * 0.9,
                child: _buildMilestoneDot(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMilestoneDot(bool completed) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: completed ? AppColors.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: completed ? AppColors.primary : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: completed ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ] : null,
      ),
      child: completed
          ? Icon(Icons.check, color: Colors.white, size: 12)
          : Icon(Icons.flag, color: Colors.grey.shade400, size: 10),
    );
  }
  
  Widget _buildAchievementBadge(bool isSmallScreen) {
    return Center(
      child: Container(
        width: isSmallScreen ? 70 : 80,
        height: isSmallScreen ? 70 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(0xFF7BC27D), // Light green
              AppColors.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
                      children: [
            // Glow effect
                        Container(
              width: isSmallScreen ? 60 : 70,
              height: isSmallScreen ? 60 : 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                          ),
            ),
            // Icon
            Icon(
                            Icons.fitness_center,
                            color: Colors.white,
              size: isSmallScreen ? 32 : 36,
                          ),
            // Badge text
            Positioned(
              bottom: isSmallScreen ? 12 : 15,
                          child: Text(
                "UNLOCK",
                            style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 8 : 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
      ),
    );
  }
  
  Widget _buildAnimatedTitle(double fontSize) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Center(
              child: Text(
                "Your Success Timeline",
                textAlign: TextAlign.center,
                      style: TextStyle(
                  fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
                      ),
                    ),
        );
      },
    );
  }
  
  Widget _buildProjectedCard(BuildContext context, bool isSmallScreen, double subtitleFontSize, 
      double bodyFontSize, String weightUnit) {
    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFF9FCFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
                            spreadRadius: 0,
            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              SizedBox(width: 12),
                          Text(
                "Your goal date",
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                            ),
                          ),
            ],
          ),
          SizedBox(height: 16),
                          
          // Target date and weight with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(30 * (1 - value), 0),
                  child: Text(
                            "${_targetWeight.toStringAsFixed(0)} $weightUnit by ${_formatDate(_projectedDate)}",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
                          ),
          SizedBox(height: isSmallScreen ? 20 : 30),
                          
                          // Graph visualization
                          SizedBox(
            height: isSmallScreen ? 160 : 200,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: TimelineGraphPainter(
                                startWeight: _startWeight,
                                targetWeight: _targetWeight,
                                weightUnit: weightUnit,
                isWeightLoss: _targetWeight < _startWeight,
                                startDate: DateTime.now(),
                                endDate: _projectedDate,
                              ),
                            ),
                          ),
                          
                          // Timeline labels
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                                "Today",
                                style: TextStyle(
                      color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                      fontSize: bodyFontSize - 1,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                                ),
                              ),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(_projectedDate),
                                style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: bodyFontSize - 1,
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
  
  Widget _buildYourPaceSection(bool isSmallScreen, double bodyFontSize, String weightUnit) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
                      child: Column(
                        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.speed_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
                          Text(
                "YOUR PERSONALIZED PACE",
                            style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                ),
                            ),
            ],
                          ),
          SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + (value * 0.5),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF7BC27D),
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                            ),
                            child: Text(
                              "${_weightChangePerWeek.toStringAsFixed(1)} $weightUnit/week",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 22 : 26,
                                fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                                color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  "AI Optimized: ${_totalWeeks} weeks",
                  style: TextStyle(
                    fontSize: bodyFontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.thumb_up_alt_rounded,
                color: Colors.amber,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                "Perfect for long-term success!",
                          style: TextStyle(
                  fontSize: bodyFontSize - 1,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimelineWithMilestones(bool isSmallScreen, double bodyFontSize, bool isWeightLoss) {
    final milestones = [
      {"week": _totalWeeks ~/ 4, "text": "First Results"},
      {"week": _totalWeeks ~/ 2, "text": "Halfway Point"},
      {"week": _totalWeeks - 1, "text": "Final Sprint"}
    ];
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "YOUR JOURNEY MILESTONES",
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
          SizedBox(height: 16),
                    Container(
            height: isSmallScreen ? 120 : 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                      ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                        width: 40,
                        height: 40,
                            decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${milestones[index]["week"]}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                            ),
                      ),
                    ),
                      SizedBox(height: 8),
                    Text(
                        "Week ${milestones[index]["week"]}",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                      ),
                    ),
                      SizedBox(height: 4),
                      Text(
                        "${milestones[index]["text"]}",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "+${(index + 1) * 15} XP",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNextButton(double horizontalPadding, bool isSmallScreen, double buttonHeight) {
    return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isSmallScreen ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
              elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "START YOUR JOURNEY",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    ),
                  ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
                ),
              ),
            ),
      ),
    );
  }
}

// Custom painter for the graph visualization
class TimelineGraphPainter extends CustomPainter {
  final double startWeight;
  final double targetWeight;
  final String weightUnit;
  final bool isWeightLoss;
  final DateTime startDate;
  final DateTime endDate;
  
  TimelineGraphPainter({
    required this.startWeight,
    required this.targetWeight,
    required this.weightUnit,
    required this.isWeightLoss,
    required this.startDate,
    required this.endDate,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Adjust sizes based on canvas size
    final bool isSmallCanvas = size.width < 300;
    final double pointRadius = isSmallCanvas ? 4.0 : 6.0;
    final double labelFontSize = isSmallCanvas ? 12.0 : 14.0;
    final double strokeWidth = isSmallCanvas ? 2.0 : 3.0;
    
    // Define colors and styles
    final greenGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.green.shade400.withOpacity(0.7),
        Colors.green.shade400.withOpacity(0.0),
      ],
    );
    
    final linePaint = Paint()
      ..color = Colors.green.shade400
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final pointPaint = Paint()
      ..color = Colors.green.shade400
      ..style = PaintingStyle.fill;
    
    final pointStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSmallCanvas ? 1.5 : 2.0;
    
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Draw grid lines
    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // Calculate control points for curve
    final startX = 0.0;
    final endX = size.width;
    
    // For weight loss, the start is higher than end
    // For weight gain, the start is lower than end
    final startY = isWeightLoss ? size.height * 0.2 : size.height * 0.8;
    final endY = isWeightLoss ? size.height * 0.8 : size.height * 0.2;
    
    // Create curve with two control points
    final path = Path();
    path.moveTo(startX, startY);
    
    // Control points for smooth S-curve
    final controlX1 = size.width * 0.3;
    final controlY1 = isWeightLoss ? size.height * 0.2 : size.height * 0.8;
    final controlX2 = size.width * 0.6;
    final controlY2 = isWeightLoss ? size.height * 0.8 : size.height * 0.2;
    
    path.cubicTo(
      controlX1, controlY1,
      controlX2, controlY2,
      endX, endY,
    );
    
    // Draw curve
    canvas.drawPath(path, linePaint);
    
    // Fill area under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(endX, size.height);
    fillPath.lineTo(startX, size.height);
    fillPath.close();
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      fillPath,
      Paint()..shader = greenGradient.createShader(rect),
    );
    
    // Draw start and end points with labels
    
    // Start point
    canvas.drawCircle(
      Offset(startX, startY),
      pointRadius + 2,
      pointStrokePaint,
    );
    canvas.drawCircle(
      Offset(startX, startY),
      pointRadius,
      pointPaint,
    );
    
    // Draw start weight label
    _drawWeightLabel(
      canvas, 
      "${startWeight.toStringAsFixed(0)} $weightUnit",
      Offset(startX + 5, startY - 25),
      Colors.green.shade400,
      labelFontSize,
      isSmallCanvas,
    );
    
    // End point
    canvas.drawCircle(
      Offset(endX, endY),
      pointRadius + 2,
      pointStrokePaint,
    );
    canvas.drawCircle(
      Offset(endX, endY),
      pointRadius,
      pointPaint,
    );
    
    // Draw end weight label
    _drawWeightLabel(
      canvas, 
      "${targetWeight.toStringAsFixed(0)} $weightUnit",
      Offset(endX - 70, endY - 25),
      Colors.green.shade400,
      labelFontSize,
      isSmallCanvas,
    );
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
    
    // Adjust padding based on canvas size
    final paddingH = isSmallCanvas ? 6.0 : 8.0;
    final paddingV = isSmallCanvas ? 3.0 : 4.0;
    
    // Draw background for the label
    final rect = Rect.fromLTWH(
      offset.dx - paddingH,
      offset.dy - paddingV,
      textPainter.width + (paddingH * 2),
      textPainter.height + (paddingV * 2),
    );
    
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(isSmallCanvas ? 8.0 : 12.0),
    );
    
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white,
    );
    
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSmallCanvas ? 1.0 : 1.5,
    );
    
    textPainter.paint(canvas, offset);
  }
  
  @override
  bool shouldRepaint(TimelineGraphPainter oldDelegate) =>
      oldDelegate.startWeight != startWeight ||
      oldDelegate.targetWeight != targetWeight ||
      oldDelegate.isWeightLoss != isWeightLoss;
} 