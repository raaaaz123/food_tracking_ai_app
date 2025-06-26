import 'package:flutter/material.dart';
import '../components/date_selector.dart';
import 'gender_screen.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class DOBScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime? initialBirthDate;
  final bool isUpdate;

  const DOBScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    this.initialBirthDate,
    this.isUpdate = false,
  });

  @override
  State<DOBScreen> createState() => _DOBScreenState();
}

class _DOBScreenState extends State<DOBScreen> {
  late DateTime _selectedDate;
  final double _progressValue = 0.75; // 75% progress

  @override
  void initState() {
    super.initState();
    // Use initial birth date if provided, otherwise default to August 1, 2000
    _selectedDate = widget.initialBirthDate ??
        DateTime(2000, 8, 1);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isVerySmallScreen = screenSize.height < 600;
    
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
              padding: EdgeInsets.symmetric(
                horizontal: 24.0, 
                vertical: isVerySmallScreen ? 12.0 : 16.0
              ),
              child: Row(
                children: List.generate(12, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: index < 3
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 16 : 24),
            // Title and description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s your date of birth?',
                    style: TextStyle(
                      fontSize: isVerySmallScreen 
                          ? 20 
                          : isSmallScreen 
                              ? 24 
                              : 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 8 : 12),
                  Text(
                    'This helps us calculate your daily calorie needs.',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 20 : 32),
            // Date selector
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 20, 
                  vertical: isVerySmallScreen ? 12 : 16
                ),
                child: DateSelector(
                  selectedDate: _selectedDate,
                  onChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  isSmallScreen: isSmallScreen,
                  isVerySmallScreen: isVerySmallScreen,
                ),
              ),
            ),
            // Continue button
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24, 
                vertical: isVerySmallScreen ? 8 : 12
              ),
              color: AppColors.background,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Add haptic feedback
                    HapticFeedback.lightImpact();
                    
                    // Validate age (at least 13 years old)
                    final age =
                        DateTime.now().difference(_selectedDate).inDays ~/ 365;
                    if (age < 13) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'You must be at least 13 years old to use this app'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }

                    if (widget.isUpdate) {
                      // Return selected date if we're updating
                      Navigator.pop(context, _selectedDate);
                    } else {
                      // Continue to gender screen
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GenderScreen(
                            height: widget.height,
                            weight: widget.weight,
                            isMetric: widget.isMetric,
                            birthDate: _selectedDate,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 14
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.isUpdate ? 'Save' : 'Continue',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
