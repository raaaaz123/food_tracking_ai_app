import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../constants/app_colors.dart';
import '../screens/subscription_screen.dart';
import '../screens/main_app_screen.dart';

class FreeTrialOfferDialog extends StatefulWidget {
  final VoidCallback? onDismiss;

  const FreeTrialOfferDialog({
    Key? key,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<FreeTrialOfferDialog> createState() => _FreeTrialOfferDialogState();
}

class _FreeTrialOfferDialogState extends State<FreeTrialOfferDialog> with SingleTickerProviderStateMixin {
  // Countdown timer
  int _timeLeft = 60 * 60; // 1 hour in seconds
  Timer? _timer;
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Confetti controller
  late ConfettiController _confettiController;
  
  // Button pressed state
  bool _isButtonPressed = false;
  
  @override
  void initState() {
    super.initState();
    
    // Start timer
    _startTimer();
    
    // Track view event in PostHog
    _trackEvent('free_trial_offer_viewed');
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Play confetti when dialog shows
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        // If time expires and user hasn't claimed, track this as expired
        if (!_isButtonPressed) {
          _trackEvent('free_trial_offer_expired');
        }
      }
    });
  }
  
  void _trackEvent(String eventName, {Map<String, Object>? properties}) {
    Posthog().capture(
      eventName: eventName,
      properties: properties ?? {}, // Provide empty map as default
    );
  }
  
  void _handleClaimPressed() {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isButtonPressed = true;
    });
    
    // Track claim event
    _trackEvent('free_trial_offer_claimed', properties: {
      'time_remaining': _timeLeft,
      'time_to_decision': 3600 - _timeLeft,
    });
    
    // Navigate to subscription screen after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionScreen(
            initialShowTrial: true,
            source: 'free_trial_offer',
          ),
        ),
      );
    });
  }
  
  String _formatTimeLeft() {
    final int minutes = (_timeLeft % 3600) ~/ 60;
    final int seconds = _timeLeft % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 600;
    final bool isVerySmallScreen = screenHeight < 500;
    
    // Adjust dialog constraints based on screen size
    final maxHeight = isVerySmallScreen 
        ? screenHeight * 0.85 
        : isSmallScreen 
            ? screenHeight * 0.8 
            : screenHeight * 0.75;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallScreen ? 16 : 24,
        vertical: isVerySmallScreen ? 8 : 16,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: screenWidth * 0.95,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main content
              Container(
                color: AppColors.cardBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 18)
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              // Limited time badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 8 : 12, 
                                  vertical: isVerySmallScreen ? 3 : 4
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.textLight.withOpacity(0.4)),
                                ),
                                child: Text(
                                  "EXCLUSIVE OFFER",
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVerySmallScreen ? 9 : 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: isVerySmallScreen ? 8 : 12),
                              
                              // Confetti source positioned at trial title
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  // Confetti effect
                                  ConfettiWidget(
                                    confettiController: _confettiController,
                                    blastDirection: pi / 2, // Upward direction
                                    emissionFrequency: 0.05,
                                    numberOfParticles: 20,
                                    maxBlastForce: 20,
                                    minBlastForce: 5,
                                    gravity: 0.2,
                                    shouldLoop: false,
                                    colors: const [
                                      AppColors.primary,
                                      AppColors.accent,
                                      AppColors.success,
                                      AppColors.warning,
                                      AppColors.secondary,
                                    ],
                                  ),
                                  
                                  // Title text that confetti emits from
                                  Text(
                                    "3-DAY FREE TRIAL",
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textLight,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isVerySmallScreen ? 4 : 6),
                              Text(
                                "Unlock all premium features",
                                style: TextStyle(
                                  fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14),
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              
                              SizedBox(height: isVerySmallScreen ? 6 : 10),
                              // Congratulations text
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 12 : 16, 
                                  vertical: isVerySmallScreen ? 4 : 5
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Congratulations! You've been selected for this limited offer",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Scrollable main content body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isVerySmallScreen ? 12 : 16, 
                          isVerySmallScreen ? 12 : 16, 
                          isVerySmallScreen ? 12 : 16, 
                          isVerySmallScreen ? 8 : 16
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Premium features section
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 8 : 10, 
                                vertical: isVerySmallScreen ? 4 : 6
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "PREMIUM FEATURES INCLUDED",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isVerySmallScreen ? 11 : (isSmallScreen ? 12 : 13),
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(height: isVerySmallScreen ? 12 : 16),
                            
                            // List of premium features in a more compact layout
                            Wrap(
                              spacing: isVerySmallScreen ? 6 : 8, // Space between items horizontally
                              runSpacing: isVerySmallScreen ? 8 : 12, // Space between items vertically
                              children: [
                                _buildCompactFeature(
                                  title: "Personalized Meal Plans",
                                  icon: Icons.restaurant_menu,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                                _buildCompactFeature(
                                  title: "Unlimited AI Coaching",
                                  icon: Icons.psychology,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                                _buildCompactFeature(
                                  title: "Advanced Progress Tracking",
                                  icon: Icons.trending_up,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                                _buildCompactFeature(
                                  title: "Expert Nutrition Support",
                                  icon: Icons.support_agent,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                                _buildCompactFeature(
                                  title: "Daily Face Workouts",
                                  icon: Icons.face,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                                _buildCompactFeature(
                                  title: "Unlimited Food Scanning",
                                  icon: Icons.camera_alt,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                ),
                              ],
                            ),
                            
                            SizedBox(height: isVerySmallScreen ? 12 : 16),
                            
                            // Countdown timer
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 6 : 8, 
                                horizontal: isVerySmallScreen ? 10 : 12
                              ),
                              decoration: BoxDecoration(
                                color: _timeLeft < 300 
                                    ? AppColors.error.withOpacity(0.1)
                                    : AppColors.background.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _timeLeft < 300 
                                      ? AppColors.error.withOpacity(0.3)
                                      : AppColors.primary.withOpacity(0.2)
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: _timeLeft < 300 ? AppColors.error : AppColors.textSecondary,
                                    size: isVerySmallScreen ? 16 : 18,
                                  ),
                                  SizedBox(width: isVerySmallScreen ? 4 : 6),
                                  Text(
                                    "Offer expires in: ",
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 11 : (isSmallScreen ? 12 : 13),
                                      fontWeight: FontWeight.w500,
                                      color: _timeLeft < 300 ? AppColors.error : AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatTimeLeft(),
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 15),
                                      fontWeight: FontWeight.bold,
                                      color: _timeLeft < 300 ? AppColors.error : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isVerySmallScreen ? 16 : 20),
                            
                            // Claim button with animation
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isButtonPressed ? 1.0 : _pulseAnimation.value,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 52),
                                    child: ElevatedButton(
                                      onPressed: _isButtonPressed ? null : _handleClaimPressed,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: AppColors.textLight,
                                        padding: EdgeInsets.zero,
                                        elevation: 8,
                                        shadowColor: AppColors.success.withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        disabledBackgroundColor: AppColors.success.withOpacity(0.7),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.success,
                                              AppColors.primaryDark,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.success.withOpacity(0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          alignment: Alignment.center,
                                          child: _isButtonPressed
                                              ? SizedBox(
                                                  width: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 22),
                                                  height: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 22),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.bolt,
                                                      color: AppColors.textLight,
                                                      size: isVerySmallScreen ? 18 : (isSmallScreen ? 19 : 20),
                                                    ),
                                                    SizedBox(width: isVerySmallScreen ? 6 : 8),
                                                    Text(
                                                      "CLAIM FREE TRIAL",
                                                      style: TextStyle(
                                                        fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: isVerySmallScreen ? 8 : 12),
                            
                            // Terms text
                            Text(
                              "No payment required. Cancel anytime.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                                color: AppColors.textSecondary,
                              ),
                            ),
                            
                            SizedBox(height: isVerySmallScreen ? 12 : 16),
                            
                            // Skip button
                            GestureDetector(
                              onTap: () {
                                _trackEvent('free_trial_offer_skipped', properties: {
                                  'time_remaining': _timeLeft,
                                });
                                Navigator.of(context).pop();
                                
                                // Navigate to main app screen
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const MainAppScreen(),
                                  ),
                                  (route) => false,
                                );
                                
                                // Call onDismiss if provided
                                if (widget.onDismiss != null) {
                                  widget.onDismiss!();
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.all(isVerySmallScreen ? 6.0 : 8.0),
                                child: Text(
                                  "Skip and continue to app",
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14),
                                    color: AppColors.textSecondary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Bottom padding to ensure content doesn't get cut off
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Close button
              Positioned(
                top: isVerySmallScreen ? 4 : 8,
                right: isVerySmallScreen ? 4 : 8,
                child: GestureDetector(
                  onTap: () {
                    _trackEvent('free_trial_offer_dismissed', properties: {
                      'time_remaining': _timeLeft,
                    });
                    Navigator.of(context).pop();
                    
                    // Navigate to main app screen
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainAppScreen(),
                      ),
                      (route) => false,
                    );
                    
                    // Call onDismiss if provided
                    if (widget.onDismiss != null) {
                      widget.onDismiss!();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(isVerySmallScreen ? 3 : 4),
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: isVerySmallScreen ? 16 : 20,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Compact version of feature item that uses less horizontal space
  Widget _buildCompactFeature({required String title, required IconData icon, required bool isSmallScreen, required bool isVerySmallScreen}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.success,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
  
  // Original method kept for reference but not used
  Widget _buildPremiumFeature({required String title, required String description, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.success,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper function to show the dialog
Future<void> showFreeTrialOfferDialog(BuildContext context, {VoidCallback? onDismiss}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return FreeTrialOfferDialog(onDismiss: onDismiss);
    },
  );
} 