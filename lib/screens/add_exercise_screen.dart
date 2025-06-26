import 'package:flutter/material.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final bool _isLoading = false;
  String _selectedCategory = 'Cardio';
  final List<String> _categories = [
    'Cardio',
    'Strength',
    'Flexibility',
    'Sports'
  ];

  // Design constants
  final Color _primaryColor = const Color(0xFF6C63FF);
  final Color _accentColor = const Color(0xFFFFA48E);
  final Color _backgroundColor = const Color(0xFFF8F9FD);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3142);
  final Color _lightTextColor = const Color(0xFF9E9EAB);

  final List<Map<String, dynamic>> _popularExercises = [
    {
      'name': 'Running',
      'category': 'Cardio',
      'calories': 500,
      'duration': '30 min',
      'icon': Icons.directions_run,
      'color': Colors.green.shade400,
    },
    {
      'name': 'Swimming',
      'category': 'Cardio',
      'calories': 450,
      'duration': '30 min',
      'icon': Icons.pool,
      'color': Colors.blue.shade400,
    },
    {
      'name': 'Cycling',
      'category': 'Cardio',
      'calories': 400,
      'duration': '30 min',
      'icon': Icons.directions_bike,
      'color': Colors.orange.shade400,
    },
    {
      'name': 'Push-ups',
      'category': 'Strength',
      'calories': 150,
      'duration': '10 min',
      'icon': Icons.fitness_center,
      'color': Colors.red.shade400,
    },
    {
      'name': 'Yoga',
      'category': 'Flexibility',
      'calories': 200,
      'duration': '30 min',
      'icon': Icons.self_improvement,
      'color': Colors.purple.shade400,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _popularExercises
        .where((e) => e['category'] == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Add Exercise',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ],
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategorySelector(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredExercises.length,
              itemBuilder: (context, index) {
                return _buildExerciseItem(filteredExercises[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show custom exercise dialog
          _showCustomExerciseDialog();
        },
        backgroundColor: _primaryColor,
        heroTag: 'addExerciseScreenFAB',
        icon: const Icon(Icons.add),
        label: const Text(
          'Custom Exercise',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          hintStyle: TextStyle(color: _lightTextColor),
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          suffixIcon: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryColor,
                  ),
                )
              : (_searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: _lightTextColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null),
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _lightTextColor.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _primaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          isDense: true,
        ),
        onChanged: (value) {
          // Implement search functionality
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: _textColor.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _lightTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final Color iconColor = exercise['color'] ?? _primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              exercise['icon'],
              color: iconColor,
              size: 24,
            ),
          ),
        ),
        title: Text(
          exercise['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: _accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${exercise['calories']} calories',
                  style: TextStyle(color: _lightTextColor, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  exercise['duration'],
                  style: TextStyle(color: _lightTextColor, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.add,
              color: _primaryColor,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              // Log the exercise
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${exercise['name']} to your log'),
                  backgroundColor: _primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _showCustomExerciseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add Custom Exercise',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Exercise Name',
                  labelStyle: TextStyle(color: _lightTextColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _lightTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  labelStyle: TextStyle(color: _lightTextColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _lightTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Calories Burned',
                  labelStyle: TextStyle(color: _lightTextColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _lightTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _lightTextColor,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Save custom exercise logic
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Custom exercise added!'),
                    backgroundColor: _primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
