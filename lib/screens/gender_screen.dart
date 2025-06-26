import 'package:flutter/material.dart';
import 'goals_screen.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class GenderScreen extends StatefulWidget {
  final double height;
  final double weight;
  final bool isMetric;
  final DateTime birthDate;

  const GenderScreen({
    super.key,
    required this.height,
    required this.weight,
    required this.isMetric,
    required this.birthDate,
  });

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selectedGender;
  final double _progressValue = 0.40; // 40% progress

  final Map<String, IconData> _genderIcons = {
    'Male': Icons.male,
    'Female': Icons.female,
    'Other': Icons.person,
  };

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenHeight < 600;
    final bool isVerySmallScreen = screenHeight < 500;
    
    // Adjust paddings and spacings based on screen size
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 24.0);
    
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
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress indicator
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0, 
                        vertical: isVerySmallScreen ? 8.0 : 16.0
                      ),
                      child: Row(
                        children: List.generate(12, (index) {
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: index < 4
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 12 : verticalSpacing),
                    
                    // Title and description
                    Text(
                      'Choose Your Gender.',
                      style: TextStyle(
                        fontSize: isVerySmallScreen 
                            ? 22 
                            : isSmallScreen 
                                ? 26 
                                : 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
                    Text(
                      'This will be used to calibrate your custom plan.',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16),
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 16 : verticalSpacing),
                    
                    // Gender options with responsive sizing
                    _buildGenderOption('Male', isSmallScreen, isVerySmallScreen),
                    SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
                    _buildGenderOption('Female', isSmallScreen, isVerySmallScreen),
                    SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
                    _buildGenderOption('Other', isSmallScreen, isVerySmallScreen),
                    
                    // Bottom padding to ensure content doesn't get hidden behind button
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // Static Next button at bottom
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isVerySmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedGender != null
                      ? () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GoalsScreen(
                                height: widget.height,
                                weight: widget.weight,
                                isMetric: widget.isMetric,
                                birthDate: widget.birthDate,
                                gender: _selectedGender!,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 14,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 18),
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

  Widget _buildGenderOption(String gender, bool isSmallScreen, bool isVerySmallScreen) {
    final isSelected = _selectedGender == gender;
    
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Adjust sizes based on screen dimensions
    final iconSize = isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);
    final fontSize = isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0);
    final verticalPadding = isVerySmallScreen ? 14.0 : (isSmallScreen ? 18.0 : 24.0);
    final cardHeight = isVerySmallScreen ? 60.0 : (isSmallScreen ? 70.0 : 80.0);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
        // Add haptic feedback for better interaction
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: cardHeight,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding, 
          horizontal: screenWidth * 0.05,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 16 : 20),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: AppColors.textPrimary.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primary : AppColors.textSecondary)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _genderIcons[gender],
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: iconSize,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Text(
                gender,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 5 : 6)),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
