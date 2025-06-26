import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../models/user_details.dart';
import '../constants/app_colors.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  String _feedbackType = 'Feature Request';
  bool _isSubmitting = false;
  UserDetails? _userDetails;
  
  // Design constants - replaced with global AppColors
  // final Color _primaryColor = const Color(0xFF6C63FF);
  // final Color _accentColor = const Color(0xFFFFA48E);
  // final Color _backgroundColor = const Color(0xFFF8F9FD);
  // final Color _cardColor = Colors.white;
  // final Color _textColor = const Color(0xFF2D3142);
  // final Color _lightTextColor = const Color(0xFF9E9EAB);
  
  final List<String> _feedbackTypes = [
    'Feature Request',
    'Bug Report',
    'General Feedback',
    'Question',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDetails = await StorageService.getUserDetails();
      setState(() {
        _userDetails = userDetails;
        if (userDetails != null) {
          _nameController.text = userDetails.name ?? '';
          _emailController.text = userDetails.email ?? '';
        }
      });
    } catch (e) {

    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Get device information
        final deviceInfo = await _getDeviceInfo();
        
        // Submit feedback using Firebase service
        final feedbackId = await FirebaseService.submitFeedback(
          name: _nameController.text,
          email: _emailController.text,
          subject: _subjectController.text,
          message: _messageController.text,
          feedbackType: _feedbackType,
          userId: _userDetails?.id,
          deviceInfo: deviceInfo,
        );
        
        setState(() {
          _isSubmitting = false;
        });
        
        // Show success message and go back
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackId != null 
                ? 'Thank you for your feedback! Reference ID: ${feedbackId.substring(0, 6)}' 
                : 'Thank you for your feedback!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
  
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = <String, dynamic>{};
    
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo['platform'] = 'Android';
        deviceInfo['version'] = androidInfo.version.release;
        deviceInfo['model'] = androidInfo.model;
        deviceInfo['manufacturer'] = androidInfo.manufacturer;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo['platform'] = 'iOS';
        deviceInfo['version'] = iosInfo.systemVersion;
        deviceInfo['model'] = iosInfo.model;
        deviceInfo['name'] = iosInfo.name;
      } else {
        deviceInfo['platform'] = 'Other';
      }
    } catch (e) {

      deviceInfo['platform'] = 'Unknown';
      deviceInfo['error'] = e.toString();
    }
    
    return deviceInfo;
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to black
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // For iOS
    ));
    
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Input decoration theme for consistent form fields
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      prefixIconColor: AppColors.primary,
      suffixIconColor: AppColors.primary,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Support & Feedback',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with form
            Positioned.fill(
              bottom: 80 + bottomPadding, // Reserve space for bottom button
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header section with gradient and illustration
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'We\'d Love to Hear from You!',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Share your ideas, report bugs, or ask questions to help us improve your experience.',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.support_agent,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 28),
                            
                            // Form container
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How can we help you?',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Type of feedback with custom dropdown
                                  DropdownButtonFormField<String>(
                                    value: _feedbackType,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Type of Feedback',
                                      prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                    items: _feedbackTypes.map((String type) {
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _feedbackType = newValue;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Name field
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Your Name',
                                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Email field
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Your Email',
                                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Subject field
                                  TextFormField(
                                    controller: _subjectController,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Subject',
                                      prefixIcon: Icon(Icons.subject, color: AppColors.primary),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a subject';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Message field
                                  TextFormField(
                                    controller: _messageController,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Your Message',
                                      alignLabelWithHint: true,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(bottom: 80),
                                        child: Icon(Icons.message_outlined, color: AppColors.primary),
                                      ),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary),
                                    maxLines: 6,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your message';
                                      }
                                      return null;
                                    },
                                  ),
                                  
                                  // Add bottom padding to ensure the last field is visible when keyboard is open
                                  SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Fixed submit button at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 