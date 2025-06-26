import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../constants/app_colors.dart';
import 'user_details_screen.dart';
import 'intro_screen.dart';
import 'reviews_screen.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<ReviewData> _reviews = [
    ReviewData(
      name: "Emily",
      rating: 5,
      headline: "I still eat food I love",
      content:
          "I quickly learned which foods I should eat more and which I should eat less. I also tried new dishes and lost weight without feeling deprived. I still eat food I love. The app I needed for an easier life.",
      image: "assets/images/review.png",
    ),
    ReviewData(
      name: "Michael",
      rating: 5,
      headline: "Changed my relationship with food",
      content:
          "This app helped me understand portions and nutrition in a way I never did before. I've lost 15 pounds in 2 months while eating foods I enjoy. The meal recommendations are fantastic!",
      image: "assets/images/review.png",
    ),
    ReviewData(
      name: "Sarah",
      rating: 5,
      headline: "Finally something that works",
      content:
          "I've tried dozens of diet apps, but this one is different. It's not about restriction - it's about balance. The AI recommendations are spot on and I'm seeing real results while enjoying my meals.",
      image: "assets/images/review.png",
    ),
  ];

  @override
  void initState() {
    super.initState();
    Posthog().screen(screenName: 'Reviews Screen');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToUserDetails() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UserDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Background image with overlay
          Positioned.fill(
            child: Image.asset(
              _reviews[_currentPage].image,
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay for better contrast
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Progress dots
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: List.generate(12, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: index < 1
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Back button and header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const IntroScreen()),
                          );
                        },
                      ),

                      // Header with avatar and text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "What others have to say",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Reviews header
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: isSmallScreen ? 12.0 : 20.0),
                  child: Column(
                    children: [
                      const Text(
                        "Over 10000",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "5 star ratings",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expanded area for reviews
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      return _ReviewCard(review: _reviews[index]);
                    },
                  ),
                ),

                // Next button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      24.0,
                      isSmallScreen ? 12.0 : 20.0,
                      24.0,
                      isSmallScreen ? 20.0 : 32.0),
                  child: Column(
                    children: [
                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _reviews.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentPage
                                  ? AppColors.primary
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Next button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _navigateToUserDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "NEXT",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewData review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24.0, 
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0), 
        24.0, 
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                color:
                    index < review.rating ? Colors.amber : Colors.grey.shade400,
                size: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 24),
              ),
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),

          // Headline
          Text(
            review.headline,
            style: TextStyle(
              fontSize: isVerySmallScreen ? 22 : (isSmallScreen ? 24 : 28),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),

          // Scrollable review content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    "\"${review.content}\"",
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),

                  // Reviewer name
                  Text(
                    review.name,
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 18),
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
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
}

class ReviewData {
  final String name;
  final int rating;
  final String headline;
  final String content;
  final String image;

  ReviewData({
    required this.name,
    required this.rating,
    required this.headline,
    required this.content,
    required this.image,
  });
}
