import 'package:flutter/material.dart';
import 'dart:developer';
import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../screens/subscription_screen.dart';

enum Feature {
  advancedMealPlanning,
  scanFood,
  exerciseLogging,
  foodDatabase,
  savedFoods,
  faceWorkout,
  settings,
  premium,
}

class SubscriptionHandler {
  // Define which features require premium
  static const Map<Feature, bool> _requiresPremium = {
    Feature.advancedMealPlanning: true,
    Feature.scanFood: true,
    Feature.exerciseLogging: true,
    Feature.foodDatabase: true,
    Feature.savedFoods: false,
    Feature.faceWorkout: true,
    Feature.settings: false,
  };

  // Initialize subscription services
  static Future<void> init() async {
    try {
      await Purchases.configure(
        PurchasesConfiguration('goog_bogyKgTMHLUOsvRQewVrmwlJDix')
      );
      log('RevenueCat configured successfully');
    } catch (e) {
      log('Error configuring RevenueCat: $e');
    }
  }

  // Check if user has premium access
  static Future<bool> isPremium() async {
    try {
      // Add timeout to prevent hanging
      final customerInfo = await Purchases.getCustomerInfo().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          log('❌ RevenueCat getCustomerInfo timed out');
          throw TimeoutException('RevenueCat getCustomerInfo timed out', Duration(seconds: 3));
        },
      );
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      log('❌ Error checking premium status: $e');
      return false;
    }
  }

  // Check if a specific feature requires premium
  static bool requiresPremium(Feature feature) {
    return _requiresPremium[feature] ?? false;
  }

  // Navigate to feature with subscription gate check
  static Future<dynamic> accessFeature(
    BuildContext context, {
    required Feature feature,
    required Widget destinationScreen,
    String? premiumTitle,
    String? premiumSubtitle,
  }) async {
    log('SubscriptionHandler.accessFeature called for feature: $feature');
    
    // Check if feature requires premium
    final featureNeedsPremium = requiresPremium(feature);
    log('Feature requires premium: $featureNeedsPremium');
    
    if (!featureNeedsPremium) {
      // Feature doesn't require premium, navigate directly
      log('Feature does not require premium, navigating directly');
      return await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => destinationScreen),
      );
    }

    // Check if user is premium
    try {
      log('Checking if user has premium subscription...');
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey('premium_access');
      log('User has premium subscription: $isPremium');
      log('Available entitlements: ${customerInfo.entitlements.active.keys.join(", ")}');
      
      if (isPremium) {
        // User is premium, navigate directly
        log('User has premium, navigating directly');
        return await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      }
      
      log('User is not premium, showing subscription screen');
      // User is not premium and feature requires it - show subscription screen
      return await showSubscriptionScreen(context, feature: feature, title: premiumTitle, subtitle: premiumSubtitle);
    } catch (e) {
      log('Error checking premium status: $e - Showing subscription screen anyway');
      // If there's an error checking premium status, show the subscription screen anyway
      return await showSubscriptionScreen(context, feature: feature, title: premiumTitle, subtitle: premiumSubtitle);
    }
  }
  
  // Show subscription screen for a specific feature
  static Future<void> showSubscriptionScreen(BuildContext context, {
    required Feature feature,
    String? title,
    String? subtitle,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubscriptionScreen(
          title: title ?? "Premium Access Required",
          subtitle: subtitle ?? "Upgrade to premium to access this feature.",
        ),
      ),
    );
  }
} 