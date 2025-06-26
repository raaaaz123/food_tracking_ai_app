import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/widget_service.dart';
import 'package:home_widget/home_widget.dart';

class WidgetPromoDialog {
  static const String _widgetPromoShownKey = 'widget_promo_shown';
  static bool _isWidgetAvailable = false;

  // Check if widgets are supported on this platform
  static Future<bool> _checkWidgetAvailability() async {
    try {
      // Try to save some dummy data to check if widgets are available
      await HomeWidget.saveWidgetData('test_key', 'test_value');
      _isWidgetAvailable = true;
      return true;
    } catch (e) {
     
      _isWidgetAvailable = false;
      return false;
    }
  }

  // Check if we should show the widget promo dialog
  static Future<bool> shouldShowWidgetPromo() async {
    // First check if widgets are even available on this platform
    if (!await _checkWidgetAvailability()) {
      return false; // Don't show promo if widgets aren't available
    }
    
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_widgetPromoShownKey) ?? false);
  }

  // Mark the promo as shown in SharedPreferences
  static Future<void> markWidgetPromoAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetPromoShownKey, true);
  }

  // Show the widget promo dialog
  static Future<void> showWidgetPromoDialog(BuildContext context) async {
    // Skip showing promo if widgets aren't available
    if (!_isWidgetAvailable) {
     
      return;
    }
    
    if (!(await shouldShowWidgetPromo())) {
      return; // Don't show if already shown
    }

    await markWidgetPromoAsShown();

    // Using showDialog instead of showModalBottomSheet for better attention
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildDialogContent(context),
        );
      },
    );
  }

  // Show the widget promo dialog, always show regardless of previous shown status
  static Future<void> showWidgetPromoForceDialog(BuildContext context) async {
    // Skip showing promo if widgets aren't available
    if (!_isWidgetAvailable) {
      // Try to reinitialize widget availability
      await _checkWidgetAvailability();
      if (!_isWidgetAvailable) {
        
        return;
      }
    }

    // Using showDialog instead of showModalBottomSheet for better attention
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildDialogContent(context),
        );
      },
    );
  }

  static Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF5A52DF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.widgets_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          const Text(
            "Track Nutrition on Home Screen!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 16),
          
          // Description
          const Text(
            "Add our widget to your home screen to easily track your daily nutrition goals without opening the app.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9E9EAB),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          
          // Widget Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/widget_preview.png',
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.widgets_outlined,
                        size: 60,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Widget Preview",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Maybe Later"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Request permission and guide to add widget
                    await _requestPermissionAndShowGuide(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Add Widget"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _requestPermissionAndShowGuide(BuildContext context) async {
    if (!_isWidgetAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widgets are not available on this platform.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    bool hasPermission = false;
    
    // Request permission for widgets - since Permission doesn't have appWidget, we'll check if we can
    // update the widget directly without explicit permission
    try {
      // Initialize the widget and check if we can update it
      await HomeWidget.saveWidgetData('test_key', 'test_value');
      hasPermission = true;
    } catch (e) {
  
      // Try requesting standard storage permissions which are often needed
      var status = await Permission.storage.request();
      hasPermission = status.isGranted;
    }
    
    if (hasPermission) {
      // Show a guide on how to add the widget
      await _showWidgetGuide(context);
      
      // Initialize the widget with current data
      await WidgetService.updateNutritionWidget();
    } else {
      // Show a message that permission was denied
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied. You can enable it later in app settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> _showWidgetGuide(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "How to Add the Widget",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/widget_guide.png', 
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey.withOpacity(0.1),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "1. Long press on your home screen\n"
                  "2. Tap 'Widgets' or '+' button\n"
                  "3. Find 'Dietly AI' widgets\n"
                  "4. Drag the nutrition widget to your home screen",
                  style: TextStyle(
                    color: Color(0xFF9E9EAB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Got it!"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 