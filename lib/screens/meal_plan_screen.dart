import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:in_app_review/in_app_review.dart';
import '../constants/app_colors.dart';
import '../services/meal_plan_service.dart';
import '../services/storage_service.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import '../models/meal_suggestion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';
import '../screens/meal_details_screen.dart';

// Import the Feature enum
import '../services/subscription_handler.dart' show Feature;

// Constants for generation limit
const String _freeGenerationCountKey = 'free_meal_generation_count';
const int _maxFreeGenerations = 2;

// Review dialog tracking
const String _lastReviewDialogKey = 'last_review_dialog_time';
const int _reviewDialogCooldownDays = 7; // Show review dialog max once per week

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  bool _isLoading = false;
  String _selectedMealType = 'Breakfast';
  String _selectedContinent = 'European';
  String _selectedRegion = 'Mediterranean';
  String _selectedSubRegion = '';
  List<String> _ingredients = [];
  final TextEditingController _ingredientController = TextEditingController();
  bool _isGenerating = false;
  
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  List<CuisineRegion> _cuisineRegions = [];
  
  List<MealSuggestion> _savedMealSuggestions = [];
  String _searchQuery = '';
  List<MealSuggestion> _filteredSavedMealSuggestions = [];
  String _sortOption = 'Recent';

  String? _filterMealType;
  String? _filterCuisine;
  
  // Add generation count tracking
  int _remainingFreeGenerations = _maxFreeGenerations;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _cuisineRegions = MealPlanService.getCuisinesByRegion();
    _loadSavedMealSuggestions();
    
    // Verify Hive box status
    _verifyHiveBoxStatus();
    
    // Track screen view
    Posthog().capture(
      eventName: 'screen_view',
      properties: {
        'screen': 'Meal Plan Screen',
      },
    );
    
    // Load remaining free generations count and premium status
    _loadGenerationCount();
    _checkPremiumStatus();
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMealSuggestions() async {
    setState(() => _isLoading = true);
    try {
      final suggestions = await MealPlanService.getSavedMealSuggestions();
      setState(() {
        _savedMealSuggestions = suggestions;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  void _applyFiltersAndSort() {
    var filtered = List<MealSuggestion>.from(_savedMealSuggestions);
    
    // Apply meal type filter
    if (_filterMealType != null) {
      filtered = filtered.where((meal) => meal.mealType == _filterMealType).toList();
    }
    
    // Apply cuisine filter
    if (_filterCuisine != null) {
      filtered = filtered.where((meal) => meal.cuisine == _filterCuisine).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((meal) =>
        meal.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        meal.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Apply sorting
    switch (_sortOption) {
      case 'Recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Calories':
        filtered.sort((a, b) => (b.nutritionInfo['calories'] ?? 0)
            .compareTo(a.nutritionInfo['calories'] ?? 0));
        break;
    }
    
    setState(() {
      _filteredSavedMealSuggestions = filtered;
    });
  }

  Future<void> _showAddMealOptionsBottomSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Meal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildOptionTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Scan Ingredients',
                    subtitle: 'Create meal from scanned ingredients',
                    onTap: () {
                      Navigator.pop(context);
                      _showScanOptionsDialog();
                    },
                  ),
                  SizedBox(height: 16),
                  _buildOptionTile(
                    icon: Icons.add_circle_outline,
                    title: 'Create Custom Meal',
                    subtitle: 'Create meal from scratch',
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateCustomMealBottomSheet();
                    },
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateCustomMealBottomSheet() async {
    // Reset ingredients list when opening the sheet
    _ingredients.clear();
    _ingredientController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create Custom Meal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20),
                  // Meal type selection
                  Text(
                    'Meal Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mealTypes.length,
                      itemBuilder: (context, index) {
                        final mealType = _mealTypes[index];
                        final isSelected = mealType == _selectedMealType;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => _selectedMealType = mealType);
                            setState(() => _selectedMealType = mealType);
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                mealType,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  // Cuisine selection
                  Text(
                    'Cuisine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cuisineRegions.length,
                      itemBuilder: (context, index) {
                        final cuisine = _cuisineRegions[index];
                        final isSelected = cuisine.continent == _selectedContinent;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _selectedContinent = cuisine.continent;
                              _selectedRegion = cuisine.regions.isNotEmpty ? cuisine.regions[0] : '';
                              _selectedSubRegion = '';
                            });
                            setState(() {
                              _selectedContinent = cuisine.continent;
                              _selectedRegion = cuisine.regions.isNotEmpty ? cuisine.regions[0] : '';
                              _selectedSubRegion = '';
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cuisine.continent,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  // Region selection
                  Text(
                    'Region',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cuisineRegions
                          .firstWhere((c) => c.continent == _selectedContinent,
                              orElse: () => CuisineRegion(
                                  continent: '', regions: [], subRegions: {}))
                          .regions
                          .length,
                      itemBuilder: (context, index) {
                        final regions = _cuisineRegions
                            .firstWhere((c) => c.continent == _selectedContinent,
                                orElse: () => CuisineRegion(
                                    continent: '', regions: [], subRegions: {}))
                            .regions;
                        
                        if (regions.isEmpty) return Container();
                        
                        final region = regions[index];
                        final isSelected = region == _selectedRegion;
                        
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _selectedRegion = region;
                              _selectedSubRegion = '';
                            });
                            setState(() {
                              _selectedRegion = region;
                              _selectedSubRegion = '';
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                region,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  // Sub-region selection
                  if (_selectedRegion.isNotEmpty &&
                      _cuisineRegions
                          .firstWhere((c) => c.continent == _selectedContinent,
                              orElse: () => CuisineRegion(
                                  continent: '', regions: [], subRegions: {}))
                          .subRegions
                          .containsKey(_selectedRegion) &&
                      _cuisineRegions
                          .firstWhere((c) => c.continent == _selectedContinent)
                          .subRegions[_selectedRegion]!
                          .isNotEmpty) ...[
                    Text(
                      'Sub-Region',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cuisineRegions
                            .firstWhere((c) => c.continent == _selectedContinent)
                            .subRegions[_selectedRegion]!
                            .length,
                        itemBuilder: (context, index) {
                          final subRegions = _cuisineRegions
                              .firstWhere((c) => c.continent == _selectedContinent)
                              .subRegions[_selectedRegion]!;
                          
                          final subRegion = subRegions[index];
                          final isSelected = subRegion == _selectedSubRegion;
                          
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => _selectedSubRegion = subRegion);
                              setState(() => _selectedSubRegion = subRegion);
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: 12),
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  subRegion,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  // Add optional ingredients section
                  Text(
                    'Ingredients (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add ingredients you want to include in your meal',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ingredientController,
                          decoration: InputDecoration(
                            hintText: 'Enter ingredient',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              setModalState(() {
                                _ingredients.add(value.trim());
                                _ingredientController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: AppColors.primary),
                        onPressed: () {
                          if (_ingredientController.text.trim().isNotEmpty) {
                            setModalState(() {
                              _ingredients.add(_ingredientController.text.trim());
                              _ingredientController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Display added ingredients
                  if (_ingredients.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _ingredients.map((ingredient) {
                          return Chip(
                            label: Text(ingredient),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIconColor: AppColors.primary,
                            onDeleted: () {
                              setModalState(() {
                                _ingredients.remove(ingredient);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateMealSuggestions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Create Meal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate used generations
    int usedGenerations = _maxFreeGenerations - _remainingFreeGenerations;
    
    // Set status bar icons to white for better contrast with primary color background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        title: GestureDetector(
          onLongPress: () async {
            // Show options for testing
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Testing Options'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Reset Generation Count'),
                      onTap: () {
                        Navigator.pop(context);
                        _resetGenerationCount();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.star),
                      title: Text('Reset Review Dialog Cooldown'),
                      onTap: () {
                        Navigator.pop(context);
                        _resetReviewDialogCooldown();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.rate_review),
                      title: Text('Test Review Dialog'),
                      onTap: () {
                        Navigator.pop(context);
                        _showReviewDialog();
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            );
          },
          child: const Text(
            'My Meals',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isPremium)
            GestureDetector(
              onLongPress: () async {
                // Show options for testing
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Testing Options'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Reset Generation Count'),
                          onTap: () {
                            Navigator.pop(context);
                            _resetGenerationCount();
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.star),
                          title: Text('Reset Review Dialog Cooldown'),
                          onTap: () {
                            Navigator.pop(context);
                            _resetReviewDialogCooldown();
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.rate_review),
                          title: Text('Test Review Dialog'),
                          onTap: () {
                            Navigator.pop(context);
                            _showReviewDialog();
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Used: $usedGenerations/${_maxFreeGenerations}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterOptionsDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _filteredSavedMealSuggestions.isEmpty
              ? _buildEmptyState()
              : _buildMealsList(),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(right: 8, bottom: 8),
        child: FloatingActionButton(
          onPressed: _showAddMealOptionsBottomSheet,
          backgroundColor: Colors.transparent,
          elevation: 6,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB8E0C0), Color(0xFF7BC27D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF7BC27D).withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: AppColors.primary.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No meals yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first meal to get started',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMealOptionsBottomSheet,
            icon: Icon(Icons.add),
            label: Text('Create Your First Meal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredSavedMealSuggestions.length,
      itemBuilder: (context, index) {
        final meal = _filteredSavedMealSuggestions[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MealDetailsScreen(meal: meal),
              ),
            );
          },
          child: Card(
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${meal.mealType} • ${meal.cuisine}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${meal.nutritionInfo['calories'] ?? 0} kcal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNutritionInfo(
                        'Protein',
                        '${meal.nutritionInfo['protein'] ?? 0}',
                        'g',
                      ),
                      _buildNutritionInfo(
                        'Carbs',
                        '${meal.nutritionInfo['carbs'] ?? 0}',
                        'g',
                      ),
                      _buildNutritionInfo(
                        'Fat',
                        '${meal.nutritionInfo['fat'] ?? 0}',
                        'g',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionInfo(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 2),
        Text(
          '$value$unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Meals'),
        content: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _applyFiltersAndSort();
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter meal name or description',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _filterMealType,
              decoration: InputDecoration(
                labelText: 'Meal Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('All'),
                ),
                ..._mealTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterMealType = value;
                  _applyFiltersAndSort();
                });
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _filterCuisine,
              decoration: InputDecoration(
                labelText: 'Cuisine',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('All'),
                ),
                ..._cuisineRegions.map((cuisine) => DropdownMenuItem(
                  value: cuisine.continent,
                  child: Text(cuisine.continent),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterCuisine = value;
                  _applyFiltersAndSort();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterMealType = null;
                _filterCuisine = null;
                _applyFiltersAndSort();
              });
              Navigator.pop(context);
            },
            child: Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyHiveBoxStatus() async {
    try {
      // Use the MealPlanService's verification method
      await MealPlanService.verifyAndRepairBox();
      
      // After verification, load the saved meal suggestions again
      await _loadSavedMealSuggestions();
    } catch (e) {
      print('❌ Error verifying Hive box status: $e');
    }
  }

  Future<void> _generateMealSuggestions() async {
    // Check if user has reached free generation limit
    if (!_isPremium && _remainingFreeGenerations <= 0) {
      _showUpgradeDialog();
      return;
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Creating your meal...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      setState(() => _isGenerating = true);
      
      // Track meal generation
      Posthog().capture(
        eventName: 'generate_meal',
        properties: {
          'meal_type': _selectedMealType,
          'cuisine': _selectedContinent,
          'region': _selectedRegion,
          'sub_region': _selectedSubRegion,
          'has_ingredients': _ingredients.isNotEmpty,
          'ingredient_count': _ingredients.length,
        },
      );
      
      // Generate meal suggestions
      final List<MealSuggestion> suggestions;
      
      // Use different generation method based on whether ingredients were provided
      if (_ingredients.isNotEmpty) {
        suggestions = await MealPlanService.generateMealsFromIngredients(
          ingredients: _ingredients,
          mealType: _selectedMealType,
          cuisine: _selectedContinent,
          region: _selectedRegion,
          subRegion: _selectedSubRegion,
          count: 1,
        );
      } else {
        suggestions = await MealPlanService.generateMealSuggestions(
          mealType: _selectedMealType,
          cuisine: _selectedContinent,
          region: _selectedRegion,
          subRegion: _selectedSubRegion,
          count: 1,
        );
      }
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Update free generation count if not premium
      if (!_isPremium) {
        final prefs = await SharedPreferences.getInstance();
        final remainingGenerations = _remainingFreeGenerations - 1;
        await prefs.setInt(_freeGenerationCountKey, remainingGenerations);
        setState(() => _remainingFreeGenerations = remainingGenerations);
      }
      
      // Reload meal suggestions instead of navigating to details screen
      if (suggestions.isNotEmpty) {
        _loadSavedMealSuggestions();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ingredients.isNotEmpty 
              ? 'Meal created successfully with your ingredients!' 
              : 'Meal created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Clear ingredients list
        setState(() {
          _ingredients.clear();
        });

        // Show review dialog after meal creation
        _showReviewDialog();
      } else {
        // Show error if no meals were generated
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate meal. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }
  
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generation Limit Reached'),
        content: Text('You have used all your free meal generations. Upgrade to premium for unlimited meal generations!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to subscription screen
              SubscriptionHandler.showSubscriptionScreen(
                context,
                feature: Feature.advancedMealPlanning,
                title: "Unlimited Meal Generations",
                subtitle: "Upgrade to premium for unlimited AI-powered meal generations and recipe creation.",
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  // Load remaining free generation count from shared preferences
  Future<void> _loadGenerationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Reset the count if this is the first time or if maxFreeGenerations has changed
      int storedMaxGenerations = prefs.getInt('max_free_generations') ?? 0;
      if (storedMaxGenerations != _maxFreeGenerations) {
        // Update the stored max value
        await prefs.setInt('max_free_generations', _maxFreeGenerations);
        
        // Reset the counter to the new max if the max has increased
        if (storedMaxGenerations < _maxFreeGenerations) {
          int usedGenerations = storedMaxGenerations - (prefs.getInt(_freeGenerationCountKey) ?? storedMaxGenerations);
          int newRemaining = _maxFreeGenerations - usedGenerations;
          await prefs.setInt(_freeGenerationCountKey, newRemaining);
        }
      }
      
      setState(() {
        _remainingFreeGenerations = prefs.getInt(_freeGenerationCountKey) ?? _maxFreeGenerations;
        // Ensure we don't have negative or more than max remaining generations
        if (_remainingFreeGenerations < 0) {
          _remainingFreeGenerations = 0;
        } else if (_remainingFreeGenerations > _maxFreeGenerations) {
          _remainingFreeGenerations = _maxFreeGenerations;
        }
      });
      
      // Log for debugging
      print('📊 Max free generations: $_maxFreeGenerations');
      print('📊 Remaining free generations: $_remainingFreeGenerations');
      
    } catch (e) {
      // If there's an error, default to max free generations
      setState(() {
        _remainingFreeGenerations = _maxFreeGenerations;
      });
      print('❌ Error loading generation count: $e');
    }
  }

  // Check if user has premium subscription
  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await SubscriptionHandler.isPremium();
      setState(() {
        _isPremium = isPremium;
      });
    } catch (e) {
      // If there's an error, assume user is not premium
      setState(() {
        _isPremium = false;
      });
    }
  }

  Future<void> _showScanOptionsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scan Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _scanIngredientsFromCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _scanIngredientsFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanIngredientsFromCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        // Process the image
        _processScannedImage(image);
      }
    } catch (e) {
      // Handle error
      print('Error taking photo: $e');
    }
  }

  Future<void> _scanIngredientsFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Process the image
        _processScannedImage(image);
      }
    } catch (e) {
      // Handle error
      print('Error picking image from gallery: $e');
    }
  }

  Future<void> _processScannedImage(XFile image) async {
    // Check if user has reached free generation limit
    if (!_isPremium && _remainingFreeGenerations <= 0) {
      _showUpgradeDialog();
      return;
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Analyzing ingredients and creating meal...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      setState(() => _isGenerating = true);
      
      // Track image analysis
      Posthog().capture(
        eventName: 'analyze_food_image',
        properties: {
          'image_source': image.path.contains('camera') ? 'camera' : 'gallery',
        },
      );
      
      // Ask user for meal type and cuisine preferences
      String selectedMealType = 'Any';
      String selectedCuisine = 'Any';
      String selectedRegion = '';
      String selectedSubRegion = '';
      
      // Close the loading dialog
      Navigator.pop(context);
      
      bool selectionConfirmed = false;
      
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Customize Your Meal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meal Type'),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedMealType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'Any', child: Text('Any')),
                      ..._mealTypes.map((type) => 
                          DropdownMenuItem(value: type, child: Text(type))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedMealType = value);
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  Text('Cuisine'),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCuisine,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'Any', child: Text('Any')),
                      ..._cuisineRegions.map((cuisine) => 
                          DropdownMenuItem(value: cuisine.continent, child: Text(cuisine.continent))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCuisine = value;
                          selectedRegion = '';
                          selectedSubRegion = '';
                        });
                      }
                    },
                  ),
                  
                  // Only show region dropdown if a cuisine is selected
                  if (selectedCuisine != 'Any') ...[
                    SizedBox(height: 16),
                    Text('Region'),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRegion,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select Region',
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text('Any Region')),
                        ..._cuisineRegions
                            .firstWhere((c) => c.continent == selectedCuisine,
                                orElse: () => CuisineRegion(
                                    continent: '', regions: [], subRegions: {}))
                            .regions
                            .map((region) => DropdownMenuItem(
                                  value: region,
                                  child: Text(region),
                                )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedRegion = value ?? '';
                          selectedSubRegion = '';
                        });
                      },
                    ),
                  ],
                  
                  // Only show sub-region dropdown if a region is selected and has sub-regions
                  if (selectedCuisine != 'Any' && 
                      selectedRegion.isNotEmpty &&
                      _cuisineRegions
                          .firstWhere((c) => c.continent == selectedCuisine,
                              orElse: () => CuisineRegion(
                                  continent: '', regions: [], subRegions: {}))
                          .subRegions
                          .containsKey(selectedRegion) &&
                      _cuisineRegions
                          .firstWhere((c) => c.continent == selectedCuisine)
                          .subRegions[selectedRegion]!
                          .isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text('Sub-Region'),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSubRegion,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select Sub-Region',
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text('Any Sub-Region')),
                        ..._cuisineRegions
                            .firstWhere((c) => c.continent == selectedCuisine)
                            .subRegions[selectedRegion]!
                            .map((subRegion) => DropdownMenuItem(
                                  value: subRegion,
                                  child: Text(subRegion),
                                )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSubRegion = value ?? '';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  selectionConfirmed = false;
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  selectionConfirmed = true;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Generate'),
              ),
            ],
          ),
        ),
      );
      
      if (selectionConfirmed) {
        // Show loading dialog again
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Creating your meal...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take up to 30 seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
    
        try {
          // Convert XFile to File
          final File imageFile = File(image.path);
          
          // Generate meal from image
          final suggestions = await MealPlanService.generateMealsFromImage(
            imageFile: imageFile,
            mealType: selectedMealType,
            cuisine: selectedCuisine,
            region: selectedRegion,
            subRegion: selectedSubRegion,
          );
          
          // Close loading dialog
          Navigator.pop(context);
          
          // Update free generation count if not premium
          if (!_isPremium) {
            final prefs = await SharedPreferences.getInstance();
            final remainingGenerations = _remainingFreeGenerations - 1;
            await prefs.setInt(_freeGenerationCountKey, remainingGenerations);
            setState(() => _remainingFreeGenerations = remainingGenerations);
          }
          
          // Reload meal suggestions instead of navigating to details screen
          if (suggestions.isNotEmpty) {
            _loadSavedMealSuggestions();
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meal created successfully from your image!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Show review dialog after meal creation
            _showReviewDialog();
          } else {
            // Show error if no meals were generated
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate meal. Please try again with a clearer image.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (innerError) {
          // Close loading dialog if still showing
          Navigator.of(context, rootNavigator: true).pop();
          
          print('Error processing image: $innerError');
          
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: Please try again with a clearer image'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      Navigator.of(context, rootNavigator: true).pop();
      
      print('Error in scan process: $e');
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // Reset generation count for testing
  Future<void> _resetGenerationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_freeGenerationCountKey, _maxFreeGenerations);
      await prefs.setInt('max_free_generations', _maxFreeGenerations);
      
      setState(() {
        _remainingFreeGenerations = _maxFreeGenerations;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generation count reset to $_maxFreeGenerations'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      print('🔄 Generation count reset to $_maxFreeGenerations');
    } catch (e) {
      print('❌ Error resetting generation count: $e');
    }
  }

  // Reset review dialog cooldown for testing
  Future<void> _resetReviewDialogCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastReviewDialogKey);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review dialog cooldown reset'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      print('🔄 Review dialog cooldown reset');
    } catch (e) {
      print('❌ Error resetting review dialog cooldown: $e');
    }
  }

  // Show review dialog after meal creation
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
        'source': 'meal_creation',
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
                  'source': 'meal_creation',
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
          'source': 'meal_creation',
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
            'source': 'meal_creation',
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
            'source': 'meal_creation',
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
          'source': 'meal_creation',
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
            'source': 'meal_creation',
            'method': 'fallback_store_listing',
          },
        );
      } catch (fallbackError) {
        print('❌ Error opening store listing: $fallbackError');
        
        // Track the fallback error
        Posthog().capture(
          eventName: 'review_fallback_error',
          properties: {
            'source': 'meal_creation',
            'error': fallbackError.toString(),
          },
        );
      }
    }
  }
} 