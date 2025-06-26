class IntroContent {
  final String title;
  final String description;
  final String image;

  IntroContent({
    required this.title,
    required this.description,
    required this.image,
  });
}

final List<IntroContent> introContents = [
  IntroContent(
    title: 'Calorie tracking\nmade easy',
    description: 'Just snap a quick photo of your meal and we\'ll do the rest. Our AI-powered system will analyze your food and provide accurate nutritional information.',
    image: 'assets/images/lady_scan.png',
  ),
  IntroContent(
    title: 'Transform\nyour body',
    description: 'Today is the best time to start working toward your dream body. Set your goals, track your progress, and achieve the results you want.',
    image: 'assets/images/trans.png',
  ),
  IntroContent(
    title: 'AI-powered\nworkout plans',
    description: 'Our AI will analyze your body and goals to suggest personalized daily workout plans, helping you stay on track effortlessly.',
    image: 'assets/images/4.png',
  ),
];
