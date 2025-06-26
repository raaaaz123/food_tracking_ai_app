import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data'; // Add this import for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
// import 'package:nutrizen_ai/widgets/photo_upload_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import '../models/face_analysis.dart';
import '../services/face_analysis_service.dart';
import '../screens/my_face_workouts_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart'; // Add this import for RenderRepaintBoundary
import 'package:screenshot/screenshot.dart';
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import '../services/storage_service.dart';


// Camera screen widget
class CameraScreen extends StatefulWidget {
  final Function(File) onCapture;
  final Color primaryColor;

  const CameraScreen({
    Key? key,
    required this.onCapture,
    this.primaryColor = AppColors.primary,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
       Posthog().screen(
      screenName: 'Face Workout Screen',
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = _isFrontCamera
        ? cameras
            .firstWhere((cam) => cam.lensDirection == CameraLensDirection.front)
        : cameras
            .firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);

    _controller = CameraController(camera, ResolutionPreset.high);
    await _controller.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  void _toggleCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });
    await _initializeCamera();
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized) return;
 await Posthog().capture(
      eventName: 'face_captured',
    );
    try {
      final XFile image = await _controller.takePicture();
      widget.onCapture(File(image.path));
      Navigator.pop(context);
    } catch (e) {
  
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: widget.primaryColor,
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Reduced camera height (60% of screen height instead of full screen)
    final cameraHeight = screenHeight * 0.6;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Demo images at top area
          Container(
            height: screenHeight * 0.2,
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDemoImage("Front"),
                _buildDemoImage("Side"),
                _buildDemoImage("Face down"),
              ],
            ),
          ),

          // Camera container
          Container(
            height: cameraHeight,
            child: Stack(
              children: [
                // Camera preview with constrained height
                Container(
                  height: cameraHeight,
                  width: double.infinity,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: Container(
                          width: screenWidth,
                          height: screenWidth * _controller.value.aspectRatio,
                          child: CameraPreview(_controller),
                        ),
                      ),
                    ),
                  ),
                ),

                // Camera controls overlay
                SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: AppColors.textLight),
                              onPressed: () => Navigator.pop(context),
                            ),
                            // Title
                            Text(
                              _isFrontCamera ? "Front Camera" : "Back Camera",
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.flip_camera_ios,
                                  color: AppColors.textLight),
                              onPressed: _toggleCamera,
                            ),
                          ],
                        ),
                      ),

                      Spacer(),

                      // Bottom controls
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Capture button
                            GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.textLight,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.textLight,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 0,
                                        ),
                                      ],
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

                // Centered face guide overlay - will have a clear center area
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer overlay with hole
                      Container(
                        width: double.infinity,
                        height: cameraHeight,
                        color: Colors.black.withOpacity(0.3),
                      ),

                      // Transparent hole for face area
                      Container(
                        width: screenWidth * 0.7,
                        height: screenWidth * 0.7,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        // Clip out the center to make it completely transparent
                        child: ClipOval(
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),

                      // Text guide at bottom of face area
                      Positioned(
                        bottom: cameraHeight * 0.25,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Position your face in the circle",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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

          // Instructions at bottom
          Container(
            height: screenHeight * 0.2,
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Capture a clear photo of your face",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Ensure good lighting and position your face within the circle",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoImage(String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.face,
            color: AppColors.textSecondary,
            size: 40,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class FaceWorkoutScreen extends StatefulWidget {
  const FaceWorkoutScreen({Key? key}) : super(key: key);

  @override
  State<FaceWorkoutScreen> createState() => _FaceWorkoutScreenState();
}

class _FaceWorkoutScreenState extends State<FaceWorkoutScreen>
    with SingleTickerProviderStateMixin {
  // Color getters using AppColors
  Color get _primaryColor => AppColors.primary;
  Color get _secondaryColor => AppColors.primaryLight;
  Color get _accentColor => AppColors.error;
  Color get _successColor => AppColors.success;
  Color get _backgroundColor => AppColors.background;
  Color get _cardColor => AppColors.cardBackground;
  Color get _textColor => AppColors.textPrimary;
  Color get _lightTextColor => AppColors.textSecondary;

  // Text sizes - made responsive with SF style
  double _headingSize = 22.0;
  double _subheadingSize = 17.0;
  double _bodySize = 15.0;
  double _smallSize = 13.0;

  final double _borderRadius = 14.0;
  final double _elevation = 2.0;

  // Gradient backgrounds for different states - updated for SF style
  final List<List<Color>> _gradients = [
    [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.info
    ], // Primary gradient
    [
      AppColors.success,
      AppColors.success,
      AppColors.success
    ], // Success gradient
    [
      AppColors.warning,
      AppColors.warning,
      AppColors.accent
    ], // Warning gradient
  ];

  // Animation durations
  final Duration _fastAnimation = Duration(milliseconds: 300);
  final Duration _normalAnimation = Duration(milliseconds: 500);
  final Duration _slowAnimation = Duration(milliseconds: 800);

  // Tab controller
  late TabController _tabController;

  // State variables
  File? _frontImage;
  File? _angleImage;
  File? _sideImage;
  bool _isAnalyzing = false;
  bool _showUploadGuidelines = true;
  bool _isLoadingHistory = false;
  List<FaceAnalysis> _pastAnalyses = [];
  FaceAnalysis? _currentAnalysis;

  // Step-by-step flow
  int _currentImageStep = 0; // 0: front, 1: angle, 2: side
  bool _showStepAnimation = false;
  bool _showResultsAnimation = false;

  // Flow control
  PageController _pageController = PageController();
  int _currentPage = 0; // 0: intro, 1: gender, 2: image upload, 3: results
  String _selectedGender = "male"; // default value

  // Add these variables for share functionality
  bool _hasShownShareDialog = false;
  bool _neverShowShareDialog = false;

  // Add face scan counter
  int _faceScanCount = 0;
  
  // Load face scan counter from storage
  Future<void> _loadFaceScanCounter() async {
    try {
      final counter = await StorageService.getSetting('faceScanCounter', defaultValue: 0);
      setState(() {
        _faceScanCount = counter;
      });
    } catch (e) {

    }
  }
  
  // Increment face scan counter
  Future<void> _incrementFaceScanCounter() async {
    try {
      _faceScanCount++;
      await StorageService.saveSetting('faceScanCounter', _faceScanCount);
    } catch (e) {

    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadPastAnalyses();
    _loadSharePreferences();
    _loadFaceScanCounter(); // Load face scan counter on init

    // Remove MediaQuery call from initState
    // _initResponsiveTextSizes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Move MediaQuery call to didChangeDependencies which is safe
    _updateResponsiveTextSizes();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _currentAnalysis != null) {
      // Show animation when switching to results tab
      setState(() {
        _showResultsAnimation = true;
      });
    }
  }

  // Rename method to avoid confusion
  void _updateResponsiveTextSizes() {
    // Get screen size to calculate responsive text sizes
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;

    // Adjust text sizes based on screen size
    setState(() {
      if (shortestSide < 600) {
        // Phone
        _headingSize = 20.0;
        _subheadingSize = 16.0;
        _bodySize = 14.0;
        _smallSize = 12.0;
      } else if (shortestSide < 900) {
        // Small tablet
        _headingSize = 22.0;
        _subheadingSize = 18.0;
        _bodySize = 16.0;
        _smallSize = 14.0;
      } else {
        // Large tablet or desktop
        _headingSize = 24.0;
        _subheadingSize = 20.0;
        _bodySize = 18.0;
        _smallSize = 16.0;
      }
    });
  }

  Future<void> _loadPastAnalyses() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final analyses = await FaceAnalysisService.getAllAnalyses();
      setState(() {
        _pastAnalyses = analyses;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });
 
    }
  }

  // Load share preferences
  Future<void> _loadSharePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hasShownShareDialog = prefs.getBool('hasShownShareDialog') ?? false;
        _neverShowShareDialog = prefs.getBool('neverShowShareDialog') ?? false;
      });
    } catch (e) {

    }
  }

  // Save share preferences
  Future<void> _saveSharePreferences({bool? hasShown, bool? neverShow}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hasShown != null) {
        await prefs.setBool('hasShownShareDialog', hasShown);
        _hasShownShareDialog = hasShown;
      }
      if (neverShow != null) {
        await prefs.setBool('neverShowShareDialog', neverShow);
        _neverShowShareDialog = neverShow;
      }
    } catch (e) {

    }
  }

  void _showImagePickerDialog(int imageType) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        isScrollControlled: true, // Add this to handle bottom insets properly
        backgroundColor: Colors.transparent, // Make transparent to create custom appearance
        builder: (context) {
          // Get safe area bottom padding to avoid navigation bar overlap
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding), // Add bottom padding to avoid navigation bar
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar for bottom sheet
                Container(
                  width: 40,
                  height: 5,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                
                Text(
                  'Choose an image source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 24),
                
                // Options in a row with enhanced styling
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      source: ImageSource.camera,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5E57E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _buildImageSourceOption(
                      icon: Icons.image,
                      label: 'Gallery',
                      source: ImageSource.gallery,
                      gradient: LinearGradient(
                        colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final pickedFile = await ImagePicker().pickImage(
          source: source,
          imageQuality: 90,
          maxWidth: 800,
        );

        if (pickedFile != null) {
          setState(() {
            switch (imageType) {
              case 0:
                _frontImage = File(pickedFile.path);
                break;
              case 1:
                _angleImage = File(pickedFile.path);
                break;
              case 2:
                _sideImage = File(pickedFile.path);
                break;
            }
            _showStepAnimation = true;
          });
        }
      }
    } catch (e) {
  
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
    required LinearGradient gradient,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(source),
                splashColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Capture and analyze photos
  Future<void> _captureAndAnalyze() async {
    if (_frontImage == null || _angleImage == null || _sideImage == null) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please upload all required photos"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if user already performed 3 scans and is not premium
    if (_faceScanCount >= 3) {
      // Check if user has premium access
      final isPremium = await SubscriptionHandler.isPremium();
      if (!isPremium) {
        // Show subscription screen
        await SubscriptionHandler.showSubscriptionScreen(
          context,
          feature: Feature.faceWorkout,
          title: "Unlock Unlimited Face Scans",
          subtitle: "You've used all 3 free scans. Subscribe to continue using our advanced face analysis and personalized workout recommendations.",
        );
        
        // Check premium status again after subscription screen
        final nowPremium = await SubscriptionHandler.isPremium();
        if (!nowPremium) {
          return;
        }
      }
    } else {
      // Increment counter for free users
      _incrementFaceScanCounter();
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Pass gender parameter to the analysis service
      final analysis = await FaceAnalysisService.analyzeImages(
        _frontImage!,
        _angleImage!,
        _sideImage!,
        gender: _selectedGender, // Pass selected gender to the analysis
      );

      setState(() {
        _currentAnalysis = analysis;
        _isAnalyzing = false;
        // Trigger animation for results display
        Future.delayed(Duration(milliseconds: 100), () {
          setState(() {
            _showResultsAnimation = true;
          });
        });
      });

      _loadPastAnalyses(); // Refresh history after new analysis
    } catch (e) {
      // Clear all images since the analysis failed
      setState(() {
        _isAnalyzing = false;
        _frontImage = null;
        _angleImage = null;
        _sideImage = null;
        _currentImageStep = 0;
      });

      // Show detailed error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Analysis Failed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We couldn\'t analyze your face properly. Please try again with clearer photos.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Tips for better photos:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 12),
              _buildTip('Make sure your face is well-lit'),
              _buildTip('Keep your face fully visible in the frame'),
              _buildTip('Avoid shadows on your face'),
              _buildTip('Use a neutral expression'),
              _buildTip('Take photos against a plain background'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back to image upload screen
                _pageController.animateToPage(
                  2,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _clearImagesAndResults() {
    setState(() {
      _frontImage = null;
      _angleImage = null;
      _sideImage = null;
      _currentAnalysis = null;
      _currentImageStep = 0;
      _showStepAnimation = false;
      _showResultsAnimation = false;
      _tabController.animateTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: _isAnalyzing
            ? _buildAnalyzingState()
            : _currentAnalysis != null
                ? _buildResultsWithNewOption()
                : _pastAnalyses.isNotEmpty && _currentPage == 0
                    ? _buildAnalysisHistoryScreen()
                    : PageView(
                        controller: _pageController,
                        physics: _currentPage == 2
                            ? NeverScrollableScrollPhysics()
                            : BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        children: [
                          _buildIntroScreen(),
                          _buildGenderSelectionScreen(),
                          _buildImageUploadScreen(),
                        ],
                      ),
      ),
    );
  }

  // INTRO SCREEN
  Widget _buildIntroScreen() {
    return Stack(
      children: [
        // Background image or gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
            ),
          ),
        ),
        
        // Content
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and title
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Face Workout',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Spacer(),
                      // Show remaining free scans if not premium
                      FutureBuilder<bool>(
                        future: SubscriptionHandler.isPremium(),
                        builder: (context, snapshot) {
                          final isPremium = snapshot.data ?? false;
                          
                          if (isPremium) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _primaryColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium,
                                    size: 14,
                                    color: _primaryColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            final remainingScans = 3 - _faceScanCount;
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$remainingScans Free Scans',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),

                // Modern SF style header
                Container(
                  padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 30),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FaceAI",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (_pastAnalyses.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentAnalysis = _pastAnalyses.first;
                              _showResultsAnimation = true;
                            });
                          },
                          child: Container(
                            padding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history,
                                  color: _primaryColor,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "History",
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView( // Added to make content scrollable
                      physics: BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // Added to minimize column size
                        children: [
                          SizedBox(height: 16), // Added padding at top
                          // Modern illustration
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5, // Reduced from 0.6
                            height: MediaQuery.of(context).size.width * 0.5, // Reduced from 0.6
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/scan.png',
                                fit: BoxFit.cover,
                                width: MediaQuery.of(context).size.width * 0.4, // Reduced from 0.5
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback if image not found
                                  return Icon(
                                    Icons.face_retouching_natural,
                                    size: MediaQuery.of(context).size.width * 0.2, // Reduced from 0.25
                                    color: _primaryColor,
                                  );
                                },
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: Duration(milliseconds: 800))
                              .slideY(begin: 0.05, end: 0),
              
                          SizedBox(height: 30), // Reduced from 48
              
                          // Title with modern typography
                          Text(
                            "Facial Analysis Scanner",
                            style: TextStyle(
                              fontSize: 24, // Reduced from 28
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 12), // Reduced from 16
              
                          // Description with SF style
                          Text(
                            "Upload three photos of your face and get AI-powered analysis with personalized recommendations.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14, // Reduced from 16
                              color: _lightTextColor,
                              height: 1.3, // Reduced from 1.4
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 30), // Reduced from 48
              
                          // Modern SF style button
                          GestureDetector(
                            onTap: () {
                              // Simply proceed to next screen, premium check will happen later
                              _pageController.animateToPage(
                                1,
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 50, // Reduced from 56
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Begin Scan",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textLight,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: AppColors.textLight,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                  duration: Duration(milliseconds: 600),
                                  delay: Duration(milliseconds: 400))
                              .slideY(begin: 0.2, end: 0),
                          SizedBox(height: 16), // Added bottom padding
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // GENDER SELECTION SCREEN
  Widget _buildGenderSelectionScreen() {
    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          // Modern header with SF style
          Container(
            padding: EdgeInsets.only(left: 4, right: 20, top: 16, bottom: 16),
            decoration: BoxDecoration(
              color: _backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: _textColor, size: 18),
                  onPressed: () {
                    _pageController.animateToPage(
                      0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                Text(
                  "Select Your Gender",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),

                    Text(
                      "Choose Your Gender",
                      style: TextStyle(
                        fontSize: 24, // Reduced from 28
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                        letterSpacing: -0.5,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: Duration(milliseconds: 600))
                        .slideY(begin: 0.1, end: 0),

                    SizedBox(height: 8), // Reduced from 12

                    Text(
                      "This helps us provide more accurate analysis",
                      style: TextStyle(
                        fontSize: 15, // Reduced from 16
                        color: _lightTextColor,
                        letterSpacing: -0.3,
                      ),
                    )
                        .animate()
                        .fadeIn(
                            duration: Duration(milliseconds: 600),
                            delay: Duration(milliseconds: 200))
                        .slideY(begin: 0.1, end: 0),

                    SizedBox(height: 30), // Reduced from 60

                    // Modern gender selection options with SF style
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildGenderOption("male", Icons.male, "Male"),
                        ),
                        SizedBox(width: 16), // Reduced from 24
                        Expanded(
                          child: _buildGenderOption(
                              "female", Icons.female, "Female"),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(
                            duration: Duration(milliseconds: 600),
                            delay: Duration(milliseconds: 400))
                        .slideY(begin: 0.1, end: 0),

                    SizedBox(height: 30), // Reduced from 80

                    // Continue button with SF style
                    GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          2,
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50, // Reduced from 56
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLight,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.textLight,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(
                            duration: Duration(milliseconds: 600),
                            delay: Duration(milliseconds: 600))
                        .slideY(begin: 0.2, end: 0),
                    
                    SizedBox(height: 20), // Add bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern gender option with SF style
  Widget _buildGenderOption(String gender, IconData icon, String label) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Reduced vertical padding
        decoration: BoxDecoration(
          color:
              isSelected ? _primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
          children: [
            Container(
              width: 56, // Reduced size
              height: 56, // Reduced size
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 28, // Reduced size
                color: isSelected ? Colors.white : _lightTextColor,
              ),
            ),
            SizedBox(height: 12), // Reduced spacing
            Text(
              label,
              style: TextStyle(
                fontSize: 16, // Reduced font size
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _primaryColor : _textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // IMAGE UPLOAD SCREEN
  Widget _buildImageUploadScreen() {
    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          // Modern SF style header
          Container(
            padding: EdgeInsets.only(left: 4, right: 20, top: 16, bottom: 16),
            decoration: BoxDecoration(
              color: _backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: _textColor, size: 18),
                  onPressed: () {
                    // Go back to the previous screen
                    _pageController.animateToPage(
                      1,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Upload Photos",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Step ${_currentImageStep + 1} of 3",
                      style: TextStyle(
                        fontSize: 13,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Row(
                  children: [
                    _buildProgressDot(0),
                    SizedBox(width: 8),
                    _buildProgressDot(1),
                    SizedBox(width: 8),
                    _buildProgressDot(2),
                  ],
                ),
              ],
            ),
          ),

          // Content area with all three steps
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),

                  // Step title with SF style
                  Text(
                    _getStepTitle(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Step description
                  Text(
                    _getStepDescription(),
                    style: TextStyle(
                      fontSize: 15,
                      color: _lightTextColor,
                      height: 1.4,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Image upload area
                  Expanded(
                    child: _buildCurrentStepContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build content based on current step
  Widget _buildCurrentStepContent() {
    File? currentImage;
    String assetImagePath = "assets/images/";

    switch (_currentImageStep) {
      case 0:
        currentImage = _frontImage;
        assetImagePath += "front.png";
        break;
      case 1:
        currentImage = _angleImage;
        assetImagePath += "angle.png";
        break;
      case 2:
        currentImage = _sideImage;
        assetImagePath += "side.png";
        break;
    }

    return Column(
      children: [
        // Image preview or upload container
        Expanded(
          child: GestureDetector(
            onTap: () => _showImagePickerDialog(_currentImageStep),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _primaryColor.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: currentImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            currentImage,
                            fit: BoxFit.cover,
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.5),
                                ],
                                stops: [0.7, 1.0],
                              ),
                            ),
                          ),
                          // Info text
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Text(
                              'Tap to change photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Example image showing the expected face position
                            Container(
                              width: 140,
                              height: 140,
                              margin: EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _primaryColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(
                                  assetImagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.face,
                                      size: 60,
                                      color: _primaryColor.withOpacity(0.5),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Upload icon in a shiny circle
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryColor,
                                    _primaryColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Icon(
                                Icons.add_a_photo,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tap to upload your photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _getStepDescription(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _lightTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),

        SizedBox(height: 24),

        // Bottom buttons
        Row(
          children: [
            // Back button (except for first step)
            if (_currentImageStep > 0)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentImageStep--;
                    });
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: _textColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            if (_currentImageStep > 0) SizedBox(width: 16),

            // Next/Analyze button
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: () {
                  if (_currentImageStep == 2) {
                    // On last step, check if all images are uploaded
                    if (_frontImage != null &&
                        _angleImage != null &&
                        _sideImage != null) {
                      _captureAndAnalyze();
                    } else {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please upload all three images first'),
                          backgroundColor: _accentColor,
                        ),
                      );
                    }
                  } else {
                    // Not on last step
                    if (currentImage != null) {
                      // Image is uploaded, proceed to next step
                      setState(() {
                        _currentImageStep++;
                      });
                    } else {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please upload an image first'),
                          backgroundColor: _accentColor,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentImageStep == 2 ? 'Analyze Photos' : 'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          _currentImageStep == 2
                              ? Icons.analytics
                              : Icons.arrow_forward,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
      ],
    );
  }
  
  // Helper method to get step-specific instructions
  String _getStepInstructions() {
    switch (_currentImageStep) {
      case 0:
        return "Face directly at the camera";
      case 1:
        return "Turn your face at 45° angle";
      case 2:
        return "Show your profile, side view";
      default:
        return "";
    }
  }

  // Progress dot indicator with SF style
  Widget _buildProgressDot(int step) {
    final bool isActive = _currentImageStep >= step;
    final bool isCurrent = _currentImageStep == step;

    return Container(
      width: isCurrent ? 10 : 8,
      height: isCurrent ? 10 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? _primaryColor : Colors.grey.shade300,
        border: isCurrent
            ? Border.all(color: _primaryColor.withOpacity(0.3), width: 2)
            : null,
      ),
    );
  }

  // Analyzing state with animation
  Widget _buildAnalyzingState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern scanner animation
            Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.width * 0.4,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing circle
                  Container(
                    width: MediaQuery.of(context).size.width * 0.38,
                    height: MediaQuery.of(context).size.width * 0.38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .scale(
                        begin: Offset(1, 1),
                        end: Offset(1.1, 1.1),
                        duration: Duration(seconds: 1),
                      )
                      .then()
                      .scale(
                        begin: Offset(1.1, 1.1),
                        end: Offset(1, 1),
                        duration: Duration(seconds: 1),
                      ),

                  // Scan animation
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _primaryColor.withOpacity(0.8),
                          _primaryColor.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.face,
                      size: 60,
                      color: Colors.white,
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .shimmer(
                        duration: Duration(seconds: 2),
                        color: Colors.white.withOpacity(0.5),
                      ),
                ],
              ),
            ),
            SizedBox(height: 40),
            Text(
              'Analyzing Your Face...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Our AI is carefully examining your features\nPlease wait a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _lightTextColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Results display with new analysis option
  Widget _buildResultsWithNewOption() {
    // Call handler when results are shown
    
    if (_currentAnalysis != null && _showResultsAnimation) {
      Future.microtask(() => _handleAnalysisShown());
    }

    return Stack(
      children: [
        // Existing results content
        SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: AnimatedOpacity(
            duration: _fastAnimation,
            opacity: _showResultsAnimation ? 1.0 : 0.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with summary
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.06),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 360;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button, share button, and date
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentAnalysis = null;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  // Share button - changed to show options dialog
                                  GestureDetector(
                                    onTap: () => _showShareOptionsDialog(),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      margin: EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.share,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.textSecondary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: AppColors.textPrimary,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _formatDate(_currentAnalysis!.timestamp),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Modern title with badge - more responsive on small screens
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Your Face Analysis',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 20 : 24,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _primaryColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Dietly AI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    SizedBox(height: 8),
                                    
                                    // Subtitle with animation
                                    Text(
                                      'Personalized insights based on your facial features',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _lightTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          _buildKeyScoreCards(),
                        ],
                      );
                    }
                  ),
                ),

                SizedBox(height: 20),

                // Create Workout Plan Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => _navigateToWorkoutPlan(),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: AppColors.textLight,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Create Personalized Workout Plan',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Main content sections with cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section title with animated underline
                      _buildSectionTitle('Detailed Scores'),
                      SizedBox(height: 12),
                      _buildScoresGrid(),
                      SizedBox(height: 24),

                      // Facial attributes section
                      _buildSectionTitle('Facial Attributes'),
                      SizedBox(height: 12),
                      _buildAttributesSection(),
                      SizedBox(height: 24),

                      // Recommendations section
                      _buildSectionTitle('Recommendations'),
                      SizedBox(height: 12),
                      _buildRecommendationsSection(),
                      SizedBox(height: 24),

                      // Photos used for analysis
                      _buildSectionTitle('Photos Used'),
                      SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: _buildPhotosGrid(),
                      ),
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Build section title with animated underline
  Widget _buildSectionTitle(String title, {bool animate = true}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 4),
          animate
              ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: _normalAnimation,
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Container(
                      height: 3,
                      width: 70 * value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                )
              : Container(
                  height: 3,
                  width: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ],
      ),
    );
  }

  // Key score cards in header
  Widget _buildKeyScoreCards() {
    // Check if we have the key metrics with real values
    Map<String, double> keyMetrics = {};

    if (_currentAnalysis != null) {
      // Using existing values but mapping to new metric names
      final masculinity = _currentAnalysis!.scores['harmony'] ?? 0;  // Repurpose harmony score
      final overallAttractiveness = _currentAnalysis!.scores['symmetry'] ?? 0;  // Repurpose symmetry score
      final structure = _currentAnalysis!.scores['balance'] ?? 0;  // Repurpose balance score

      if (masculinity > 0) keyMetrics['Masculinity'] = masculinity / 10.0;
      if (overallAttractiveness > 0) keyMetrics['Attractiveness'] = overallAttractiveness / 10.0;
      if (structure > 0) keyMetrics['Structure'] = structure / 10.0;
    }

    // If no valid metrics, show a stylish placeholder
    if (keyMetrics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
              padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                ),
                  child: Icon(
                Icons.face,
                color: Colors.white,
                size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
              child: Text(
                'Complete analysis to see key facial metrics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                ),
              ),
            ],
          ),
      );
    }

    // Return a responsive layout container
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we need a vertical layout for small screens
        final useVerticalLayout = constraints.maxWidth < 350;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(useVerticalLayout ? 12 : 16),
          child: useVerticalLayout
            // Vertical layout for small screens
            ? Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                  // Header
                  Row(
              children: [
                Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
                        child: Icon(
                          Icons.face,
              color: Colors.white,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Facial Analysis',
                        style: TextStyle(
                  color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                  ),
                    ),
                  ],
                ),
                  SizedBox(height: 16),
                  // Score cards
                  ...keyMetrics.entries.map((entry) {
                    // Use white color for all progress indicators for better visibility
                    final Color color = Colors.white;
                    
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                  children: [
                          // Progress indicator
                          Container(
                            height: 40,
                            width: 40,
                            margin: EdgeInsets.only(right: 12),
                            child: Stack(
                              alignment: Alignment.center,
                      children: [
                                CircularProgressIndicator(
                                  value: entry.value / 10,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.grey[300]?.withOpacity(0.3) ?? Colors.white.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                ),
                            Text(
                                  '${entry.value.toStringAsFixed(1)}',
                              style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                          ),
                          // Label and score
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                // Score bar
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300]?.withOpacity(0.3) ?? Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return FractionallySizedBox(
                                        widthFactor: entry.value / 10,
              child: Container(
                      decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      );
                                    },
                                            ),
                                          ),
                                        ],
                                      ),
                                          ),
                                        ],
                                      ),
                    );
                  }).toList(),
                ],
              )
            // Horizontal layout for larger screens
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                                Row(
                                  children: [
                                      Container(
                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                                        ),
                                        child: Icon(
                                          Icons.face,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                                          Text(
                        'Facial Analysis',
                                            style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Score cards in a row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: keyMetrics.entries.map((entry) {
                      // Use white color for all progress indicators for better visibility
                      final Color color = Colors.white;
                      
                                              return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                                                child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                              // Circular progress indicator
                                                    Stack(
                                alignment: Alignment.center,
                                                      children: [
                                                        SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: CircularProgressIndicator(
                                      value: entry.value / 10,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.grey[300]?.withOpacity(0.3) ?? Colors.white.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                                        Text(
                                        '${entry.value.toStringAsFixed(1)}',
                                                          style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                ],
                              ),
                              SizedBox(height: 10),
                              // Label
                                                    Text(
                                entry.key,
                                                      style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
              ),
        );
      }
    );
  }

  // Get gradient colors based on index
  List<Color> _getGradientForIndex(int index) {
    List<List<Color>> gradients = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Purple-indigo
      [Color(0xFFEC4899), Color(0xFFF472B6)], // Pink shades
      [Color(0xFF0EA5E9), Color(0xFF38BDF8)], // Blue shades
      [Color(0xFF10B981), Color(0xFF34D399)], // Green shades
      [Color(0xFFF59E0B), Color(0xFFFBBF24)], // Amber shades
    ];

    return gradients[index % gradients.length];
  }

  // Get top 3 scores from analysis to display in card
  List<MapEntry<String, int>> _getTopScores(FaceAnalysis analysis) {
    final scores = analysis.scores.entries.toList();
    // Sort by value in descending order
    scores.sort((a, b) => b.value.compareTo(a.value));
    // Take top 3 or fewer if there are less than 3
    return scores.take(3).toList();
  }

  // Navigate to workout plan screen
  void _navigateToWorkoutPlan() {
    if (_currentAnalysis == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyFaceWorkoutsScreen(
          faceAnalysis: _currentAnalysis,
        ),
      ),
    );
  }

  // Helper methods for step titles and descriptions
  String _getStepTitle() {
    switch (_currentImageStep) {
      case 0:
        return "Front View";
      case 1:
        return "Angled View";
      case 2:
        return "Side View";
      default:
        return "Upload Photo";
    }
  }

  String _getStepDescription() {
    switch (_currentImageStep) {
      case 0:
        return "Take a clear photo of your face from the front";
      case 1:
        return "Take a photo from a 45-degree angle";
      case 2:
        return "Take a clear photo of your face from the side";
      default:
        return "Upload a photo for analysis";
    }
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Helper method to format score labels
  String _formatScoreLabel(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Add a handler for when analysis is shown
  void _handleAnalysisShown() {
    if (!_hasShownShareDialog &&
        !_neverShowShareDialog &&
        _currentAnalysis != null) {
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted) {
          _showShareDialog();
        }
      });
    }
  }

  // Show the share dialog
  void _showShareDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primaryColor.withOpacity(0.02),
                Color(0xFFEEF2FF),
              ],
            ),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header image - more eye-catching
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Title with gradient text
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'Share Your Results',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Share your face analysis results with friends and family on your favorite social platforms!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textColor.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: 32),
              // Buttons - simplified to two buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Not Now button
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _saveSharePreferences(hasShown: true);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Not Now',
                        style: TextStyle(
                          color: _textColor.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Share Now button - more attractive
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _saveSharePreferences(hasShown: true);
                        _generateAndShareImage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: AppColors.textLight,
                        elevation: 4,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        shadowColor: _primaryColor.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Share Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Don't ask again option - as a simple text link
              GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await _saveSharePreferences(hasShown: true, neverShow: true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Don\'t ask again',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor.withOpacity(0.4),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Generate and share image with optimized layout
  Future<void> _generateAndShareImage() async {
    if (_currentAnalysis == null) return;
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(width: 16),
                Text('Creating share image...'),
              ],
            ),
          ),
        ),
      );
      
      // Create a screenshot controller
      final screenshotController = ScreenshotController();
      
      // Get all scores for display
      final allScores = _currentAnalysis!.scores.entries.toList();
      // Sort by value in descending order
      allScores.sort((a, b) => b.value.compareTo(a.value));
      
      // Take screenshot of the optimized content widget
      final Uint8List? imageBytes = await screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: Container(
            width: 600,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                        AppColors.primaryLight,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Profile photo - side aligned for space efficiency
                      if (_currentAnalysis!.faceImagePath != null)
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.textLight.withOpacity(0.8),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.file(
                              File(_currentAnalysis!.faceImagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            border: Border.all(
                              color: AppColors.textLight.withOpacity(0.8),
                              width: 3,
                            ),
                          ),
                          child: Icon(Icons.face, color: AppColors.textLight, size: 36),
                        ),
                      SizedBox(width: 16),
                      // Title aligned next to the photo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App branding
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.textLight.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.verified,
                                    color: AppColors.textLight,
                                    size: 12,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Dietly AI PREMIUM',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            // Analysis title
                            Text(
                              'Face Analysis Results',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content area with optimized spacing
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Metrics Section
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'KEY METRICS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Top metrics in a row - first 4 emphasized
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: allScores.take(4).map((score) {
                          final Color color = _getAppColorForScore(score.value.toDouble());
                          return Expanded(
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.background,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: CircularProgressIndicator(
                                          value: score.value / 100,
                                          strokeWidth: 4,
                                          backgroundColor: AppColors.surfaceColor,
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                        ),
                                      ),
                                      Text(
                                        "${score.value}%",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5),
                                Container(
                                  width: 60,
                                  child: Text(
                                    _formatScoreLabel(score.key),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Remaining metrics in a wrapped grid with smaller circles
                      if (allScores.length > 4) ...[
                        SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 12,
                          children: allScores.skip(4).map((score) {
                            final Color color = _getAppColorForScore(score.value.toDouble());
                            return Container(
                              width: 50,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Smaller circular progress indicator
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.background,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 46,
                                          height: 46,
                                          child: CircularProgressIndicator(
                                            value: score.value / 100,
                                            strokeWidth: 3,
                                            backgroundColor: AppColors.surfaceColor,
                                            valueColor: AlwaysStoppedAnimation<Color>(color),
                                          ),
                                        ),
                                        Text(
                                          "${score.value}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatScoreLabel(score.key),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      
                      // Slim divider
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 16),
                        height: 1,
                        width: double.infinity,
                        color: AppColors.surfaceColor,
                      ),
                      
                      // Facial attributes section
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'FACIAL ATTRIBUTES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      
                      // Grid of attributes - compressed for better fit
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: _currentAnalysis!.attributes.entries.take(6).map((entry) {
                          return Container(
                            width: 120,
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.surfaceColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getAttributeIcon(entry.key),
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatAttributeLabel(entry.key),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 7,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Footer with app branding - slimmer design
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Created with Dietly',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
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
          ),
        ),
        pixelRatio: 3.0,
        context: context,
      );
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (imageBytes == null) {
        throw Exception('Failed to capture the share image');
      }
      
      // Save the image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/dietly_analysis_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      // Share the image file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out my face analysis from Dietly!',
        subject: 'My Face Analysis Results',
      );
    } catch (e) {

      if (context.mounted) {
        // Remove loading dialog if still showing
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create share image: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Helper method to get appropriate app color based on score
  Color _getAppColorForScore(double score) {
    if (score >= 70)
      return AppColors.success; // Green for scores above 70%
    if (score >= 50) 
      return AppColors.warning; // Yellow/amber for medium scores
    return AppColors.error; // Red for low scores
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Add this method to show the share options dialog
  void _showShareOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF3F4FF),
              ],
            ),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with colorful icon
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Share Results',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Choose how you want to share your analysis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _lightTextColor,
                ),
              ),
              SizedBox(height: 24),

              // Share options
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildShareOption('Image', Icons.image, Color(0xFF34C759),
                      () {
                    Navigator.pop(context);
                    _generateAndShareImage();
                  }),
                  _buildShareOption(
                      'Text', Icons.text_fields, Color(0xFF007AFF), () {
                    Navigator.pop(context);
                    _shareAsText();
                  }),
                  _buildShareOption(
                      'PDF', Icons.picture_as_pdf, Color(0xFFFF3B30), () {
                    Navigator.pop(context);
                    _showComingSoonMessage('PDF sharing');
                  }),
                ],
              ),

              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: _lightTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build share option
  Widget _buildShareOption(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Share analysis as text only
  Future<void> _shareAsText() async {
    if (_currentAnalysis == null) return;

    try {
      // Create text content to share
      final topScores = _getTopScores(_currentAnalysis!);

      String shareText = 'My Face Analysis Results\n';
      shareText += 'Date: ${_formatDate(_currentAnalysis!.timestamp)}\n\n';
      shareText += 'Key Metrics:\n';

      for (var score in topScores) {
        shareText += '• ${_formatScoreLabel(score.key)}: ${score.value}%\n';
      }

      shareText += '\nShared from FaceAI App';

      // Share the text
      await Share.share(
        shareText,
        subject: 'My Face Analysis Results',
      );
    } catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share results: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show coming soon message for features not yet implemented
  void _showComingSoonMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: _primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Detailed scores grid with improved responsiveness
  Widget _buildScoresGrid() {
    if (_currentAnalysis == null) return SizedBox.shrink();
    
    // Sorted scores for better display
    final sortedScores = _currentAnalysis!.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine grid columns based on available width
        final isNarrow = constraints.maxWidth < 360;
        
        return Wrap(
          spacing: 8,  // Horizontal space between items
          runSpacing: 8, // Vertical space between rows
          children: sortedScores.map((entry) {
            // Format score from 0-10 scale to percentage
            final score = entry.value / 10;
            final scorePercent = (score * 100).toInt();
            
            // Determine color based on score value
            final color = _getScoreColor(score);
            
            // Calculate item width based on available space
            final itemWidth = isNarrow 
                ? (constraints.maxWidth / 2) - 8  // 2 columns for narrow screens
                : (constraints.maxWidth / 3) - 8; // 3 columns for wider screens
            
            return Container(
              width: itemWidth,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score name
                  Text(
                    _formatScoreLabel(entry.key),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  
                  // Progress bar
                  LinearProgressIndicator(
                    value: score,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  SizedBox(height: 6),
                  
                  // Score value
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$scorePercent%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }
    );
  }
  
  // Get color based on score value
  Color _getScoreColor(double score) {
    if (score >= 0.7) return Color(0xFF34C759); // Green for high scores
    if (score >= 0.5) return Color(0xFFFFD60A); // Yellow for medium scores
    return Color(0xFFFF375F); // Red for low scores
  }
  
  // Build attributes section with responsive design
  Widget _buildAttributesSection() {
    if (_currentAnalysis == null || _currentAnalysis!.attributes.isEmpty) {
      return Center(
        child: Text(
          'No attribute data available',
          style: TextStyle(color: _lightTextColor),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        
        return ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _currentAnalysis!.attributes.length,
          itemBuilder: (context, index) {
            final entry = _currentAnalysis!.attributes.entries.elementAt(index);
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attribute icon
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.face,
                      color: _primaryColor,
                      size: isNarrow ? 16 : 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // Flexible text content to prevent overflow
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatScoreLabel(entry.key),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: _lightTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }
  
  // Recommendations section with responsive layout
  Widget _buildRecommendationsSection() {
    if (_currentAnalysis == null || _currentAnalysis!.recommendations.isEmpty) {
      return Center(
        child: Text(
          'No recommendations available',
          style: TextStyle(color: _lightTextColor),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _currentAnalysis!.recommendations.length,
          itemBuilder: (context, index) {
            final recommendation = _currentAnalysis!.recommendations[index];
            return Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: _primaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates,
                        color: _primaryColor,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      // Make the title flexible to prevent overflow
                      Expanded(
                        child: Text(
                          recommendation.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    recommendation.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }
  
  // Grid of photos used for analysis
  Widget _buildPhotosGrid() {
    if (_currentAnalysis == null) return SizedBox.shrink();
    
    // Get photos from current analysis
    final photos = [
      _currentAnalysis!.faceImagePath,
      _currentAnalysis!.angleImagePath,
      _currentAnalysis!.sideImagePath,
    ];
    
    final labels = ['Front', 'Angle', 'Side'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 3;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            return Container(
              width: itemWidth,
              height: 140,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Photo container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(File(photos[index] ?? '')),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  
                  // Label
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      }
    );
  }
  
  // Build detailed scores section
  Widget _buildDetailedScores() {
    if (_currentAnalysis == null || _currentAnalysis!.scores.isEmpty) {
      return Center(
        child: Text(
          'No detailed score data available',
          style: TextStyle(color: _lightTextColor),
        ),
      );
    }
    
    // Filter out scores we don't want to show or format differently
    Map<String, int> filteredScores = Map.from(_currentAnalysis!.scores);
    filteredScores.remove('harmony');
    filteredScores.remove('symmetry');
    filteredScores.remove('balance');
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredScores.length,
      itemBuilder: (context, index) {
        final entry = filteredScores.entries.elementAt(index);
        
        // Format display name
        final displayName = _formatScoreLabel(entry.key);
        
        // Convert to double for progress value (0.0 to 1.0)
        final score = entry.value.toDouble() / 10.0;
        
        // Determine color based on score
        Color scoreColor;
        if (score >= 0.7) {
          scoreColor = Colors.green;
        } else if (score >= 0.5) {
          scoreColor = Colors.orange;
        } else {
          scoreColor = Colors.red;
        }
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(score * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              LinearProgressIndicator(
                value: score,
                backgroundColor: Colors.grey.withOpacity(0.1),
                color: scoreColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  // Analysis history screen
  Widget _buildAnalysisHistoryScreen() {
    return Scaffold(
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            setState(() {
              _currentAnalysis = null;
              _currentPage = 1;
              _currentImageStep = 0;
              _frontImage = null;
              _angleImage = null;
              _sideImage = null;
              _showStepAnimation = false;
              _showResultsAnimation = false;
              _selectedGender = "male";
            });

            Future.delayed(Duration(milliseconds: 50), () {
              if (mounted) {
                setState(() {
                  _currentPage = 1;
                });
              }
            });
          },
          backgroundColor: _primaryColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_a_photo, size: 24, color: Colors.white),
          ),
          label: Text(
            'New Face Scan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoadingHistory
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : _pastAnalyses.isEmpty
                ? _buildEmptyHistoryState()
                : _buildAnalysisHistoryList(),
      ),
    );
  }

  // Empty history state
  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          SizedBox(height: 24),
          Text(
            'No Analysis History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Complete your first face analysis to see history',
            style: TextStyle(
              fontSize: 16,
              color: _lightTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Analysis history list
  Widget _buildAnalysisHistoryList() {
    return CustomScrollView(
      slivers: [
        // Modern Header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Face Analysis History",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Track your facial analysis progress",
                          style: TextStyle(
                            fontSize: 16,
                            color: _lightTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.face_retouching_natural,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // List of analyses
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final analysis = _pastAnalyses[index];
                final topScores = _getTopScores(analysis);
                
                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentAnalysis = analysis;
                          _showResultsAnimation = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Date and time
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: _primaryColor,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        _formatDate(analysis.timestamp),
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Spacer(),
                                // View details button
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "View Details",
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: _primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Thumbnail and scores
                            Row(
                              children: [
                                // Thumbnail
                                if (analysis.faceImagePath != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(analysis.faceImagePath ?? ''),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.face,
                                      color: AppColors.textLight,
                                      size: 36,
                                    ),
                                  ),
                                SizedBox(width: 16),
                                // Scores
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Key Metrics",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _lightTextColor,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: topScores.take(3).map((score) {
                                          final percentage = score.value / 10;
                                          final color = _getScoreColor(percentage);
                                          return Expanded(
                                            child: Column(
                                              children: [
                                                Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: 40,
                                                      height: 40,
                                                      child: CircularProgressIndicator(
                                                        value: percentage,
                                                        strokeWidth: 4,
                                                        backgroundColor: color.withOpacity(0.1),
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                            color),
                                                      ),
                                                    ),
                                                    Text(
                                                      "${score.value}",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: _textColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  _formatScoreLabel(score.key),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _lightTextColor,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _pastAnalyses.length,
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper method to get attribute icon based on key
  IconData _getAttributeIcon(String key) {
    switch (key.toLowerCase()) {
      case 'symmetry':
      case 'attractiveness':
        return Icons.auto_awesome;
      case 'harmony':
      case 'masculinity':
        return Icons.face;
      case 'balance':
      case 'structure':
        return Icons.architecture;
      case 'proportion':
        return Icons.straighten;
      case 'clarity':
        return Icons.visibility;
      default:
        return Icons.face;
    }
  }
  
  // Helper method to format attribute labels
  String _formatAttributeLabel(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Helper method to build tip items for face scanning guidance
  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

