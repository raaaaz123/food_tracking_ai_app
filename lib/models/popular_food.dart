import 'package:flutter/material.dart';

class PopularFood {
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final List<String> commonIngredients;
  final String servingSize;
  final Map<String, dynamic> nutritionPreview;
  final IconData icon;

  PopularFood({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.commonIngredients,
    required this.servingSize,
    required this.nutritionPreview,
    required this.icon,
  });

  static List<PopularFood> getPopularFoods() {
    return [
      PopularFood(
        name: 'Hamburger',
        description:
            'Classic American burger with beef patty, lettuce, tomato, and condiments',
        imageUrl: 'assets/images/foods/hamburger.jpg',
        category: 'Fast Food',
        commonIngredients: [
          'Beef patty',
          'Burger bun',
          'Lettuce',
          'Tomato',
          'Onion',
          'Pickle',
          'Ketchup',
          'Mustard'
        ],
        servingSize: '1 burger (250g)',
        nutritionPreview: {
          'calories': 540,
          'protein': 25,
          'carbs': 45,
          'fat': 29,
        },
        icon: Icons.lunch_dining,
      ),
      PopularFood(
        name: 'Pizza',
        description:
            'Traditional pizza with cheese, tomato sauce, and various toppings',
        imageUrl: 'assets/images/foods/pizza.jpg',
        category: 'Italian',
        commonIngredients: [
          'Pizza dough',
          'Tomato sauce',
          'Mozzarella cheese',
          'Olive oil',
          'Basil'
        ],
        servingSize: '2 slices (about 180g)',
        nutritionPreview: {
          'calories': 570,
          'protein': 22,
          'carbs': 65,
          'fat': 22,
        },
        icon: Icons.local_pizza,
      ),
      PopularFood(
        name: 'Fried Chicken',
        description: 'Crispy fried chicken pieces, seasoned and breaded',
        imageUrl: 'assets/images/foods/fried_chicken.jpg',
        category: 'Fast Food',
        commonIngredients: [
          'Chicken pieces',
          'Flour',
          'Eggs',
          'Breadcrumbs',
          'Salt',
          'Pepper',
          'Vegetable oil'
        ],
        servingSize: '2 pieces (210g)',
        nutritionPreview: {
          'calories': 485,
          'protein': 30,
          'carbs': 18,
          'fat': 32,
        },
        icon: Icons.fastfood,
      ),
      PopularFood(
        name: 'Mac and Cheese',
        description: 'Creamy macaroni pasta with cheese sauce',
        imageUrl: 'assets/images/foods/mac_cheese.jpg',
        category: 'Comfort Food',
        commonIngredients: [
          'Macaroni pasta',
          'Cheddar cheese',
          'Milk',
          'Butter',
          'Flour',
          'Breadcrumbs'
        ],
        servingSize: '1 cup (220g)',
        nutritionPreview: {
          'calories': 380,
          'protein': 15,
          'carbs': 44,
          'fat': 17,
        },
        icon: Icons.restaurant,
      ),
      PopularFood(
        name: 'Tacos',
        description:
            'Mexican tacos with meat, vegetables, and toppings in a tortilla shell',
        imageUrl: 'assets/images/foods/tacos.jpg',
        category: 'Mexican',
        commonIngredients: [
          'Tortillas',
          'Ground beef',
          'Lettuce',
          'Tomato',
          'Cheese',
          'Sour cream',
          'Salsa'
        ],
        servingSize: '2 tacos (240g)',
        nutritionPreview: {
          'calories': 370,
          'protein': 21,
          'carbs': 28,
          'fat': 20,
        },
        icon: Icons.food_bank,
      ),
      PopularFood(
        name: 'Spaghetti and Meatballs',
        description: 'Italian pasta dish with meatballs in tomato sauce',
        imageUrl: 'assets/images/foods/spaghetti.jpg',
        category: 'Italian',
        commonIngredients: [
          'Spaghetti pasta',
          'Ground beef',
          'Breadcrumbs',
          'Eggs',
          'Tomato sauce',
          'Garlic',
          'Onions',
          'Parmesan cheese'
        ],
        servingSize: '1 serving (350g)',
        nutritionPreview: {
          'calories': 520,
          'protein': 24,
          'carbs': 60,
          'fat': 19,
        },
        icon: Icons.dinner_dining,
      ),
      PopularFood(
        name: 'Pancakes',
        description: 'Fluffy breakfast pancakes with syrup and butter',
        imageUrl: 'assets/images/foods/pancakes.jpg',
        category: 'Breakfast',
        commonIngredients: [
          'Flour',
          'Eggs',
          'Milk',
          'Baking powder',
          'Sugar',
          'Butter',
          'Maple syrup'
        ],
        servingSize: '3 pancakes (210g)',
        nutritionPreview: {
          'calories': 430,
          'protein': 8,
          'carbs': 77,
          'fat': 11,
        },
        icon: Icons.breakfast_dining,
      ),
      PopularFood(
        name: 'Caesar Salad',
        description:
            'Classic salad with romaine lettuce, croutons, and Caesar dressing',
        imageUrl: 'assets/images/foods/caesar_salad.jpg',
        category: 'Salad',
        commonIngredients: [
          'Romaine lettuce',
          'Croutons',
          'Parmesan cheese',
          'Caesar dressing',
          'Chicken breast',
          'Bacon bits'
        ],
        servingSize: '1 bowl (230g)',
        nutritionPreview: {
          'calories': 320,
          'protein': 18,
          'carbs': 15,
          'fat': 22,
        },
        icon: Icons.restaurant_menu,
      ),
      PopularFood(
        name: 'Ice Cream',
        description: 'Frozen dessert in various flavors',
        imageUrl: 'assets/images/foods/ice_cream.jpg',
        category: 'Dessert',
        commonIngredients: [
          'Milk',
          'Cream',
          'Sugar',
          'Eggs',
          'Vanilla extract',
          'Various flavorings'
        ],
        servingSize: '1 cup (130g)',
        nutritionPreview: {
          'calories': 270,
          'protein': 5,
          'carbs': 32,
          'fat': 14,
        },
        icon: Icons.icecream,
      ),
      PopularFood(
        name: 'Chicken Wings',
        description: 'Fried or baked chicken wings with various sauces',
        imageUrl: 'assets/images/foods/chicken_wings.jpg',
        category: 'Appetizer',
        commonIngredients: [
          'Chicken wings',
          'Hot sauce',
          'Butter',
          'Garlic powder',
          'Salt',
          'Pepper'
        ],
        servingSize: '6 wings (240g)',
        nutritionPreview: {
          'calories': 480,
          'protein': 42,
          'carbs': 2,
          'fat': 34,
        },
        icon: Icons.takeout_dining,
      ),
    ];
  }
}
