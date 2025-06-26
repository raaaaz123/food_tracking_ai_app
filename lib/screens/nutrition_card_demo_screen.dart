import 'package:flutter/material.dart';
import '../widgets/nutrition_card.dart';

class NutritionCardDemoScreen extends StatefulWidget {
  const NutritionCardDemoScreen({Key? key}) : super(key: key);

  @override
  State<NutritionCardDemoScreen> createState() => _NutritionCardDemoScreenState();
}

class _NutritionCardDemoScreenState extends State<NutritionCardDemoScreen> {
  // Sample nutrition data
  final double _calories = 0;
  final double _caloriesGoal = 1414;
  final double _carbs = 0;
  final double _carbsGoal = 177;
  final double _protein = 0;
  final double _proteinGoal = 71;
  final double _fat = 0;
  final double _fatGoal = 47;
  
  // Date navigation
  late DateTime _selectedDate;
  
  // Demo streak count
  final int _streak = 5;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }
  
  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }
  
  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(tomorrow)) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      });
    }
  }
  
  void _showStreakDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange),
            SizedBox(width: 8),
            Text('Current Streak'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_streak',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            Text(
              'days in a row!',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Keep using the app daily to maintain your streak.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Remove app bar to allow card to fit into the status bar area
      body: Column(
        children: [
          // Nutrition card fits into status bar area
          NutritionCard(
            calories: _calories,
            caloriesGoal: _caloriesGoal,
            carbs: _carbs,
            carbsGoal: _carbsGoal,
            protein: _protein,
            proteinGoal: _proteinGoal,
            fat: _fat,
            fatGoal: _fatGoal,
            streak: _streak,
            selectedDate: _selectedDate,
            onPreviousDate: _goToPreviousDay,
            onNextDate: _goToNextDay,
            onStreakTap: _showStreakDialog,
            onTap: () {
              // Example of what could happen on tap
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card tapped!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          
          // Rest of the screen
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About This Demo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This screen demonstrates the updated nutrition card with:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildBulletPoint('More compact macro items with proper spacing'),
                          _buildBulletPoint('Pie chart indicating consumed calories'),
                          _buildBulletPoint('Card fits into the status bar area'),
                          _buildBulletPoint('Streak indicator replaces account/notification icons'),
                          _buildBulletPoint('Dynamic date navigation'),
                          const SizedBox(height: 12),
                          const Text(
                            'Current date: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Try it out:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildBulletPoint('Tap the streak indicator (${_streak}) to see the streak dialog'),
                          _buildBulletPoint('Use the arrow buttons to navigate between dates'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}