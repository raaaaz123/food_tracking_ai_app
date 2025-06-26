import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import 'diet_screen.dart';

class NotificationPermissionScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;
  final String gender;
  final String motivationGoal;
  final int workoutsPerWeek;

  const NotificationPermissionScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
    required this.gender,
    required this.motivationGoal,
    required this.workoutsPerWeek,
  });

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  
  // For animation
  late AnimationController _animationController;
  
  // Progress value
  final double _progressValue = 0.75; // 75% progress

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _animationController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Request permission using permission_handler
  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });
        await Posthog().capture(
  eventName: 'notification_allowed',
);
    try {
      // For Android, check and request notification permission
      if (Platform.isAndroid) {
        // Get current status
        PermissionStatus status = await Permission.notification.status;
  
        
        // Request if not already granted
        if (!status.isGranted) {
          status = await Permission.notification.request();
 
        }
        
        // Handle exact alarm permission for older versions
        if (status.isGranted) {
         
        }
      } 
      // For iOS
      else if (Platform.isIOS) {
       
      }
      
      // Initialize notification channels and settings
  
      
      // Navigate to next screen after permission handling
      _navigateToNextScreen();
    } catch (e) {

      
      // Navigate anyway in case of error
      _navigateToNextScreen();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToNextScreen() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DietScreen(
          height: widget.height,
          weight: widget.weight,
          isMetric: widget.isMetric,
          birthDate: widget.birthDate,
          workoutsPerWeek: widget.workoutsPerWeek,
          gender: widget.gender,
          motivationGoal: widget.motivationGoal, weightGoal: '',
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
           Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: List.generate(12, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: index < 7
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            const SizedBox(height: 24),
            
            // Title and description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Notifications',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get timely reminders for your workouts and meal tracking.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bell icon with animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 4 * _animationController.value - 2),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              size: isSmallScreen ? 48 : 56,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    
                    // Benefits card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why Enable Notifications?',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBenefitItem(
                            icon: Icons.fitness_center,
                            title: 'Workout Reminders',
                            description: 'Get notified when it\'s time for your scheduled workouts',
                            isSmallScreen: isSmallScreen,
                          ),
                          const SizedBox(height: 16),
                          _buildBenefitItem(
                            icon: Icons.restaurant,
                            title: 'Meal Tracking',
                            description: 'Reminders to log your meals and maintain your nutrition goals',
                            isSmallScreen: isSmallScreen,
                          ),
                          const SizedBox(height: 16),
                          _buildBenefitItem(
                            icon: Icons.local_fire_department,
                            title: 'Streak Notifications',
                            description: 'Celebrate your achievements and maintain your daily streaks',
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Fixed bottom buttons
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Later button
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : _navigateToNextScreen,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Allow button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _requestNotificationPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Allow',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 15 : 16,
                                fontWeight: FontWeight.bold,
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
  
  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isSmallScreen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: isSmallScreen ? 14 : 16,
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
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
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
} 