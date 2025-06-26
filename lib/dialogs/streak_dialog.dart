import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart'; // Import global app colors
import '../services/subscription_handler.dart'; // Add subscription handler import

/// A dialog that displays the user's food logging streak in a gamified way
class StreakDialog extends StatefulWidget {
  final int currentStreak;
  final List<bool> weeklyLogging;

  const StreakDialog({
    Key? key,
    required this.currentStreak,
    required this.weeklyLogging,
  }) : super(key: key);

  @override
  State<StreakDialog> createState() => _StreakDialogState();
}

class _StreakDialogState extends State<StreakDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Use global app colors
  final Color _primaryColor = AppColors.primary;
  final Color _accentColor = AppColors.accent;
  final Color _fireColor1 = Color.fromARGB(255, 248, 64, 64); // Orange
  final Color _fireColor2 = const Color.fromARGB(255, 239, 137, 73);
  final Color _activeColor = AppColors.success;
  final Color _inactiveColor = Color.fromARGB(255, 224, 224, 224);
  final Color _textColor = AppColors.textPrimary;
  final Color _lightTextColor = AppColors.textSecondary;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0),
      ),
    );
    
    // Start animation
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isVerySmallScreen = size.height < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12, 
        vertical: isVerySmallScreen ? 8 : 16
      ),
      child: _buildDialogContent(context, isSmallScreen, isVerySmallScreen),
    );
  }
  
  Widget _buildDialogContent(BuildContext context, bool isSmallScreen, bool isVerySmallScreen) {
    return IntrinsicHeight(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 340,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with flame and streak number
            _buildHeader(isSmallScreen, isVerySmallScreen),
            
            // Content area - no longer using Expanded
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Week day indicators
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12, 
                      vertical: isVerySmallScreen ? 6 : 8
                    ),
                    child: _buildWeekIndicator(isSmallScreen, isVerySmallScreen),
                  ),
                  
                  // Stats row - only show if streak > 0
                  if (widget.currentStreak > 0) 
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isVerySmallScreen ? 4 : 6,
                      ),
                      child: _buildStatsRow(isSmallScreen, isVerySmallScreen),
                    ),
                  
                  // Bottom padding to ensure content doesn't get cut off
                  SizedBox(height: isVerySmallScreen ? 8 : 12),
                ],
              ),
            ),
            
            // Action buttons - fixed at bottom
            Container(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 12 : 16,
                isVerySmallScreen ? 8 : 12,
                isSmallScreen ? 12 : 16,
                isVerySmallScreen ? 12 : 16
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Close button
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 6 : 8),
                        backgroundColor: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add Food button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Remove premium check and directly navigate
                        Navigator.pop(context, 'add_food');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 6 : 8),
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: isSmallScreen ? 14 : 16),
                          SizedBox(width: 4),
                          Text(
                            'Add Food',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 12 : 13,
                            ),
                          ),
                        ],
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
  
  Widget _buildHeader(bool isSmallScreen, bool isVerySmallScreen) {
    return Container(
      padding: EdgeInsets.only(
        top: isVerySmallScreen ? 12 : 16, 
        bottom: isVerySmallScreen ? 8 : 10
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Streak count display with fire icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              children: [
                // Fire icon
                Container(
                  width: isVerySmallScreen ? 40 : (isSmallScreen ? 50 : 60),
                  height: isVerySmallScreen ? 40 : (isSmallScreen ? 50 : 60),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_fireColor1, _fireColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _fireColor1.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: isVerySmallScreen ? 24 : (isSmallScreen ? 30 : 36),
                    ),
                  ),
                ),
                SizedBox(height: isVerySmallScreen ? 6 : 8),
                
                // Streak number above DAY STREAK text
                Text(
                  '${widget.currentStreak}',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 40),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // DAY STREAK text
                Text(
                  'DAYS STREAK',
                  style: TextStyle(
                    color: _lightTextColor,
                    fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isVerySmallScreen ? 6 : 8),
          
          // Motivational text
          FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.currentStreak > 0 ? _primaryColor.withOpacity(0.1) : _fireColor1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.currentStreak > 0
                    ? '🔥 You\'re on fire! Keep it up! 🔥'
                    : '🍎 Start your streak today! 🍎',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.currentStreak > 0 ? _primaryColor : _fireColor2,
                  fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWeekIndicator(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last 7 Days',
                style: TextStyle(
                  color: _textColor,
                  fontSize: isVerySmallScreen ? 11 : (isSmallScreen ? 13 : 14),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMM yyyy').format(DateTime.now()),
                style: TextStyle(
                  color: _lightTextColor,
                  fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 11 : 12),
                ),
              ),
            ],
          ),
        ),
        
        // Day indicators with clean white background
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12), 
            horizontal: 4
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              // Calculate the date for this day
              final date = DateTime.now().subtract(Duration(days: 6 - index));
              final dayName = DateFormat('E').format(date)[0]; // First letter of day name
              final isToday = index == 6;
              
              // Check if food was logged on this day
              final dayIndex = 6 - index; // Reverse index to match weeklyLogging
              final isLogged = widget.weeklyLogging.length > dayIndex ? widget.weeklyLogging[dayIndex] : false;
              
              // Calculate if this day is part of the streak
              // A day is part of streak if it has food logged and so did all days after it
              bool isPartOfStreak = false;
              if (isLogged) {
                isPartOfStreak = true;
                for (int i = 0; i < dayIndex; i++) {
                  if (!widget.weeklyLogging[i]) {
                    isPartOfStreak = false;
                    break;
                  }
                }
              }
              
              // Determine circle colors - light grey for normal, green for streak
              final Color circleColor = isLogged ? _activeColor : Colors.grey.shade200;
              final bool showCheck = isLogged; // Show check only if food was logged
              
              return FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    // Modern day indicator with clean styling
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isVerySmallScreen ? 26 : (isSmallScreen ? 30 : 36),
                      height: isVerySmallScreen ? 26 : (isSmallScreen ? 30 : 36),
                      decoration: BoxDecoration(
                        color: isLogged ? circleColor : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(
                          color: _primaryColor,
                          width: 2.0,
                        ) : null,
                      ),
                      child: Center(
                        child: showCheck
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 2 : 4),
                    // Day label with clean styling
                    Text(
                      dayName,
                      style: TextStyle(
                        color: isToday ? _primaryColor : _textColor,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 11),
                      ),
                    ),
                    // Date number
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: _lightTextColor,
                        fontSize: isVerySmallScreen ? 7 : (isSmallScreen ? 9 : 10),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
  
  // Stats row to show streak statistics with clean UI
  Widget _buildStatsRow(bool isSmallScreen, bool isVerySmallScreen) {
    // Calculate streak stats
    final loggingDays = widget.weeklyLogging.where((day) => day).length;
    final completionRate = loggingDays / widget.weeklyLogging.length;
    
    return Container(
      padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            title: '$loggingDays/7',
            subtitle: 'Days',
            icon: Icons.check_circle_outline,
            color: _activeColor,
            isSmallScreen: isSmallScreen,
            isVerySmallScreen: isVerySmallScreen,
          ),
          _buildStatItem(
            title: '${(completionRate * 100).toInt()}%',
            subtitle: 'Complete',
            icon: Icons.pie_chart_outline,
            color: _primaryColor,
            isSmallScreen: isSmallScreen,
            isVerySmallScreen: isVerySmallScreen,
          ),
          _buildStatItem(
            title: '${widget.currentStreak}',
            subtitle: 'Current',
            icon: Icons.local_fire_department_outlined,
            color: _fireColor2,
            isSmallScreen: isSmallScreen,
            isVerySmallScreen: isVerySmallScreen,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon, 
            color: color, 
            size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18)
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 4 : 6),
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: _lightTextColor,
            fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 11),
          ),
        ),
      ],
    );
  }
} 