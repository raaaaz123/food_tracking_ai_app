import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/exercise.dart';
import '../services/exercise_hive_service.dart';
import '../services/gpt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/main_app_screen.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/subscription_handler.dart';
import '../widgets/special_offer_dialog.dart';

// Constants for free analysis limit
const String _freeExerciseAnalysisCountKey = 'free_exercise_analysis_count';
const int _maxFreeAnalysis = 2;

class CustomExerciseScreen extends StatefulWidget {
  const CustomExerciseScreen({super.key});

  @override
  State<CustomExerciseScreen> createState() => _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends State<CustomExerciseScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _canSubmit = false;
  bool _isAnalyzing = false;
  String? _analysisError;
  Map<String, dynamic>? _exerciseAnalysis;
  
  // Add free analysis count tracking
  int _remainingFreeAnalysis = _maxFreeAnalysis;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_validateInput);
    _nameController.addListener(_validateInput);
    Posthog().screen(
      screenName: 'Custom Exercise Screen',
    );
    
    // Load remaining free analysis count and premium status
    _loadAnalysisCount();
    _checkPremiumStatus();
  }
  
  // Load remaining free analysis count from shared preferences
  Future<void> _loadAnalysisCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _remainingFreeAnalysis = prefs.getInt(_freeExerciseAnalysisCountKey) ?? _maxFreeAnalysis;
      });
    } catch (e) {
      // If there's an error, default to max free scans
      setState(() {
        _remainingFreeAnalysis = _maxFreeAnalysis;
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
      setState(() {
        _isPremium = false;
      });
    }
  }
  
  // Decrement free analysis count
  Future<bool> _useFreeAnalysis() async {
    // Skip the check if user is premium
    if (_isPremium) return true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_freeExerciseAnalysisCountKey) ?? _maxFreeAnalysis;
      
      // If no free analyses left, show special offer dialog immediately
      if (currentCount <= 0) {
        if (mounted) {
          showSpecialOfferDialog(
            context,
            feature: Feature.exerciseLogging,
            title: 'Upgrade to Premium',
            subtitle: 'You\'ve used all your free exercise analyses. Upgrade to Premium for unlimited exercise analysis and premium features!',
            forceShow: true, // Force show the dialog
          );
        }
        return false;
      }
      
      // Decrement count
      currentCount--;
      await prefs.setInt(_freeExerciseAnalysisCountKey, currentCount);
      
      if (mounted) {
        setState(() {
          _remainingFreeAnalysis = currentCount;
        });
      }
      
      // If this was the last analysis, show special offer dialog but still allow analysis
      if (currentCount == 0 && mounted) {
        // Delay showing dialog until after analysis is complete
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            showSpecialOfferDialog(
              context,
              feature: Feature.exerciseLogging,
              title: 'Last Analysis Used',
              subtitle: 'You\'ve used all your free exercise analyses. Upgrade to Premium for unlimited access!',
              forceShow: true, // Force show the dialog
            );
          }
        });
      }
      
      return true;
    } catch (e) {
      // In case of error, allow the analysis but don't modify counter
      return true;
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_validateInput);
    _descriptionController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final description = _descriptionController.text.trim();
    final name = _nameController.text.trim();
    setState(() {
      _canSubmit = description.length >= 5 && name.isNotEmpty;
    });
  }

  Future<void> _analyzeExercise() async {
    if (_isAnalyzing) return;
    
    // Check if user can analyze exercise
    final canAnalyze = await _useFreeAnalysis();
    if (!canAnalyze) return;

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _exerciseAnalysis = null;
    });

    try {
      final gptService = GPTService();
      final analysis = await gptService.analyzeExercise(_descriptionController.text);
      final parsedAnalysis = GPTService.parseGPTResponse(analysis);

      setState(() {
        _exerciseAnalysis = parsedAnalysis;
      });
      
      // Show analysis results in bottom sheet
      if (mounted) {
        _showAnalysisBottomSheet(parsedAnalysis);
      }
      
    } catch (e) {
      // Don't store the actual error message in state
      setState(() {
        _analysisError = 'error';
      });
      
      // Show user-friendly error dialog
      if (mounted) {
        _showErrorDialog();
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveExercise() async {
    if (_isLoading || !_canSubmit || _exerciseAnalysis == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user's weight (default to 70kg if not available)
      final prefs = await SharedPreferences.getInstance();
      final userWeight = prefs.getDouble('user_weight') ?? 70.0;

      // Create exercise type from description
      final exerciseType = ExerciseType(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        icon: Icons.fitness_center,
        isCustom: true,
      );

      // Convert values to correct types
      final intensity = _exerciseAnalysis!['intensity'] as IntensityLevel;
      final duration = (_exerciseAnalysis!['duration'] as num).toInt();
      final calories = (_exerciseAnalysis!['calories'] as num).round();
      final protein = (_exerciseAnalysis!['protein'] as num).toDouble();
      final carbs = (_exerciseAnalysis!['carbs'] as num).toDouble();
      final fat = (_exerciseAnalysis!['fat'] as num).toDouble();
      final notes = _exerciseAnalysis!['notes'] as String;

      // Create new exercise with analysis data
      final exercise = Exercise(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: exerciseType,
        intensity: intensity,
        durationMinutes: duration,
        date: DateTime.now(),
        caloriesBurned: calories,
        notes: notes,
        proteinBurned: protein,
        carbsBurned: carbs,
        fatBurned: fat,
      );

      // Save exercise using ExerciseHiveService
      await ExerciseHiveService.addExercise(exercise);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom workout added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to MainAppScreen instead of just popping
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainAppScreen()),
          (route) => false,
        );
      }
    } catch (e) {
    
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add exercise: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.cardBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Custom Exercise',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isPremium) _buildFreeAIUsedCard(),
              SizedBox(height: 16),
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildInputSection(),
              const SizedBox(height: 24),
              if (_isAnalyzing) _buildAnalyzingIndicator(),
              if (_analysisError != null) _buildErrorSection(),
              if (_exerciseAnalysis != null) _buildAnalysisSection(),
              const SizedBox(height: 24),
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeAIUsedCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.insights,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Text(
            '${_maxFreeAnalysis - _remainingFreeAnalysis}/${_maxFreeAnalysis} Free AI Analysis Used',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: Duration(milliseconds: 500))
      .slideY(begin: 0.1, end: 0, duration: Duration(milliseconds: 400));
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7BC27D),  // Medium green
            Color(0xFFB8E0C0),  // Light green 
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF7BC27D).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Animated fitness icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: Colors.white,
                  size: 26,
                ),
              ).animate()
                .fadeIn(duration: Duration(milliseconds: 500))
                .scale(delay: Duration(milliseconds: 200)),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Custom Workout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get AI-powered analysis instantly',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Added benefits section with increased spacing
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 4),
            child: Wrap(
              spacing: 24, // Increased spacing between chips
              runSpacing: 12, // Added spacing between rows if chips wrap
              children: [
                _buildBenefitChip(Icons.bolt_outlined, 'AI Analysis'),
                _buildBenefitChip(Icons.local_fire_department_outlined, 'Calories'),
                _buildBenefitChip(Icons.restaurant_outlined, 'Nutrients'),
              ],
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: Duration(milliseconds: 600))
      .slideY(begin: 0.1, end: 0, duration: Duration(milliseconds: 500), curve: Curves.easeOutQuad);
  }
  
  // Small chips for benefits
  Widget _buildBenefitChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: 400))
      .scale(delay: Duration(milliseconds: 400), begin: Offset(0.8, 0.8), duration: Duration(milliseconds: 300));
  }

  Widget _buildInputSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with animated element
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF7BC27D),
                      Color(0xFFB8E0C0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF7BC27D).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_note,
                  color: Colors.white,
                  size: 22,
                ),
              ).animate()
                .fadeIn(duration: Duration(milliseconds: 500))
                .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1), duration: Duration(milliseconds: 300)),
              
              const SizedBox(width: 12),
              
              Text(
                'Exercise Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Exercise name field with floating label
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Exercise Name',
                hintText: 'e.g., Morning Yoga Routine',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                prefixIcon: Icon(Icons.fitness_center_outlined, color: Color(0xFF7BC27D), size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFF7BC27D), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                labelStyle: TextStyle(color: Colors.grey.shade600),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Exercise description field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 5,
              style: TextStyle(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Exercise Description',
                hintText: 'Describe your workout in detail (e.g., 30 min HIIT with jumping jacks, push-ups, and lunges, moderate intensity)',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.description_outlined, color: Color(0xFF7BC27D), size: 20),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFF7BC27D), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                labelStyle: TextStyle(color: Colors.grey.shade600),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Analyze button with animation and gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _canSubmit ? [
                BoxShadow(
                  color: Color(0xFF7BC27D).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ] : [],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _analyzeExercise : null,
                icon: Icon(Icons.bolt, size: 20),
                label: Text(
                  _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  // Add gradient if button is enabled
                  backgroundColor: _canSubmit ? Color(0xFF7BC27D) : Colors.grey.shade300,
                ),
              ),
            ),
          ).animate(target: _canSubmit ? 1 : 0)
            .scale(begin: Offset(1, 1), end: Offset(1.03, 1.03))
            .then(duration: Duration(milliseconds: 200)),
        ],
      ),
    ).animate()
      .fadeIn(duration: Duration(milliseconds: 700), delay: Duration(milliseconds: 200))
      .slideY(begin: 0.1, end: 0, duration: Duration(milliseconds: 500), curve: Curves.easeOutQuad);
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Analyzing exercise...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppColors.error.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _analysisError!,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Exercise Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalysisRow('Intensity', _exerciseAnalysis!['intensity'].toString()),
          _buildAnalysisRow('Duration', '${_exerciseAnalysis!['duration']} minutes'),
          _buildAnalysisRow('Calories', '${_exerciseAnalysis!['calories'].toStringAsFixed(1)} kcal'),
          _buildAnalysisRow('Protein', '${_exerciseAnalysis!['protein'].toStringAsFixed(1)}g'),
          _buildAnalysisRow('Carbs', '${_exerciseAnalysis!['carbs'].toStringAsFixed(1)}g'),
          _buildAnalysisRow('Fat', '${_exerciseAnalysis!['fat'].toStringAsFixed(1)}g'),
          if (_exerciseAnalysis!['notes'] != null && _exerciseAnalysis!['notes'].isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes: ${_exerciseAnalysis!['notes']}',
              style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
  
    );
  }

  // Show user-friendly error dialog
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Something Went Wrong'),
          ],
        ),
        content: Text(
          'We couldn\'t analyze your exercise. Please check your description and try again.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
  
  // Show analysis results in a bottom sheet
  void _showAnalysisBottomSheet(Map<String, dynamic> analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Bottom sheet handle
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title with icon
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.analytics, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Exercise Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Results
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise name and description
                    Text(
                      _nameController.text,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _descriptionController.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    Divider(height: 32, thickness: 1),
                    
                    // Analysis cards - 2 columns with added gap
                    Row(
                      children: [
                        Expanded(child: _buildAnalysisCard('Intensity', analysis['intensity'].toString(), Icons.speed, Colors.orange)),
                        SizedBox(width: 20), // Increased spacing
                        Expanded(child: _buildAnalysisCard('Duration', '${analysis['duration']} min', Icons.timer, Colors.blue)),
                      ],
                    ),
                    SizedBox(height: 20), // Increased spacing
                    Row(
                      children: [
                        Expanded(child: _buildAnalysisCard('Calories', '${analysis['calories'].toStringAsFixed(0)} kcal', Icons.local_fire_department, Colors.red)),
                        SizedBox(width: 20), // Increased spacing
                        Expanded(child: _buildAnalysisCard('Protein', '${analysis['protein'].toStringAsFixed(1)}g', Icons.fitness_center, Colors.green)),
                      ],
                    ),
                    SizedBox(height: 20), // Increased spacing
                    Row(
                      children: [
                        Expanded(child: _buildAnalysisCard('Carbs', '${analysis['carbs'].toStringAsFixed(1)}g', Icons.grain, Colors.amber)),
                        SizedBox(width: 20), // Increased spacing
                        Expanded(child: _buildAnalysisCard('Fat', '${analysis['fat'].toStringAsFixed(1)}g', Icons.opacity, Colors.purple)),
                      ],
                    ),
                    
                    // Notes section
                    if (analysis['notes'] != null && analysis['notes'].isNotEmpty) ...[
                      SizedBox(height: 28), // Increased spacing
                      Container(
                        padding: EdgeInsets.all(20), // Increased padding
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'AI Notes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12), // Increased spacing
                            Text(
                              analysis['notes'],
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Add button with padding for navigation bar
            Padding(
              padding: EdgeInsets.fromLTRB(
                24, 
                16, 
                24, 
                24 + MediaQuery.of(context).padding.bottom
              ),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    _saveExercise(); // Save the exercise
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add Exercise to Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build analysis card with icon and value
  Widget _buildAnalysisCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20), // Increased padding
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
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10), // Slightly increased padding
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(height: 16), // Increased spacing
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6), // Increased spacing
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
