import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrition_info.dart';
import '../services/image_to_gpt_service.dart';
import '../services/food_hive_service.dart';
import 'package:intl/intl.dart';
import '../utils/date_utils.dart';
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';

// Development mode flag - set to true for unlimited scans and always show demo
const bool _isDevelopmentMode = false;

// Constants for scan limit - combined for both food and label scans
const String _freeScanCountKey = 'free_scan_count';
const int _maxFreeScans = 4; // Combined limit for both food and label scans

// Key for tracking if label scan demo was shown
const String _labelScanDemoShownKey = 'label_scan_demo_shown';

// Key for tracking how many times the label scan demo has been shown
const String _labelScanDemoCountKey = 'label_scan_demo_count';
const int _maxLabelScanDemoShows = 2;

// Scan mode selection
enum ScanMode { food, label, gallery }

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path();
    
    // Top line
    _drawDashedLine(canvas, paint, 
      Offset(0, 0), 
      Offset(size.width, 0)
    );
    
    // Right line
    _drawDashedLine(canvas, paint, 
      Offset(size.width, 0), 
      Offset(size.width, size.height)
    );
    
    // Bottom line
    _drawDashedLine(canvas, paint, 
      Offset(size.width, size.height), 
      Offset(0, size.height)
    );
    
    // Left line
    _drawDashedLine(canvas, paint, 
      Offset(0, size.height), 
      Offset(0, 0)
    );
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    // Calculate the length of the line
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double distance = sqrt(dx * dx + dy * dy);
    
    // Calculate the number of dashes
    int dashCount = (distance / (2 * gap)).floor();
    
    // Calculate the unit vector along the line
    double unitX = dx / distance;
    double unitY = dy / distance;
    
    // Draw the dashes
    for (int i = 0; i < dashCount; i++) {
      double startFraction = i * 2 * gap / distance;
      double endFraction = (i * 2 * gap + gap) / distance;
      
      endFraction = endFraction > 1.0 ? 1.0 : endFraction;
      
      double startX = start.dx + unitX * distance * startFraction;
      double startY = start.dy + unitY * distance * startFraction;
      double endX = start.dx + unitX * distance * endFraction;
      double endY = start.dy + unitY * distance * endFraction;
      
      canvas.drawLine(
        Offset(startX, startY), 
        Offset(endX, endY), 
        paint
      );
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => 
    oldDelegate.color != color ||
    oldDelegate.strokeWidth != strokeWidth ||
    oldDelegate.gap != gap;
}

class ScanFoodScreen extends StatefulWidget {
  final Function? onFoodLogged;
  final DateTime? selectedDate;

  const ScanFoodScreen({
    super.key,
    this.onFoodLogged,
    this.selectedDate,
  });

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final ImageToGptService _gptService = ImageToGptService();
  final FoodHiveService _foodHiveService = FoodHiveService();

  // Design constants - using AppColors instead of local definitions
  Color get _primaryColor => AppColors.primary;
  Color get _accentColor => AppColors.error;
  Color get _cardColor => AppColors.cardBackground;
  Color get _textColor => AppColors.textPrimary;
  Color get _lightTextColor => AppColors.textSecondary;

  // Animation controller for option buttons
  late AnimationController _animationController;

  // Pref key for guideline shown
  static const String _guidelineShownKey = 'scan_food_guideline_shown';

  bool _isProcessing = false;
  File? _imageFile;
  NutritionInfo? _nutritionInfo;
  String _selectedMeal = 'Lunch';
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final _flashModes = [FlashMode.off, FlashMode.auto, FlashMode.always];
  int _currentFlashIndex = 0;
  int _selectedOptionIndex = 0;
  
  // Store effective date to be used for logging food - don't set directly to now
  DateTime _effectiveDate = AppDateUtils.getToday(); // Initialize with today, but will be updated in _initializeDate

  // Variables for focus UI
  Offset? _focusPoint;
  bool _isFocusing = false;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  // Add scan count tracking
  int _remainingFreeScans = _maxFreeScans;
  bool _isPremium = false;
  
  // Scan mode selection
  ScanMode _selectedScanMode = ScanMode.food;

  @override
  void initState() {
    super.initState();
 
    _initializeCamera();
    Posthog().screen(
      screenName: 'Scan Food Screen',
    );

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize date from SharedPreferences or widget.selectedDate - this is run first
    _initializeDate();

    // Check if we should show guidelines on first launch
    _checkAndShowGuidelines();
    
    // Load remaining free scans count and premium status
    _loadScanCount();
    _checkPremiumStatus();
  }
  
  Future<void> _initializeDate() async {


    
    try {
      DateTime selectedDate;
      
      // Priority 1: Use widget.selectedDate if provided
      if (widget.selectedDate != null) {
        selectedDate = AppDateUtils.validateDate(widget.selectedDate!);
   
      }
      // Priority 2: Load from SharedPreferences
      else {
        selectedDate = await AppDateUtils.getSelectedDate();
    
      }
      
      // Set the effective date
      if (mounted) {
        setState(() {
          _effectiveDate = selectedDate;
         
        });
        
        // Ensure the date is saved to SharedPreferences for consistency across screens
        AppDateUtils.saveSelectedDate(_effectiveDate).then((success) {
         
        });
        
        // Log the formatted date for debugging
        final formattedDate = AppDateUtils.formatDateForDisplay(_effectiveDate);
       
      }
      

    } catch (e) {
      // In case of any error, use today's date
      final today = AppDateUtils.getToday();
      
      if (mounted) {
        setState(() {
          _effectiveDate = today;
        });
      
      }
    }
  }

