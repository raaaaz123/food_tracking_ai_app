import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import '../screens/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

void showSpecialOfferDialog(
  BuildContext context, {
  Feature? feature,
  String title = "Limited Time Offer",
  String subtitle = "Unlock all premium features with 50% OFF today!",
  VoidCallback? onDismiss,
  bool forceShow = false,
}) async {
  // Check if we should show the offer based on last shown date
  final prefs = await SharedPreferences.getInstance();
  final lastShownDate = prefs.getString('last_offer_shown_date');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day).toString();
  
  // Skip the 7-day check if forceShow is true
  if (!forceShow && lastShownDate != null) {
    final lastDate = DateTime.parse(lastShownDate);
    final daysDifference = now.difference(lastDate).inDays;
    
    if (daysDifference < 7) {
      // Don't show the offer, call onDismiss if provided
      if (onDismiss != null) {
        onDismiss();
      }
      return;
    }
  }
  
  // Save current date as last shown date (only if not forcing show)
  if (!forceShow) {
    await prefs.setString('last_offer_shown_date', today);
  }
  
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6), // Darker backdrop for more focus
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: IntrinsicHeight(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7BC27D), // Medium green
                  Color(0xFFB8E0C0), // Light green
                ],
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background decorative elements - subtle shapes
                Positioned(
                  top: -30,
                  right: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: -40,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.03),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),
                ),
                
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Offer badge at top - Fixed positioning issue
                    Transform.translate(
                      offset: const Offset(0, -55),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF7BC27D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "50% OFF TODAY",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 200), duration: Duration(milliseconds: 400))
                    .slideY(begin: -0.3, end: 0, duration: Duration(milliseconds: 600), curve: Curves.elasticOut),
                    
                    // Header with title and close button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Glowing premium icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF7BC27D).withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.workspace_premium,
                                color: Color(0xFF4CAF50),
                                size: 30,
                              ),
                            ),
                          ).animate()
                              .fadeIn(duration: Duration(milliseconds: 500))
                              .scale(begin: Offset(0.8, 0.8), end: Offset(1, 1), duration: Duration(milliseconds: 500)),
                          
                          SizedBox(height: 16),
                          
                          // Title with premium gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.yellow.shade200,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          SizedBox(height: 8),
                          
                          // Subtitle
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          SizedBox(height: 8),
                          
                          // Time-limited offer indicator
                          _buildTimeLimitedBadge(),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Features list with enhanced visuals - more compact
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildPremiumFeatureRow(Icons.camera_alt_outlined, "Unlimited AI food scanning", "No daily limits"),
                                const SizedBox(height: 10),
                                _buildPremiumFeatureRow(Icons.analytics_outlined, "Advanced nutrition insights", "Detailed reports & analytics"),
                                const SizedBox(height: 10),
                                _buildPremiumFeatureRow(Icons.restaurant_menu_outlined, "Unlimited Daily Meal Plans", "No Limitations for Meal Plans"),
                                const SizedBox(height: 10),
                                _buildPremiumFeatureRow(Icons.widgets_outlined, "Premium Face Glow Plans", "Daily Face Glow Workouts"),
                              ],
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: 300), duration: Duration(milliseconds: 500))
                              .slideY(begin: 0.2, end: 0, duration: Duration(milliseconds: 500), curve: Curves.easeOutQuad),
                          
                          const SizedBox(height: 16),
                          
                          // Action buttons with improved design
                          Row(
                            children: [
                              // No thanks button
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    if (onDismiss != null) {
                                      onDismiss();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withOpacity(0.8),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    "Not Now",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Claim offer button
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    // Navigate to subscription screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SubscriptionScreen(
                                          title: "Dietly Premium",
                                          subtitle: "Unlock premium features at 50% off",
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Color(0xFF4CAF50),
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Claim Your 50% Off",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ).animate()
                                    .fadeIn(delay: Duration(milliseconds: 400), duration: Duration(milliseconds: 400))
                                    .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1), duration: Duration(milliseconds: 400)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Close button - simple, no background
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onDismiss != null) {
                        onDismiss();
                      }
                    },
                    constraints: BoxConstraints(
                      minHeight: 36,
                      minWidth: 36,
                    ),
                    padding: EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 400))
          .slideY(begin: 0.2, end: 0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutQuad),
      );
    },
  );
}

// Premium feature row with icon, title and description
Widget _buildPremiumFeatureRow(IconData icon, String title, String description) {
  return Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(0xFFE8F5E9), // Light green background
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Color(0xFF4CAF50), // Green icon
          size: 20,
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
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      Icon(
        Icons.check_circle,
        color: Color(0xFF4CAF50),
        size: 18,
      ),
    ],
  );
}

// Time limited badge
Widget _buildTimeLimitedBadge() {
  return Container(
    margin: EdgeInsets.symmetric(vertical: 6),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Color(0xFF4CAF50).withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          color: Colors.white,
          size: 14,
        ),
        SizedBox(width: 4),
        Text(
          "Offer ends in 24h",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
      .fadeIn(duration: Duration(milliseconds: 400))
      .then(delay: Duration(milliseconds: 200))
      .tint(color: Colors.white.withOpacity(0.2), duration: Duration(milliseconds: 800));
} 