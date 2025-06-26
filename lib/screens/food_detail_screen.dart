import 'package:flutter/material.dart';
import 'dart:io';
import '../models/nutrition_info.dart';
import '../services/food_hive_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class FoodDetailScreen extends StatefulWidget {
  final NutritionInfo food;
  final DateTime selectedDate;

  const FoodDetailScreen({
    Key? key,
    required this.food,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late int _servingCount;

  // Replace local color definitions with AppColors
  Color get _primaryColor => AppColors.primary;
  Color get _accentColor => AppColors.warning;
  Color get _backgroundColor => AppColors.background;
  Color get _cardColor => AppColors.cardBackground;
  Color get _textColor => AppColors.textPrimary;
  Color get _lightTextColor => AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    // Set status bar text color to dark
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    
    _nameController = TextEditingController(text: widget.food.foodName);
    _caloriesController = TextEditingController(text: widget.food.calories.toString());
    _proteinController = TextEditingController(text: widget.food.protein.toString());
    _carbsController = TextEditingController(text: widget.food.carbs.toString());
    _fatController = TextEditingController(text: widget.food.fat.toString());
    _servingCount = widget.food.additionalInfo['servingCount'] as int? ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    try {
      final updatedFood = NutritionInfo(
        foodName: _nameController.text,
        brandName: widget.food.brandName ?? '',
        calories: double.parse(_caloriesController.text),
        protein: double.parse(_proteinController.text),
        carbs: double.parse(_carbsController.text),
        fat: double.parse(_fatController.text),
        servingSize: widget.food.servingSize ?? '1 serving',
        ingredients: widget.food.ingredients,
        additionalInfo: {
          ...widget.food.additionalInfo,
          'servingCount': _servingCount,
          'timestamp': widget.food.additionalInfo['timestamp'],
        },
      );

      await FoodHiveService.updateFood(widget.selectedDate, widget.food, updatedFood);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeString = widget.food.additionalInfo.containsKey('timestamp')
        ? DateFormat('h:mm a').format(DateTime.parse(widget.food.additionalInfo['timestamp']))
        : '';
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            CustomScrollView(
              slivers: [
                // App Bar with Hero Image
                SliverAppBar(
                  expandedHeight: widget.food.additionalInfo.containsKey('imagePath') ? 220 : 120,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: _backgroundColor,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Food Details',
                      style: TextStyle(
                        color: widget.food.additionalInfo.containsKey('imagePath') 
                            ? Colors.white
                            : _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: widget.food.additionalInfo.containsKey('imagePath')
                            ? [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                    background: widget.food.additionalInfo.containsKey('imagePath')
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // Food Image
                              Image.file(
                                File(widget.food.additionalInfo['imagePath']),
                                fit: BoxFit.cover,
                              ),
                              // Gradient overlay for better text visibility
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                              // Time badge on the image
                              if (timeString.isNotEmpty)
                                Positioned(
                                  right: 16,
                                  top: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time, color: _primaryColor, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeString,
                                          style: TextStyle(
                                            color: _textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Container(
                            color: _primaryColor.withOpacity(0.1),
                            child: Center(
                              child: Icon(
                                Icons.restaurant,
                                size: 50,
                                color: _primaryColor.withOpacity(0.5),
                              ),
                            ),
                          ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food Name with Card-like design
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _nameController,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Food Name',
                              labelStyle: TextStyle(
                                color: _lightTextColor,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.restaurant, color: _primaryColor),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: _cardColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),

                        // Nutrition Summary Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _primaryColor.withOpacity(0.8),
                                _primaryColor.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nutrition Summary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildNutritionSummaryItem(
                                    'Calories',
                                    _caloriesController.text,
                                    'kcal',
                                    Icons.local_fire_department,
                                    Colors.orange,
                                  ),
                                  _buildNutritionSummaryItem(
                                    'Protein',
                                    _proteinController.text,
                                    'g',
                                    Icons.fitness_center,
                                    Colors.blue,
                                  ),
                                  _buildNutritionSummaryItem(
                                    'Carbs',
                                    _carbsController.text,
                                    'g',
                                    Icons.grain,
                                    Colors.green,
                                  ),
                                  _buildNutritionSummaryItem(
                                    'Fat',
                                    _fatController.text,
                                    'g',
                                    Icons.water_drop,
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Serving count with improved UI
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.restaurant_menu,
                                      color: _primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Serving Count',
                                    style: TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildServingButton(
                                    Icons.remove,
                                    () {
                                      if (_servingCount > 1) {
                                        setState(() {
                                          _servingCount--;
                                          _updateNutrientValues();
                                        });
                                      }
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        '$_servingCount',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildServingButton(
                                    Icons.add,
                                    () {
                                      setState(() {
                                        _servingCount++;
                                        _updateNutrientValues();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Section title for detailed nutrition
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 8),
                          child: Text(
                            'Nutrition Details',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),

                        // Detailed nutrition fields with improved design
                        _buildNutrientField(
                          'Calories',
                          _caloriesController,
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                        _buildNutrientField(
                          'Protein (g)',
                          _proteinController,
                          Icons.fitness_center,
                          AppColors.info,
                        ),
                        _buildNutrientField(
                          'Carbs (g)',
                          _carbsController,
                          Icons.grain,
                          AppColors.success,
                        ),
                        _buildNutrientField(
                          'Fat (g)',
                          _fatController,
                          Icons.water_drop,
                          AppColors.error,
                        ),
                        
                        // Extra space at the bottom to ensure all content is visible above the save button
                        SizedBox(height: 70 + bottomPadding),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Save button with proper bottom padding
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottomPadding,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18,
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

  // New method to build nutrition summary items
  Widget _buildNutritionSummaryItem(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // New method to build serving adjustment buttons
  Widget _buildServingButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              color: _primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // Updated nutrient field with modern design
  Widget _buildNutrientField(String label, TextEditingController controller, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: _lightTextColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateNutrientValues() {
    final baseCalories = widget.food.calories / (widget.food.additionalInfo['servingCount'] as int? ?? 1);
    final baseProtein = widget.food.protein / (widget.food.additionalInfo['servingCount'] as int? ?? 1);
    final baseCarbs = widget.food.carbs / (widget.food.additionalInfo['servingCount'] as int? ?? 1);
    final baseFat = widget.food.fat / (widget.food.additionalInfo['servingCount'] as int? ?? 1);

    setState(() {
      _caloriesController.text = (baseCalories * _servingCount).toStringAsFixed(1);
      _proteinController.text = (baseProtein * _servingCount).toStringAsFixed(1);
      _carbsController.text = (baseCarbs * _servingCount).toStringAsFixed(1);
      _fatController.text = (baseFat * _servingCount).toStringAsFixed(1);
    });
  }
} 