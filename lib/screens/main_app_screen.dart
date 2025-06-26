import 'package:flutter/material.dart';
import 'package:nutrizen_ai/screens/face_workout_screen.dart';

import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import '../dialogs/food_logging_dialog.dart';
import 'scan_food_screen.dart';
import 'exercise_logging_screen.dart';
import 'saved_foods_screen.dart';
import 'food_database_screen.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';



class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  bool _hasRebuiltScreens = false;
  DateTime _selectedDate = DateTime.now();

  // Review dialog tracking
  static const String _lastReviewDialogKey = 'last_review_dialog_main';
  static const int _reviewDialogCooldownDays = 7; // Show review dialog max once per week
  static const String _firstFoodScanKey = 'first_food_scan_completed';

  final List<Widget> _screens = [
    HomeScreen(),
    const MealPlanScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeSubscriptions();
    
    // Track screen view when MainAppScreen is first loaded
    Posthog().screen(
      screenName: 'Main App Screen',
    );
    
    // Track initial tab view
    _trackCurrentTab();
  }

  Future<void> _initializeNotifications() async {
    // Initialize the notification service

  }

  Future<void> _initializeSubscriptions() async {
    // Initialize the subscription service
    try {
      await SubscriptionHandler.init();
    } catch (e) {
      print("Failed to initialize subscription service: $e");
    }
  }

  void _navigateToScreen(Widget screen) {
    // Track screen navigation
    String screenName = 'Unknown Screen';
    Feature? feature;
    
    if (screen is ScanFoodScreen) {
      screenName = 'Scan Food Screen';
      feature = Feature.scanFood;
    } else if (screen is SavedFoodsScreen) {
      screenName = 'Saved Foods Screen';
      feature = Feature.savedFoods;
    } else if (screen is SettingsScreen) {
      screenName = 'Settings Screen';
      feature = Feature.settings;
    } else if (screen is FoodDatabaseScreen) {
      screenName = 'Food Database Screen';
      feature = Feature.foodDatabase;
    } else if (screen is ExerciseLoggingScreen) {
      screenName = 'Exercise Logging Screen';
      feature = Feature.exerciseLogging;
    } else if (screen is FaceWorkoutScreen) {
      screenName = 'Face Workout Screen';
      feature = Feature.faceWorkout;
    }
    
    Posthog().screen(
      screenName: screenName,
    );
    
    if (feature != null) {
      // Use subscription handler to check if feature requires premium
      SubscriptionHandler.accessFeature(
        context, 
        feature: feature, 
        destinationScreen: screen,
      ).then((dynamic value) {
        // If we returned from ScanFoodScreen and value is true (food was added)
        if (value is bool && screen is ScanFoodScreen && value == true) {
          _refreshHomeScreen();
        }
      });
    } else {
      // Fallback for screens without subscription check
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      ).then((result) {
        // If food was added successfully, refresh the HomeScreen
        if (result == true) {
          _refreshHomeScreen();
        }
        
        // Track return to main screen
        Posthog().screen(
          screenName: 'Returned to Main App Screen',
        );
        
        // Track current tab again
        _trackCurrentTab();
      });
    }
  }

  void _refreshHomeScreen() {

    if (_currentIndex == 0) {  // Only refresh if we're on the home screen
      setState(() {
        // Recreate the HomeScreen with a new key to force a complete rebuild
        _screens[0] = HomeScreen(key: UniqueKey());
      });
    }
  }

  void _showQuickActionBottomSheet() {
    // Track bottom sheet open
    Posthog().screen(
      screenName: 'Quick Actions Bottom Sheet',
    );
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // Get available height considering safe areas
        final mediaQuery = MediaQuery.of(context);
        final availableHeight = mediaQuery.size.height - 
                               mediaQuery.padding.top - 
                               mediaQuery.padding.bottom;
                               
        // Calculate optimal height for bottom sheet - increase slightly to avoid overflow
        final bottomSheetHeight = mediaQuery.size.height < 700 
          ? availableHeight * 0.42  // Increased for small screens
          : availableHeight * 0.38;  // Increased for larger screens
                               
        return SafeArea(
          bottom: true,
          child: Container(
            // Adaptive height calculation
            height: bottomSheetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header - Centered with animation
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                  child: Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                
                // Main content - 2 rows of actions
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final List<Map<String, dynamic>> actions = [
                          {
                            'icon': Icons.add_circle_outline,
                            'label': 'Add Exercise',
                            'onTap': () {
                              final screen = ExerciseLoggingScreen(
                                onExerciseAdded: () {
                                  if (!_hasRebuiltScreens) {
                                    _refreshHomeScreen();
                                  }
                                },
                              );
                              _navigateWithSubscriptionCheck(
                                feature: Feature.exerciseLogging,
                                screen: screen,
                                premiumTitle: "Unlock Exercise Tracking",
                                premiumSubtitle: "Get access to advanced exercise tracking and personalized workout recommendations.",
                              );
                            },
                          },
                          {
                            'icon': Icons.face_retouching_natural,
                            'label': 'Face AI',
                            'onTap': () {
                              _navigateWithSubscriptionCheck(
                                feature: Feature.faceWorkout,
                                screen: const FaceWorkoutScreen(),
                                premiumTitle: "Unlock Face AI",
                                premiumSubtitle: "Get access to advanced face analysis and personalized face workout routines.",
                              );
                            },
                          },
                          {
                            'icon': Icons.menu_book,
                            'label': 'Food Database',
                            'onTap': () {
                              final screen = FoodDatabaseScreen(
                                selectedDate: _selectedDate,
                              );
                              _navigateWithSubscriptionCheck(
                                feature: Feature.foodDatabase,
                                screen: screen,
                                premiumTitle: "Access Full Food Database",
                                premiumSubtitle: "Get unlimited access to our comprehensive food database with nutritional details for thousands of items.",
                              );
                            },
                          },
                          {
                            'icon': Icons.camera_alt,
                            'label': 'Scan Food',
                            'onTap': () {
                              final screen = ScanFoodScreen(
                                onFoodLogged: () {
                                  if (mounted) {
                                    _refreshHomeScreen();
                                  }
                                },
                              );
                              // Use the same navigation method as other premium features
                              _navigateWithSubscriptionCheck(
                                feature: Feature.scanFood,
                                screen: screen,
                                premiumTitle: "Unlock Food Scanner",
                                premiumSubtitle: "Get access to our advanced AI-powered food scanner to quickly log your meals.",
                              );
                            },
                          },
                        ];
                        
                        // Split into 2 rows
                        final firstRow = actions.sublist(0, 2);
                        final secondRow = actions.sublist(2);
                        
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // First row
                            Expanded(
                              child: Row(
                                children: firstRow.map((action) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: _buildMinimalActionButton(
                                      icon: action['icon'],
                                      label: action['label'],
                                      onTap: action['onTap'],
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                            // Second row
                            Expanded(
                              child: Row(
                                children: secondRow.map((action) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: _buildMinimalActionButton(
                                      icon: action['icon'],
                                      label: action['label'],
                                      onTap: action['onTap'],
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(
              begin: 1.0,
              end: 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuad,
            );
      },
    );
  }

  Widget _buildMinimalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: const Duration(milliseconds: 300))
      .scale(delay: const Duration(milliseconds: 100), begin: const Offset(0.95, 0.95));
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'Add Food':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodDatabaseScreen(
              selectedDate: _selectedDate,
            ),
          ),
        ).then((result) {
          // If food was successfully added, refresh the HomeScreen
          if (result == true) {

            _refreshHomeScreen();
          }
        });
        break;
      case 'Add Exercise':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseLoggingScreen(
              selectedDate: _selectedDate,
            ),
          ),
        ).then((result) {
          // If exercise was successfully added, refresh the HomeScreen
          if (result == true) {

            _refreshHomeScreen();
          }
        });
        break;
      case 'Settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
  }

  // Track the current tab view
  void _trackCurrentTab() {
    String tabName;
    switch (_currentIndex) {
      case 0:
        tabName = 'Home Tab';
        break;
      case 1:
        tabName = 'Meal Plan Tab';
        break;
      case 2:
        tabName = 'Analytics Tab';
        break;
      case 3:
        tabName = 'Settings Tab';
        break;
      default:
        tabName = 'Unknown Tab';
    }
    
    Posthog().screen(
      screenName: tabName,
    );
  }

  // Updated to navigate directly without subscription check
  void _navigateWithSubscriptionCheck({
    required Feature feature,
    required Widget screen,
    String? premiumTitle,
    String? premiumSubtitle,
  }) {
    // Close the quick action menu
    Navigator.pop(context);

    // Navigate directly to the screen without subscription check
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((result) async {
      // If returning with a positive result, refresh the home screen
      if (result == true) {
        _refreshHomeScreen();
        
        // Check if this was a food scan and handle review dialog
        if (feature == Feature.scanFood) {
          await _handleFoodScanSuccess();
        }
      }
      
      // Track return to main screen
      Posthog().screen(
        screenName: 'Returned to Main App Screen',
    );
      
      // Track current tab again
      _trackCurrentTab();
    });
  }

  // Add this method to test the RevenueCat Paywall V2
  Future<void> _testRevenueCatPaywall() async {
    final screen = ScanFoodScreen(
      onFoodLogged: () {
        if (mounted) {
          _refreshHomeScreen();
        }
      },
    );
    
    // Use the subscription handler to show our custom paywall screen
    await SubscriptionHandler.showSubscriptionScreen(
      context, 
      feature: Feature.scanFood,
      title: "Unlock Food Scanner",
      subtitle: "Get access to our advanced AI-powered food scanner to quickly log your meals.",
    );
  }

  // Handle food scan success and show review dialog if appropriate
  Future<void> _handleFoodScanSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedFirstScan = prefs.getBool(_firstFoodScanKey) ?? false;
      
      if (!hasCompletedFirstScan) {
        // Mark first food scan as completed
        await prefs.setBool(_firstFoodScanKey, true);
        
        // Show review dialog after first successful food scan
        _showReviewDialog();
      }
    } catch (e) {
      print('❌ Error handling food scan success: $e');
    }
  }

  // Show review dialog after first food scan
  Future<void> _showReviewDialog() async {
    // Check if we should show the review dialog based on frequency
    if (!await _shouldShowReviewDialog()) {
      return;
    }
    
    // Wait for 5 seconds before showing the dialog
    await Future.delayed(Duration(seconds: 5));
    
    // Check if dialog should still be shown (user hasn't navigated away)
    if (!mounted) return;
    
    // Track when review dialog is shown
    Posthog().capture(
      eventName: 'review_dialog_shown',
      properties: {
        'source': 'first_food_scan',
      },
    );
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.amber,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Enjoying Our App?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Would you like to help us do more updates and new features by rating 5 stars and leaving a good review?',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Track when user dismisses the review dialog
              Posthog().capture(
                eventName: 'review_dialog_dismissed',
                properties: {
                  'source': 'first_food_scan',
                  'action': 'not_now',
                },
              );
              Navigator.pop(context);
            },
            child: Text(
              'Not Now',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestReview();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Rate 5 Stars',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Check if review dialog should be shown based on frequency
  Future<bool> _shouldShowReviewDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReviewTime = prefs.getInt(_lastReviewDialogKey);
      
      if (lastReviewTime == null) {
        // First time showing the dialog
        await prefs.setInt(_lastReviewDialogKey, DateTime.now().millisecondsSinceEpoch);
        return true;
      }
      
      final lastReviewDate = DateTime.fromMillisecondsSinceEpoch(lastReviewTime);
      final now = DateTime.now();
      final daysSinceLastReview = now.difference(lastReviewDate).inDays;
      
      if (daysSinceLastReview >= _reviewDialogCooldownDays) {
        // Update the last review time
        await prefs.setInt(_lastReviewDialogKey, now.millisecondsSinceEpoch);
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking review dialog frequency: $e');
      return false;
    }
  }

  // Request in-app review
  Future<void> _requestReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      
      // Track the review button click
      Posthog().capture(
        eventName: 'review_button_clicked',
        properties: {
          'source': 'first_food_scan',
        },
      );
      
      // Check if in-app review is available
      if (await inAppReview.isAvailable()) {
        // Request the review
        await inAppReview.requestReview();
        
        // Track the review request
        Posthog().capture(
          eventName: 'review_requested',
          properties: {
            'source': 'first_food_scan',
            'method': 'in_app_review',
          },
        );
      } else {
        // If in-app review is not available, open store listing
        await inAppReview.openStoreListing();
        
        // Track the store listing open
        Posthog().capture(
          eventName: 'store_listing_opened',
          properties: {
            'source': 'first_food_scan',
            'method': 'store_listing',
          },
        );
      }
    } catch (e) {
      print('❌ Error requesting review: $e');
      
      // Track the error
      Posthog().capture(
        eventName: 'review_request_error',
        properties: {
          'source': 'first_food_scan',
          'error': e.toString(),
        },
      );
      
      // Fallback: try to open store listing
      try {
        final InAppReview inAppReview = InAppReview.instance;
        await inAppReview.openStoreListing();
        
        // Track the fallback store listing open
        Posthog().capture(
          eventName: 'store_listing_opened',
          properties: {
            'source': 'first_food_scan',
            'method': 'fallback_store_listing',
          },
        );
      } catch (fallbackError) {
        print('❌ Error opening store listing: $fallbackError');
        
        // Track the fallback error
        Posthog().capture(
          eventName: 'review_fallback_error',
          properties: {
            'source': 'first_food_scan',
            'error': fallbackError.toString(),
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to black for better contrast with white background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // Get the bottom padding to account for navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: LinearGradient(
            colors: [Color(0xFFB8E0C0), Color(0xFF7BC27D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        height: 56,
        width: 56,
        child: FloatingActionButton(
          onPressed: () {
            // Show quick actions directly without premium check
              _showQuickActionBottomSheet();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          heroTag: 'mainScreenFAB',
          child: const Icon(
            Icons.add,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: Container(
          // Adjust height based on bottom padding
          height: 60, // Reduced height
          decoration: BoxDecoration(
            color: AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: StylishBottomBar(
              option: AnimatedBarOptions(
                iconSize: 22, // Reduced icon size
                barAnimation: BarAnimation.transform3D,
                iconStyle: IconStyle.animated,
                opacity: 0.3,
              ),
              items: [
                BottomBarItem(
                  icon: const Icon(Icons.home_rounded),
                  title: const Text('Home'),
                  backgroundColor: Color(0xFF424242),
                  showBadge: false,
                ),
                BottomBarItem(
                  icon: const Icon(Icons.restaurant_menu),
                  title: const Text('Meal Plan'),
                  backgroundColor: Color(0xFF424242),
                ),
                BottomBarItem(
                  icon: const Icon(Icons.bar_chart_rounded),
                  title: const Text('Analytics'),
                  backgroundColor: Color(0xFF424242),
                ),
                BottomBarItem(
                  icon: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  backgroundColor: Color(0xFF424242),
                ),
              ],
              fabLocation: StylishBarFabLocation.center,
              hasNotch: true,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                
                // Track tab change with PostHog
                _trackCurrentTab();
              },
            ),
          ),
        ),
      ),
    );
  }
}