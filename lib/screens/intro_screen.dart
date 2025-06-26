import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../components/dot_indicator.dart';
import '../constants/intro_content.dart';
import '../constants/app_colors.dart';
import '../services/preferences_service.dart';
import 'reviews_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
    
    Posthog().screen(
      screenName: 'Intro Screen',
    );
    
    // Hide status bar for more immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    // Restore system UI when leaving the screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }

  void _skipToReviews() async {
    // Add light haptic feedback
    HapticFeedback.mediumImpact();
    
    // Mark first time as false and navigate to review screen
    await PreferencesService.setFirstTime(false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ReviewsScreen()),
    );
  }

  void _onNextPage() async {
    // Add light haptic feedback
    HapticFeedback.mediumImpact();
    
    if (_currentPage == introContents.length - 1) {
      // Mark first time as false and navigate to review screen
      await PreferencesService.setFirstTime(false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ReviewsScreen()),
      );
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          TextButton(
            onPressed: _skipToReviews,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (value) {
            setState(() {
              _currentPage = value;
              _animationController.reset();
              _animationController.forward();
            });
          },
          itemCount: introContents.length,
          itemBuilder: (context, index) => IntroContentWidget(
            content: introContents[index],
            currentPage: _currentPage,
            totalPages: introContents.length,
            onNextPressed: _onNextPage,
            animation: _fadeAnimation,
          ),
        ),
      ),
    );
  }
}

class IntroContentWidget extends StatelessWidget {
  final IntroContent content;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNextPressed;
  final Animation<double> animation;

  const IntroContentWidget({
    super.key,
    required this.content,
    required this.currentPage,
    required this.totalPages,
    required this.onNextPressed,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLastPage = currentPage == totalPages - 1;
    final isSmallScreen = screenSize.height < 700;
    final isVerySmallScreen = screenSize.height < 600;
    final isExtremelySmallScreen = screenSize.height < 500;

    return FadeTransition(
      opacity: animation,
      child: Column(
        children: [
          // Image Area - More flexible sizing
          Expanded(
            flex: isExtremelySmallScreen ? 4 : (isVerySmallScreen ? 5 : (isSmallScreen ? 6 : 7)),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(16, isExtremelySmallScreen ? 1 : (isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 8)), 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    Image.asset(
                      content.image,
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.3),
                          ],
                          stops: const [0.7, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content area - More space for content
          Expanded(
            flex: isExtremelySmallScreen ? 6 : (isVerySmallScreen ? 5 : (isSmallScreen ? 4 : 3)),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(0, isExtremelySmallScreen ? 4 : (isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 18)), 0, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 
                  isExtremelySmallScreen ? 12 : (isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 30)), 
                  24, 
                  isExtremelySmallScreen ? 8 : (isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 24))
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text content - scrollable description
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title with FittedBox to ensure it fits
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              content.title,
                              style: TextStyle(
                                fontSize: isExtremelySmallScreen ? 18 : (isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 32)),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: isExtremelySmallScreen ? 4 : (isVerySmallScreen ? 6 : (isSmallScreen ? 8 : screenSize.height * 0.015))),
                          // Scrollable description text
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                content.description,
                                style: TextStyle(
                                  fontSize: isExtremelySmallScreen ? 12 : (isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16)),
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Minimal gap
                    SizedBox(height: isExtremelySmallScreen ? 1 : (isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 8))),
                    // Button and dots - more compact
                    SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Button first
                          SizedBox(
                            width: double.infinity,
                            height: isExtremelySmallScreen ? 40 : (isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 56)),
                            child: ElevatedButton(
                              onPressed: onNextPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLastPage ? 'Get Started' : 'Continue',
                                    style: TextStyle(
                                      fontSize: isExtremelySmallScreen ? 14 : (isVerySmallScreen ? 15 : (isSmallScreen ? 16 : 18)),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (!isLastPage) ...[
                                    SizedBox(width: isExtremelySmallScreen ? 3 : (isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8))),
                                    Icon(Icons.arrow_forward, size: isExtremelySmallScreen ? 14 : (isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20))),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Page indicators below button - more compact
                          Padding(
                            padding: EdgeInsets.only(top: isExtremelySmallScreen ? 6 : (isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)), bottom: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                totalPages,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 5,
                                    width: index == currentPage ? 18 : 5,
                                    decoration: BoxDecoration(
                                      color: index == currentPage
                                          ? AppColors.primary
                                          : AppColors.primary.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}
