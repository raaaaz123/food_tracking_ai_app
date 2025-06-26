import 'package:flutter/material.dart';
import '../screens/add_exercise_screen.dart';
import '../screens/saved_foods_screen.dart';
import '../screens/famous_foods_screen.dart';
import '../screens/scan_food_screen.dart';
import '../models/nutrition_info.dart';
import '../services/food_hive_service.dart';

class FoodLoggingDialog extends StatefulWidget {
  const FoodLoggingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FoodLoggingDialog(),
    );
  }

  @override
  State<FoodLoggingDialog> createState() => _FoodLoggingDialogState();
}

class _FoodLoggingDialogState extends State<FoodLoggingDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _selectedMeal = 'Breakfast';
  final List<String> _mealOptions = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  List<NutritionInfo> _recentFoods = [];

  @override
  void initState() {
    super.initState();
    _loadRecentFoods();
  }

  Future<void> _loadRecentFoods() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recentFoods = FoodHiveService.getRecentFoods();
      setState(() {
        _recentFoods = recentFoods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading recent foods: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        return Container(
      decoration: BoxDecoration(
            color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  'Add Food',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMealSelector(),
                const SizedBox(height: 16),
                _buildRecentFoods(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Meal',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _mealOptions.map((meal) {
              final isSelected = _selectedMeal == meal;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(meal),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMeal = meal;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFoods() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No recent foods',
                style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
          'Recent Foods',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentFoods.length,
          itemBuilder: (context, index) {
            final food = _recentFoods[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.fastfood),
              ),
              title: Text(food.foodName),
              subtitle: Text(
                '${food.calories?.round() ?? 0} cal · ${food.protein?.round() ?? 0}g protein',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  // Add the food to today's log
                  FoodHiveService.addFood(food);
                  Navigator.pop(context);
                },
              ),
            );
            },
          ),
        ],
    );
  }
}
