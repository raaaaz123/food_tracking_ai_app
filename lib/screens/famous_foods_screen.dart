import 'package:flutter/material.dart';

class FamousFoodsScreen extends StatefulWidget {
  const FamousFoodsScreen({super.key});

  @override
  State<FamousFoodsScreen> createState() => _FamousFoodsScreenState();
}

class _FamousFoodsScreenState extends State<FamousFoodsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final bool _isLoading = false;
  String _selectedCategory = 'Popular';
  final List<String> _categories = [
    'Popular',
    'Fast Food',
    'Healthy',
    'Breakfast',
    'Dinner'
  ];

  // Sample data for famous foods
  final List<Map<String, dynamic>> _famousFoods = [
    {
      'name': 'Big Mac',
      'brand': 'McDonald\'s',
      'calories': 550,
      'protein': 25,
      'carbs': 45,
      'fat': 30,
      'category': 'Fast Food',
      'imageUrl': 'https://example.com/big_mac.jpg',
    },
    {
      'name': 'Chicken Caesar Salad',
      'brand': 'Generic',
      'calories': 350,
      'protein': 30,
      'carbs': 10,
      'fat': 22,
      'category': 'Healthy',
      'imageUrl': 'https://example.com/salad.jpg',
    },
    {
      'name': 'Avocado Toast',
      'brand': 'Generic',
      'calories': 320,
      'protein': 10,
      'carbs': 35,
      'fat': 16,
      'category': 'Breakfast',
      'imageUrl': 'https://example.com/avocado_toast.jpg',
    },
    {
      'name': 'Whopper',
      'brand': 'Burger King',
      'calories': 660,
      'protein': 28,
      'carbs': 49,
      'fat': 40,
      'category': 'Fast Food',
      'imageUrl': 'https://example.com/whopper.jpg',
    },
    {
      'name': 'Grilled Salmon',
      'brand': 'Generic',
      'calories': 367,
      'protein': 40,
      'carbs': 0,
      'fat': 22,
      'category': 'Dinner',
      'imageUrl': 'https://example.com/salmon.jpg',
    },
    {
      'name': 'Egg & Bacon Breakfast Sandwich',
      'brand': 'Starbucks',
      'calories': 480,
      'protein': 21,
      'carbs': 40,
      'fat': 27,
      'category': 'Breakfast',
      'imageUrl': 'https://example.com/breakfast_sandwich.jpg',
    },
    {
      'name': 'Quesadilla',
      'brand': 'Taco Bell',
      'calories': 520,
      'protein': 18,
      'carbs': 41,
      'fat': 33,
      'category': 'Fast Food',
      'imageUrl': 'https://example.com/quesadilla.jpg',
    },
  ];

  List<Map<String, dynamic>> get _filteredFoods {
    final query = _searchController.text.toLowerCase();
    var foods = _selectedCategory == 'Popular'
        ? _famousFoods
        : _famousFoods
            .where((food) => food['category'] == _selectedCategory)
            .toList();

    if (query.isNotEmpty) {
      foods = foods
          .where((food) =>
              food['name'].toLowerCase().contains(query) ||
              food['brand'].toLowerCase().contains(query))
          .toList();
    }

    return foods;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Famous Foods',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategorySelector(),
          Expanded(
            child: _filteredFoods.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFoods.length,
                    itemBuilder: (context, index) {
                      return _buildFoodItem(_filteredFoods[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search famous foods...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (_searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_food,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No foods found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for something else',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.fastfood, color: Colors.black),
        ),
        title: Text(
          food['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${food['brand']}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 2),
            Text(
              '${food['calories']} cal · ${food['protein']}g protein · ${food['carbs']}g carbs · ${food['fat']}g fat',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.black),
          onPressed: () {
            // Log the food
            _showMealSelectionDialog(food);
          },
        ),
      ),
    );
  }

  void _showMealSelectionDialog(Map<String, dynamic> food) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add to which meal?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMealOption('Breakfast', Icons.wb_sunny, food),
              _buildMealOption('Lunch', Icons.lunch_dining, food),
              _buildMealOption('Dinner', Icons.nightlight, food),
              _buildMealOption('Snacks', Icons.cookie, food),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMealOption(
      String mealName, IconData icon, Map<String, dynamic> food) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        // Add food to the selected meal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${food['name']} to $mealName'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to the parent screen
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 16),
            Text(
              mealName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
