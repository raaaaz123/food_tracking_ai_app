import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static Future<void> checkForUpdates(BuildContext context) async {
    // Store the widget state at the beginning
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Check for updates
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      // Check if widget is still mounted
      if (!context.mounted) return;
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // Show update dialog
        final shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: const Text('A new version of the app is available. Would you like to update now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update'),
              ),
            ],
          ),
        );

        // Check if widget is still mounted
        if (!context.mounted) return;
        
        if (shouldUpdate == true) {
          // Perform immediate update
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {

      // Don't show error to user as this is not critical
    }
  }
} 