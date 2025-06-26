import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDateUtils {
  static const String selectedDateKey = 'selected_date';
  
  // Get today's date without time components
  static DateTime getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  
  // Save date to SharedPreferences
  static Future<bool> saveSelectedDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Always use a clean date without time components
      final cleanDate = DateTime(date.year, date.month, date.day);
      
      await prefs.setString(selectedDateKey, cleanDate.toIso8601String());
     
      return true;
    } catch (e) {
     
      return false;
    }
  }
  
  // Load date from SharedPreferences
  static Future<DateTime> getSelectedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = getToday();
      
      // Always default to today's date first
      return today;
      
      /* Commenting out the old implementation that could return a previous date
      final dateString = prefs.getString(selectedDateKey);
      if (dateString == null) {
      
        return today;
      }
      
      final savedDate = DateTime.parse(dateString);
      final cleanDate = DateTime(savedDate.year, savedDate.month, savedDate.day);
      
      // Make sure the date is not in the future
      if (cleanDate.isAfter(today)) {
       
        return today;
      }
      
    
      return cleanDate;
      */
    } catch (e) {
    
      return getToday();
    }
  }
  
  // Format date for display
  static String formatDateForDisplay(DateTime date) {
    final today = getToday();
    final yesterday = today.subtract(const Duration(days: 1));
    
    final cleanDate = DateTime(date.year, date.month, date.day);
    
    if (cleanDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (cleanDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(cleanDate);
    }
  }
  
  // Validate a date to ensure it's not in the future
  static DateTime validateDate(DateTime date) {
    final today = getToday();
    final cleanDate = DateTime(date.year, date.month, date.day);
    
    if (cleanDate.isAfter(today)) {
     
      return today;
    }
    
    return cleanDate;
  }
} 