  Future<void> _checkAndShowGuidelines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShownGuideline = prefs.getBool(_guidelineShownKey) ?? false;

      if (!hasShownGuideline) {
        // Wait for the build to complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showScanningGuidelines();
        });

        // Mark as shown
        await prefs.setBool(_guidelineShownKey, true);
      }
    } catch (e) {

    }
  }
  
  // Helper method to format date for display
  String _getFormattedDate(DateTime date) {
    return AppDateUtils.formatDateForDisplay(date);
  }

  @override
  void dispose() {
    if (_isCameraInitialized) {
      _cameraController!.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Set flag to indicate we're trying to initialize
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    
    try {
      // Get available cameras with timeout
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Camera discovery timed out');
        },
      );
      
      if (cameras.isEmpty) {
        if (mounted) {
          _showError('No cameras found on device');
        }
        return;
      }

      // Dispose of previous controller if it exists
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isInitialized) {
            await _cameraController!.dispose();
          }
        } catch (e) {
          // Ignore errors during disposal
        }
      }

      // Create new controller with safer settings
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium, // Use medium instead of high for better compatibility
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.yuv420 
            : ImageFormatGroup.bgra8888,
      );

      // Add error listener
      _cameraController!.addListener(() {
        if (_cameraController != null && _cameraController!.value.hasError) {
          if (mounted) {
            _showError('Camera error: ${_cameraController!.value.errorDescription}');
          }
        }
      });

      // Initialize with timeout and retry
      bool initialized = false;
      int retries = 0;
      
      while (!initialized && retries < 3) {
        try {
          await _cameraController!.initialize().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Camera initialization timed out');
            },
          );
          initialized = true;
        } catch (e) {
          retries++;
          if (retries >= 3) {
            rethrow;
          }
          // Short delay before retry
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (!mounted) return;

      // Configure camera settings
      try {
        await _cameraController!.setFlashMode(FlashMode.auto);
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        // Some devices might not support all modes, continue anyway
      }

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
        _showError('Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _captureImage() async {
    await Posthog().capture(
      eventName: 'user_captured_food',
    );
    
    // Check if user can scan
    final canScan = await _useFreeScan();
    if (!canScan) return;
    
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera is not initialized');
      // Try to reinitialize camera
      await _initializeCamera();
      return;
    }

    if (_cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Add a small delay to ensure camera is ready
      await Future.delayed(Duration(milliseconds: 200));
      
      XFile? photo;
      
      // Use a retry mechanism
      int retries = 0;
      while (retries < 3 && (photo == null)) {
        try {
          photo = await _cameraController!.takePicture().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Taking picture timed out');
            },
          );
        } catch (e) {
          retries++;
          if (retries >= 3) {
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      
      if (photo == null) {
        throw Exception('Failed to capture image after multiple attempts');
      }

      setState(() {
        _isProcessing = false;
        _imageFile = File(photo!.path);
      });
      
      // Show confirmation dialog before processing
      _showImageConfirmationDialog();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to capture image: $e');
      
      // Try to recover camera
      _recoverCamera();
    }
  }
  
  // New method to recover camera after errors
  Future<void> _recoverCamera() async {
    try {
      if (_isCameraInitialized && _cameraController != null) {
        await _cameraController!.dispose();
      }
      
      setState(() {
        _isCameraInitialized = false;
      });
      
      // Reinitialize after a short delay
      await Future.delayed(Duration(milliseconds: 1000));
      await _initializeCamera();
    } catch (e) {
      // If recovery fails, just log it
    }
  }

  Future<void> _pickImageFromGallery() async {
    // Check if user can scan
    await Posthog().capture(
      eventName: 'gallery_opened_food',
    );
    final canScan = await _useFreeScan();
    if (!canScan) return;
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
        
        // Show confirmation dialog before processing
        _showImageConfirmationDialog();
      }
    } catch (e) {
      // Show a more descriptive error to the user
      if (e.toString().contains('permission')) {
        _showError(
          'Permission denied. Please grant storage access in your device settings to use the gallery.',
          actionText: 'Settings',
          action: () async {
            // This requires the permission_handler package
            // await openAppSettings();
            // For now, just show more detailed instructions
            _showPermissionsDialog();
          },
        );
      } else {
        _showError('Failed to pick image: $e');
      }
    }
  }

  Future<void> _scanBarcode() async {
    _showComingSoonDialog('Barcode Scanning');
  }

  Future<void> _scanFoodLabel({bool skipDemoCheck = false}) async {
    // Always check if demo should be shown, unless explicitly skipped
    if (!skipDemoCheck) {
      // In development mode, always show the demo
      if (_isDevelopmentMode) {
        await _checkAndShowLabelScanDemo();
      } else {
        // In normal mode, check the count
        final prefs = await SharedPreferences.getInstance();
        final demoShowCount = prefs.getInt(_labelScanDemoCountKey) ?? 0;
        
        // Show demo if we haven't shown it 4 times yet
        if (demoShowCount < _maxLabelScanDemoShows) {
          await _checkAndShowLabelScanDemo();
        }
      }
    }
    
    // Check if user can scan
    final canScan = await _useFreeLabelScan();
    if (!canScan) return;
    
    try {
      await Posthog().capture(
        eventName: 'food_label_scan_started',
      );
      
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
        
        // Show confirmation dialog before processing
        _showImageConfirmationDialog();
      }
    } catch (e) {
      // Show a more descriptive error to the user
      if (e.toString().contains('permission')) {
        _showError(
          'Permission denied. Please grant camera access in your device settings to scan food labels.',
          actionText: 'Settings',
          action: () async {
            // This requires the permission_handler package
            // await openAppSettings();
            // For now, just show more detailed instructions
            _showPermissionsDialog();
          },
        );
      } else {
        _showError('Failed to capture image: $e');
      }
    }
  }

  Future<void> _processLabelImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
    });
    
    await Posthog().capture(
      eventName: 'food_label_scan_api_called',
    );
    
    try {
      // Use the new analyzeFoodLabel method instead of analyzeImage
      final nutritionInfo = await _gptService.analyzeFoodLabel(_imageFile!);

      // Add the image path to the additionalInfo
      nutritionInfo.additionalInfo['imagePath'] = _imageFile!.path;
      
      // Set default meal type
      nutritionInfo.additionalInfo['mealType'] = _selectedMeal;
      
      // Mark that this came from a label scan
      nutritionInfo.additionalInfo['sourceType'] = 'label_scan';

      if (mounted) {
        setState(() {
          _nutritionInfo = nutritionInfo;
          _isProcessing = false; // Ensure loading is dismissed on success
        });
        
        // Show the food details bottom sheet for label scan
        _showFoodDetailsBottomSheet(isLabelScan: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _imageFile = null; // Reset image file so user can try again
        });
        
        // Show a proper failure dialog for label scanning
        _showLabelAnalysisFailureDialog(e.toString());
      }
    }
  }
  
  // New method to show a failure dialog specifically for label scanning
  void _showLabelAnalysisFailureDialog(String errorMessage) {
    // Extract just the exception message without the "Exception: " prefix
    final cleanMessage = errorMessage.replaceAll('Exception: ', '');
    
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
            Text('Label Analysis Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cleanMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Tips for better label scanning:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 12),
            _buildTipItem('Make sure the nutrition facts label is clearly visible'),
            _buildTipItem('Ensure good lighting without glare or shadows'),
            _buildTipItem('Hold the camera steady and parallel to the label'),
            _buildTipItem('Include the entire nutrition facts panel in the photo'),
            _buildTipItem('Avoid wrinkled or curved packaging surfaces'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Coming Soon!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.engineering_outlined, size: 60, color: _primaryColor),
            SizedBox(height: 16),
            Text(
              '$feature will be available in a future update.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    if (!_isCameraInitialized || _cameraController == null) return;
    
    setState(() {
      _currentFlashIndex = (_currentFlashIndex + 1) % _flashModes.length;
      _cameraController!.setFlashMode(_flashModes[_currentFlashIndex]);
    });
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
    });
    
    await Posthog().capture(
      eventName: 'food_scan_api_called',
    );
    
    try {
      final nutritionInfo = await _gptService.analyzeImage(_imageFile!);

      // Add the image path to the additionalInfo
      nutritionInfo.additionalInfo['imagePath'] = _imageFile!.path;
      
      // Set default meal type
      nutritionInfo.additionalInfo['mealType'] = _selectedMeal;

      if (mounted) {
        setState(() {
          _nutritionInfo = nutritionInfo;
          _isProcessing = false; // Ensure loading is dismissed on success
        });
        
        // Skip food details dialog and directly add to log
        _addFoodToLog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _imageFile = null; // Reset image file so user can try again
        });
        
        // Show a proper failure dialog instead of a simple error message
        _showAnalysisFailureDialog(e.toString());
      }
    }
  }

  // New method to show a better failure dialog
  void _showAnalysisFailureDialog(String errorMessage) {
    // Extract just the exception message without the "Exception: " prefix
    final cleanMessage = errorMessage.replaceAll('Exception: ', '');
    
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
              cleanMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Tips for better scanning:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 12),
            _buildTipItem('Make sure food is centered in the frame'),
            _buildTipItem('Ensure good lighting without shadows'),
            _buildTipItem('Hold the camera steady to avoid blur'),
            _buildTipItem('Include the entire dish in the photo'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

  // Helper method to build tip items
  Widget _buildTipItem(String tip) {
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

  void _showScanningGuidelines() {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 500 ? 500.0 : screenWidth * 0.9;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.asset(
                    'assets/images/scanning_guidelines.png',
                    fit: BoxFit.cover,
                        height: 180,
                        width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _primaryColor.withOpacity(0.8),
                                _primaryColor.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                Icon(Icons.photo_camera,
                                    size: 40, color: Colors.white),
                                const SizedBox(height: 12),
                                Text(
                                  'Scanning Guidelines',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                      top: 12,
                      right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                          padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: _textColor,
                            size: 16,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
                  padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best scanning practices',
                    style: TextStyle(
                          fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                      const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade500,
                                  Colors.green.shade300,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                        ),
                              ],
                      ),
                            child: Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do',
                          style: TextStyle(
                                fontSize: 16,
                            fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade500,
                                  Colors.red.shade300,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                        ),
                              ],
                      ),
                            child: Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Don\'t',
                          style: TextStyle(
                                fontSize: 16,
                            fontWeight: FontWeight.bold,
                                color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                      const SizedBox(height: 20),
                  _buildGuidelineItem(
                        Icons.crop_free,
                        'Keep the food inside the scan lines',
                        Colors.green,
                      ),
                      _buildGuidelineItem(
                        Icons.stay_current_portrait,
                        'Hold your phone still so the image is not blurry',
                        Colors.green,
                      ),
                      _buildGuidelineItem(
                        Icons.landscape,
                        'Don\'t take the picture at obscure angles',
                        Colors.red,
                      ),
                      const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: _primaryColor.withOpacity(0.4),
                          ),
                          child: Text(
                            'Scan now',
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
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Call this to show the bottom sheet with camera options
  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 48,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryColor.withOpacity(0.8),
                          _primaryColor.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image Options',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        'Choose a scanning method',
                        style: TextStyle(
                          fontSize: 14,
                          color: _lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButtonModern(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  _buildOptionButtonModern(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    color: Color(0xFF2196F3),
                    onTap: () {
                      Navigator.pop(context);
                      _scanBarcode();
                    },
                  ),
                  _buildOptionButtonModern(
                    icon: Icons.receipt,
                    label: 'Food Label',
                    color: Color(0xFFFF9800),
                    onTap: () async {
                      Navigator.pop(context);
                      
                      // In development mode, always show the demo
                      if (_isDevelopmentMode) {
                        await _showLabelScanDemo();
                        _scanFoodLabel(skipDemoCheck: true);
                        return;
                      }
                      
                      // Get the current demo count
                      final prefs = await SharedPreferences.getInstance();
                      final demoShowCount = prefs.getInt(_labelScanDemoCountKey) ?? 0;
                      
                      // Show demo if we haven't shown it 4 times yet
                      if (demoShowCount < _maxLabelScanDemoShows) {
                        // Show the demo first, then scan when demo is closed
                        await _showLabelScanDemo();
                        
                        // Now start the scan after demo is closed, skip demo check since we just showed it
                        _scanFoodLabel(skipDemoCheck: true);
                      } else {
                        // If demo was already shown the max number of times, just scan
                        _scanFoodLabel();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButtonModern({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: color.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.8),
                      color.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              child: Icon(
                icon,
                  color: Colors.white,
                  size: 32,
              ),
            ),
          ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Show the food details bottom sheet
  void _showFoodDetailsBottomSheet({bool isLabelScan = false}) {
    if (_nutritionInfo == null) return;

    final NutritionInfo nutritionInfo = _nutritionInfo!;
    // Create a local meal selection variable for the bottom sheet
    String selectedMealLocal = _selectedMeal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85, // Reduced from 0.9
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4), // Reduced padding
                  child: Container(
                    width: 40,
                    height: 4, // Thinner handle
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Header - more compact
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
                  decoration: BoxDecoration(
                    color: _cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8), // Smaller icon container
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _primaryColor.withOpacity(0.8),
                                  _primaryColor.withOpacity(0.6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isLabelScan ? Icons.receipt : Icons.restaurant,
                              color: Colors.white,
                              size: 16, // Smaller icon
                            ),
                          ),
                          const SizedBox(width: 8), // Reduced spacing
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLabelScan ? 'Nutrition Label' : 'Food Details',
                                style: TextStyle(
                                  fontSize: 18, // Smaller title
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                              Text(
                                isLabelScan ? 'Label Analysis' : 'AI Nutrition Analysis',
                                style: TextStyle(
                                  fontSize: 12, // Smaller subtext
                                  color: _lightTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero, // Remove padding
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40), // Smaller touch target
                        icon: Container(
                          padding: const EdgeInsets.all(6), // Smaller close button
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: _textColor, size: 16), // Smaller icon
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food Image with nutritional info overlay
                        if (_imageFile != null)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 180, // Reduced height
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 16), // Less margin
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16), // Smaller radius
                                  image: DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 32, // Adjusted position
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.orange.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.white,
                                        size: 14, // Smaller icon
                                      ),
                                      const SizedBox(width: 4), // Less spacing
                                      Text(
                                        "${nutritionInfo.calories.toStringAsFixed(0)} kcal",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14, // Smaller text
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isLabelScan)
                                Positioned(
                                  right: 16,
                                  top: 32, // Adjusted position
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade600,
                                          Colors.blue.shade400,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.receipt_outlined,
                                          color: Colors.white,
                                          size: 14, // Smaller icon
                                        ),
                                        const SizedBox(width: 4), // Less spacing
                                        Text(
                                          "Label Scan",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14, // Smaller text
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                        const SizedBox(height: 20), // Less spacing

                        // Food Name and Brand
                        Hero(
                          tag: 'food_name_${DateTime.now().toString()}',
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nutritionInfo.foodName,
                                  style: TextStyle(
                                    fontSize: 24, // Smaller title
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                if (nutritionInfo.brandName.isNotEmpty) ...[
                                  const SizedBox(height: 4), // Less spacing
                                  Text(
                                    nutritionInfo.brandName,
                                    style: TextStyle(
                                      fontSize: 16, // Smaller text
                                      color: _lightTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20), // Less spacing

                        // Serving size information for label scans
                        if (isLabelScan && nutritionInfo.servingSize.isNotEmpty && nutritionInfo.servingSize != '100g')
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Serving Size: ${nutritionInfo.servingSize}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Nutritional information cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutritionCard(
                                'Protein',
                                '${nutritionInfo.protein.toStringAsFixed(1)}g',
                                Color(0xFFE91E63),
                                Icons.fitness_center,
                              ),
                            ),
                            Expanded(
                              child: _buildNutritionCard(
                                'Carbs',
                                '${nutritionInfo.carbs.toStringAsFixed(1)}g',
                                Color(0xFFFF9800),
                                Icons.grain,
                              ),
                            ),
                            Expanded(
                              child: _buildNutritionCard(
                                'Fat',
                                '${nutritionInfo.fat.toStringAsFixed(1)}g',
                                Color(0xFF2196F3),
                                Icons.water_drop,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20), // Less spacing

                        // Additional Nutrition Information for label scans
                        if (isLabelScan) ...[
                          _buildSectionTitle('Detailed Nutrition'),
                          Container(
                            margin: const EdgeInsets.only(top: 12), // Less margin
                            padding: const EdgeInsets.all(16), // Less padding
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16), // Smaller radius
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (nutritionInfo.additionalInfo['dietaryFiber'] != null)
                                  _buildNutritionRow('Dietary Fiber', 
                                    '${nutritionInfo.additionalInfo['dietaryFiber']} g'),
                                if (nutritionInfo.additionalInfo['sugars'] != null)
                                  _buildNutritionRow('Sugars', 
                                    '${nutritionInfo.additionalInfo['sugars']} g'),
                                if (nutritionInfo.additionalInfo['saturatedFat'] != null)
                                  _buildNutritionRow('Saturated Fat', 
                                    '${nutritionInfo.additionalInfo['saturatedFat']} g'),
                                if (nutritionInfo.additionalInfo['cholesterol'] != null)
                                  _buildNutritionRow('Cholesterol', 
                                    '${nutritionInfo.additionalInfo['cholesterol']} mg'),
                                if (nutritionInfo.additionalInfo['sodium'] != null)
                                  _buildNutritionRow('Sodium', 
                                    '${nutritionInfo.additionalInfo['sodium']} mg'),
                                if (nutritionInfo.additionalInfo['calcium'] != null)
                                  _buildNutritionRow('Calcium', 
                                    '${nutritionInfo.additionalInfo['calcium']}'),
                                if (nutritionInfo.additionalInfo['iron'] != null)
                                  _buildNutritionRow('Iron', 
                                    '${nutritionInfo.additionalInfo['iron']}'),
                                if (nutritionInfo.additionalInfo['vitaminA'] != null)
                                  _buildNutritionRow('Vitamin A', 
                                    '${nutritionInfo.additionalInfo['vitaminA']}'),
                                if (nutritionInfo.additionalInfo['vitaminC'] != null)
                                  _buildNutritionRow('Vitamin C', 
                                    '${nutritionInfo.additionalInfo['vitaminC']}'),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20), // Less spacing

                        // Additional Information Section
                        _buildSectionTitle('Additional Information'),
                        Container(
                          margin: const EdgeInsets.only(top: 12), // Less margin
                          padding: const EdgeInsets.all(16), // Less padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16), // Smaller radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (!isLabelScan) ...[
                                _buildInfoRow('Cuisine Type',
                                    nutritionInfo.additionalInfo['cuisineType']),
                                _buildInfoRow(
                                    'Preparation',
                                    nutritionInfo
                                        .additionalInfo['preparationMethod']),
                                _buildInfoRow('Health Benefits',
                                    nutritionInfo.additionalInfo['healthBenefits']),
                              ],
                              _buildInfoRow('Allergens',
                                  nutritionInfo.additionalInfo['allergens']),
                              if (!isLabelScan) ...[
                                _buildInfoRow('Storage',
                                    nutritionInfo.additionalInfo['storage']),
                                _buildInfoRow('Shelf Life',
                                    nutritionInfo.additionalInfo['shelfLife']),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20), // Less spacing

                        // Ingredients Section
                        _buildSectionTitle('Ingredients'),
                        Container(
                          margin: const EdgeInsets.only(top: 12), // Less margin
                          padding: const EdgeInsets.all(16), // Less padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16), // Smaller radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: nutritionInfo.ingredients.isEmpty
                              ? [
                                  Text(
                                    'No ingredients information available',
                                    style: TextStyle(
                                      color: _lightTextColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                ]
                              : nutritionInfo.ingredients
                                  .map((ingredient) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6), // Less padding
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 6, // Smaller dot
                                          height: 6, // Smaller dot
                                          decoration: BoxDecoration(
                                            color: _primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10), // Less spacing
                                        Expanded(
                                          child: Text(
                                            ingredient,
                                            style: TextStyle(
                                              color: _textColor,
                                              height: 1.4,
                                              fontSize: 14, // Smaller text
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                                  .toList(),
                          ),
                        ),

                        const SizedBox(height: 20), // Less spacing

                        // Meal Selection Section
                        _buildSectionTitle('Add to Meal'),
                        Container(
                          margin: const EdgeInsets.only(top: 12), // Less margin
                          height: 48, // Reduced height
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Other']
                                .map(
                                  (meal) => GestureDetector(
                                    onTap: () {
                                      // Update the local state in the bottom sheet
                                      setModalState(() {
                                        selectedMealLocal = meal;
                                        
                                        // Also update the parent state and nutrition info
                                        setState(() {
                                          _selectedMeal = meal;
                                          
                                          // Update additionalInfo with selected meal type
                                          if (_nutritionInfo != null) {
                                            _nutritionInfo!.additionalInfo['mealType'] = meal;
                                          }
                                        });
                                      });
                                      
                                      // Show confirmation
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Selected: $meal'),
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: _primaryColor,
                                        ),
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(right: 12), // Less margin
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ), // Less padding
                                      decoration: BoxDecoration(
                                        color: selectedMealLocal == meal
                                            ? _primaryColor
                                            : Colors.grey.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: selectedMealLocal == meal
                                            ? [
                                                BoxShadow(
                                                  color: _primaryColor
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          meal,
                                          style: TextStyle(
                                            color: selectedMealLocal == meal
                                                ? Colors.white
                                                : _textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14, // Smaller text
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 20), // Less spacing

                        // Add to Meal Button
                        SizedBox(
                          width: double.infinity,
                          height: 50, // Shorter button
                          child: ElevatedButton(
                            onPressed: () {
                              // Update _selectedMeal before closing
                              setState(() {
                                _selectedMeal = selectedMealLocal;
                              });
                              Navigator.pop(context); // Close bottom sheet
                              _addFoodToLog(); // Use our new method
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12), // Less padding
                              elevation: 4, // Less elevation
                              shadowColor: _primaryColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16), // Smaller radius
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, size: 20), // Smaller icon
                                const SizedBox(width: 8), // Less spacing
                                const Text(
                                  'Add to Meal',
                                  style: TextStyle(
                                    fontSize: 16, // Smaller text
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24), // Bottom padding for safe area
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
      title,
      style: TextStyle(
            fontSize: 22,
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final displayValue = (value == null || value.toString().isEmpty)
        ? 'Not specified'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textColor,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: _lightTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
        color: color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.7),
                  color.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message, {String? actionText, VoidCallback? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: actionText != null && action != null
            ? SnackBarAction(
                label: actionText,
                textColor: Colors.white,
                onPressed: () => action!(),
              )
            : null,
      ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Storage Access Required',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: _primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'To pick images from your gallery, please follow these steps:\n\n'
              '1. Open your device Settings\n'
              '2. Go to Apps or Application Manager\n'
              '3. Find this app\n'
              '4. Tap Permissions\n'
              '5. Enable Storage permission',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format the selected date for display using the helper method
    final String dateText = _getFormattedDate(_effectiveDate);
   
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true, // Center the title widget
        title: !_isPremium && !_isDevelopmentMode 
          ? Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${_maxFreeScans - _remainingFreeScans}/$_maxFreeScans',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : null, // Don't show anything in development mode or premium
        actions: [
          // Flash mode button
          if (_isCameraInitialized && _cameraController != null)
            IconButton(
              icon: Icon(
                _flashModes[_currentFlashIndex] == FlashMode.off
                    ? Icons.flash_off
                    : _flashModes[_currentFlashIndex] == FlashMode.auto
                        ? Icons.flash_auto
                        : Icons.flash_on,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _toggleFlash,
            ),
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
            onPressed: _showScanningGuidelines,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview - better fixed size approach
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.width * _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Top black bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              height: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
          ),

          // Simplified positioning UI - just edge indicators
          if (_isCameraInitialized && !_isProcessing)
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate scan frame size based on screen size
                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;
                  
                  // Make the frame a square with fixed size ratio of the screen width
                  final frameSize = screenWidth * 0.75;
                  
                  return Container(
                    width: frameSize,
                    height: frameSize,
                    child: Stack(
                      children: [
                        // Top left corner
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _buildCorner(true, true),
                        ),
                        // Top right corner
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _buildCorner(true, false),
                        ),
                        // Bottom left corner
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: _buildCorner(false, true),
                        ),
                        // Bottom right corner
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _buildCorner(false, false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Bottom controls - replaced with solid black bar
          if (_isCameraInitialized && !_isProcessing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black,
                // Remove fixed height and let content determine height
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 16,
                  left: 24,
                  right: 24,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Ensure the column takes minimum required space
                    children: [
                      // Toggle options for scan modes
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildScanModeToggle(
                              mode: ScanMode.food, 
                              icon: Icons.restaurant, 
                              label: 'Food'
                            ),
                            _buildScanModeToggle(
                              mode: ScanMode.label, 
                              icon: Icons.receipt_outlined, 
                              label: 'Label'
                            ),
                            _buildScanModeToggle(
                              mode: ScanMode.gallery, 
                              icon: Icons.photo_library, 
                              label: 'Gallery'
                            ),
                          ],
                        ),
                      ),
                      
                      // Capture button
                      GestureDetector(
                        onTap: _handleCapture,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryColor.withOpacity(0.8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _selectedScanMode == ScanMode.gallery 
                                    ? Icons.photo_library
                                    : _selectedScanMode == ScanMode.label
                                        ? Icons.receipt_outlined
                                        : Icons.camera_alt,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Processing overlay with rotating messages
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Modern animated loader
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsating background
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(seconds: 2),
                                builder: (context, value, child) {
                                  return Container(
                                    width: 80 + (value * 10),
                                    height: 80 + (value * 10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _primaryColor.withOpacity(0.1 * (1 - value)),
                                    ),
                                  );
                                },
                                child: Container(),
                              ),
                              
                              // Rotating outer circle
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 2 * pi),
                                duration: Duration(seconds: 3),
                                builder: (context, value, child) {
                                  return Transform.rotate(
                                    angle: value,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      child: CircularProgressIndicator(
                                        color: _primaryColor,
                                        strokeWidth: 3,
                                        value: null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              // Inner circle with icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryColor.withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _selectedScanMode == ScanMode.label
                                    ? Icon(
                                        Icons.receipt_outlined,
                                        color: _primaryColor,
                                        size: 28,
                                      )
                                    : Icon(
                                        Icons.restaurant,
                                        color: _primaryColor,
                                        size: 28,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Modern text display with typewriter effect
                        StreamBuilder<String>(
                          stream: Stream.periodic(const Duration(seconds: 3), (count) {
                            final messages = _selectedScanMode == ScanMode.label
                              ? [
                                  'Analyzing nutrition label...',
                                  'Extracting nutritional data...',
                                  'Processing ingredients list...',
                                  'Calculating serving sizes...',
                                  'Almost complete...',
                                ]
                              : [
                                  'Analyzing your food...',
                                  'Identifying ingredients...',
                                  'Calculating nutrition facts...',
                                  'Processing calorie data...',
                                  'Almost complete...',
                                ];
                            return messages[count % messages.length];
                          }),
                          initialData: _selectedScanMode == ScanMode.label
                              ? 'Analyzing nutrition label...'
                              : 'Analyzing your food...',
                          builder: (context, snapshot) {
                            return Column(
                              children: [
                                Text(
                                  snapshot.data!,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Animated dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) {
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(milliseconds: 600),
                                      curve: Curves.easeInOut,
                                      builder: (context, value, child) {
                                        return Container(
                                          margin: EdgeInsets.symmetric(horizontal: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _primaryColor.withOpacity(
                                              (index == 0 && value < 0.5) ||
                                              (index == 1 && (value >= 0.3 && value < 0.8)) ||
                                              (index == 2 && value >= 0.6)
                                                  ? 1.0
                                                  : 0.3,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build corner indicators for positioning
  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          // Horizontal line
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            child: Container(
              width: 30,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          // Vertical line
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            child: Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Circle button for camera controls
  Widget _buildCircleIconButton(
    IconData icon, VoidCallback onPressed, String label, bool isActive) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? Colors.white : AppColors.textSecondary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFoodToLog() async {
    if (_nutritionInfo == null) return;

    // Don't set _isProcessing to true again here, as it's already handled in the processing methods
    // and we want to avoid showing the loading dialog twice

    try {
      // Validate the date for logging
      final validatedDate = AppDateUtils.validateDate(_effectiveDate);
      
      // Format for display
      final String dateText = _getFormattedDate(validatedDate);

      // Add timestamp to additionalInfo
      _nutritionInfo!.additionalInfo['timestamp'] = DateTime.now().toIso8601String();
      
      // Make sure meal type is set
      if (!_nutritionInfo!.additionalInfo.containsKey('mealType')) {
        _nutritionInfo!.additionalInfo['mealType'] = _selectedMeal;
      }
      
      // Add the food with the validated date using FoodHiveService
      await FoodHiveService.addFood(
        _nutritionInfo!,
        logDate: validatedDate // Use validated date
      );
      
      // Ensure processing is stopped
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_nutritionInfo!.foodName} quickly analyzed and added to your log!',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Call the callback function if provided
      if (widget.onFoodLogged != null) {
        widget.onFoodLogged!();
      }

      // Add a short delay to ensure data is saved and user sees the success message
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Return to previous screen with success result
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error adding food: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  // Load remaining free scan count from shared preferences
  Future<void> _loadScanCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _remainingFreeScans = prefs.getInt(_freeScanCountKey) ?? _maxFreeScans;
      });
    } catch (e) {
      // If there's an error, default to max free scans
      setState(() {
        _remainingFreeScans = _maxFreeScans;
      });
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
  
  // Decrement free scan count
  Future<bool> _useFreeScan() async {
    // Skip the check if user is premium or in development mode
    if (_isPremium || _isDevelopmentMode) return true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_freeScanCountKey) ?? _maxFreeScans;
      
      // If no free scans left, show special offer dialog immediately
      if (currentCount <= 0) {
        if (mounted) {
          showSpecialOfferDialog(
            context,
            feature: Feature.scanFood,
            title: 'Upgrade to Premium',
            subtitle: 'You\'ve used all your free scans. Upgrade to Premium for unlimited food scanning and premium features!',
            forceShow: true, // Force show the dialog
          );
        }
        return false;
      }
      
      // Decrement count
      currentCount--;
      await prefs.setInt(_freeScanCountKey, currentCount);
      
      if (mounted) {
        setState(() {
          _remainingFreeScans = currentCount;
        });
      }
      
      // If this was the last scan, show special offer dialog but still allow scan
      if (currentCount == 0 && mounted) {
        // Delay showing dialog until after scan is complete
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            showSpecialOfferDialog(
              context,
              feature: Feature.scanFood,
              title: 'Last Scan Used',
              subtitle: 'You\'ve used all your free scans. Upgrade to Premium for unlimited scanning!',
              forceShow: true, // Force show the dialog
            );
          }
        });
      }
      
      return true;
    } catch (e) {
      // In case of error, allow the scan but don't modify counter
      return true;
    }
  }

  // Decrement free label scan count - now uses the same counter as regular scans
  Future<bool> _useFreeLabelScan() async {
    // Just use the regular scan check since we're using a combined limit
    return _useFreeScan();
  }

  // New method to check and show label scan demo for first-time users
  Future<void> _checkAndShowLabelScanDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the current demo show count (default to 0 if not set)
      final demoShowCount = prefs.getInt(_labelScanDemoCountKey) ?? 0;
      
      // In development mode, always show the demo
      // In normal mode, show it for the first 4 times
      if (_isDevelopmentMode || (demoShowCount < _maxLabelScanDemoShows && mounted)) {
        // Show the demo directly and wait for it to complete
        await _showLabelScanDemo();

        // In non-development mode, increment and save the count
        if (!_isDevelopmentMode) {
          final newCount = demoShowCount + 1;
          await prefs.setInt(_labelScanDemoCountKey, newCount);
          
          // If this was the 4th time, also set the "shown" flag to true for backward compatibility
          if (newCount >= _maxLabelScanDemoShows) {
            await prefs.setBool(_labelScanDemoShownKey, true);
          }
        }
      }
    } catch (e) {
      // Ignore errors, demo is not critical
    }
  }
  
  // New method to show label scan demo
  Future<void> _showLabelScanDemo() async {
    final completer = Completer<void>();
    
    // Get the current demo count to display
    final prefs = await SharedPreferences.getInstance();
    final currentDemoCount = prefs.getInt(_labelScanDemoCountKey) ?? 0;
    final demoNumber = _isDevelopmentMode ? 0 : currentDemoCount + 1;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.asset(
                        'assets/images/food_scan_demo.jpg',
                        fit: BoxFit.cover,
                        height: 160, // Reduced height
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 160, // Reduced height
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.receipt_outlined,
                              color: Colors.white,
                              size: 48, // Reduced size
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -16, // Adjusted position
                      child: Container(
                        padding: EdgeInsets.all(6), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.new_releases,
                          color: Colors.white,
                          size: 20, // Reduced size
                        ),
                      ),
                    ),
                    if (!_isDevelopmentMode && demoNumber > 0 && demoNumber <= _maxLabelScanDemoShows)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            'Tip $demoNumber/$_maxLabelScanDemoShows',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11, // Reduced font size
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // Reduced padding
                  child: Column(
                    children: [
                      Text(
                        demoNumber == 1 
                            ? 'New Feature: Label Scanner'
                            : demoNumber == 2
                                ? 'Tip: Hold Camera Steady'
                                : demoNumber == 3
                                    ? 'Tip: Ensure Good Lighting'
                                    : demoNumber == 4
                                        ? 'Tip: Capture Full Label'
                                        : 'New Feature: Label Scanner',
                        style: TextStyle(
                          fontSize: 18, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      if (_isDevelopmentMode)
                        Container(
                          margin: EdgeInsets.only(top: 6), // Reduced margin
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.developer_mode,
                                color: Colors.green.shade700,
                                size: 14, // Reduced size
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Development Mode',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12, // Reduced font size
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 12), // Reduced spacing
                      Text(
                        demoNumber == 1 
                            ? 'Scan nutrition labels for instant detailed information'
                            : demoNumber == 2
                                ? 'Hold phone steady and parallel to label'
                                : demoNumber == 3
                                    ? 'Ensure good lighting, avoid glare'
                                    : demoNumber == 4
                                        ? 'Capture entire label in one photo'
                                        : 'Scan nutrition labels for instant detailed information',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, // Reduced font size
                          color: _lightTextColor,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 16), // Reduced spacing
                      Column(
                        children: [
                          _buildDemoStep(
                            1, 
                            'Position', 
                            'Center the nutrition label in frame'
                          ),
                          SizedBox(height: 8), // Reduced spacing
                          _buildDemoStep(
                            2, 
                            'Capture', 
                            'Hold steady with good lighting'
                          ),
                          SizedBox(height: 8), // Reduced spacing
                          _buildDemoStep(
                            3, 
                            'Review', 
                            'Get detailed nutrition data'
                          ),
                        ],
                      ),
                      SizedBox(height: 16), // Reduced spacing
                      Text(
                        _isDevelopmentMode
                            ? 'Unlimited scans in dev mode'
                            : '${_maxFreeScans} free scans available',
                        style: TextStyle(
                          fontSize: 14, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: _isDevelopmentMode ? Colors.green.shade700 : Colors.blue.shade700,
                        ),
                      ),
                      if (!_isDevelopmentMode)
                        Text(
                          '(Shared limit with food scans)',
                          style: TextStyle(
                            fontSize: 11, // Reduced font size
                            color: _lightTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      SizedBox(height: 16), // Reduced spacing
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            completer.complete();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12), // Reduced padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _isDevelopmentMode 
                                ? 'Got it!'
                                : demoNumber < _maxLabelScanDemoShows 
                                    ? 'Next ($demoNumber/$_maxLabelScanDemoShows)'
                                    : 'Start Scanning',
                            style: TextStyle(
                              fontSize: 14, // Reduced font size
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
        ),
      ),
    );
    
    return completer.future;
  }
  
  // Helper method to build demo steps with reduced sizes
  Widget _buildDemoStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, // Reduced size
          height: 24, // Reduced size
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12, // Reduced font size
              ),
            ),
          ),
        ),
        SizedBox(width: 12), // Reduced spacing
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Reduced font size
                  color: _textColor,
                ),
              ),
              SizedBox(height: 2), // Reduced spacing
              Text(
                description,
                style: TextStyle(
                  fontSize: 12, // Reduced font size
                  color: _lightTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build nutrition rows for label scan data
  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _textColor,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Build toggle button for scan mode selection
  Widget _buildScanModeToggle({
    required ScanMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedScanMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          // If switching to label mode, check if we need to show demo
          if (mode == ScanMode.label && _selectedScanMode != ScanMode.label) {
            await _checkAndShowLabelScanDemo();
          }
          setState(() {
            _selectedScanMode = mode;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          margin: EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isSelected ? 20 : 16,
              ),
              SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSelected ? 12 : 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle capture based on selected mode
  void _handleCapture() async {
    switch (_selectedScanMode) {
      case ScanMode.food:
        await _captureImage();
        break;
      case ScanMode.label:
        // Remove demo check from here, just capture
        await _captureImage();
        break;
      case ScanMode.gallery:
        await _pickImageFromGallery();
        break;
    }
  }

  // Show confirmation dialog with the selected image
  void _showImageConfirmationDialog() {
    if (_imageFile == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                height: 300,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _selectedScanMode == ScanMode.label 
                        ? 'Confirm Food Label Image'
                        : 'Confirm Food Image',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _selectedScanMode == ScanMode.label
                        ? 'Is the nutrition label clearly visible?'
                        : 'Is the food clearly visible in the image?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _lightTextColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _imageFile = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textColor,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Retake'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _isProcessing = true;
                            });
                            // Process the image based on the selected scan mode
                            if (_selectedScanMode == ScanMode.label) {
                              _processLabelImage();
                            } else {
                              _processImage();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text('Analyze'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
