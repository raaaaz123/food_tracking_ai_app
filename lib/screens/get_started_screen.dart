import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'intro_screen.dart';
import '../constants/app_colors.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  @override
  void initState() {
    super.initState();
    // Hide status bar for a more immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI when leaving the screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with Overlay
          Image.asset(
            'assets/images/get_started_bg.png',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo
                const Text(
                  'Dietly',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                // Trust Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left laurel icon
                    SvgPicture.asset(
                      'assets/icons/laurel.svg',
                      height: 54,
                      width: 54,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      children: [
                        Text(
                          'Trusted by',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '10k+ users',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Right laurel icon - flipped horizontally
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(3.14159), // PI radians = 180 degrees
                      child: SvgPicture.asset(
                        'assets/icons/laurel.svg',
                        height: 54,
                        width: 54,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Expert Advice Text
                const Text(
                  'Get expert advice',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'on what, when, and how much to eat,\ntailored to suit your individual lifestyle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton(
                    onPressed: () async {
                      // Add haptic feedback
                      HapticFeedback.mediumImpact();
                      await Posthog().capture(
  eventName: 'user_clicked_get_started',
);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IntroScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
             
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Add haptic feedback
                        HapticFeedback.lightImpact();
                        // Handle login
                      },
                      child: const Text(
                        '',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
             
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LaurelIcon extends StatelessWidget {
  final bool isLeft;
  
  const LaurelIcon({super.key, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 40,
      child: CustomPaint(
        painter: LaurelPainter(isLeft: isLeft),
      ),
    );
  }
}

class LaurelPainter extends CustomPainter {
  final bool isLeft;
  
  LaurelPainter({required this.isLeft});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textLight
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final width = size.width;
    final height = size.height;
    
    // Draw laurel stems
    final stemPath = Path();
    if (isLeft) {
      stemPath.moveTo(width * 0.6, height * 0.05);
      stemPath.quadraticBezierTo(width * 0.5, height * 0.5, width * 0.6, height * 0.95);
    } else {
      stemPath.moveTo(width * 0.4, height * 0.05);
      stemPath.quadraticBezierTo(width * 0.5, height * 0.5, width * 0.4, height * 0.95);
    }
    canvas.drawPath(stemPath, paint);
    
    // Draw laurel leaves
    for (int i = 0; i < 7; i++) {
      final startY = height * 0.15 + (i * height * 0.1);
      final controlY = startY + (height * 0.05);
      
      final leafPath = Path();
      if (isLeft) {
        // Left side laurel leaves
        leafPath.moveTo(width * 0.6, startY);
        leafPath.quadraticBezierTo(width * 0.1, controlY, width * 0.55, startY + height * 0.1);
      } else {
        // Right side laurel leaves
        leafPath.moveTo(width * 0.4, startY);
        leafPath.quadraticBezierTo(width * 0.9, controlY, width * 0.45, startY + height * 0.1);
      }
      
      canvas.drawPath(leafPath, paint);
      
      // Add leaf details (vein)
      final detailPath = Path();
      if (isLeft) {
        final midX = width * 0.4;
        final midY = startY + height * 0.05;
        detailPath.moveTo(width * 0.6, startY);
        detailPath.quadraticBezierTo(midX + width * 0.1, midY, width * 0.55, startY + height * 0.1);
      } else {
        final midX = width * 0.6;
        final midY = startY + height * 0.05;
        detailPath.moveTo(width * 0.4, startY);
        detailPath.quadraticBezierTo(midX - width * 0.1, midY, width * 0.45, startY + height * 0.1);
      }
      
      // Draw leaf vein with thinner stroke
      final veinPaint = Paint()
        ..color = AppColors.textLight
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(detailPath, veinPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 