import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import 'main_app_screen.dart';
import '../services/nutrition_service.dart';
import 'personal_details_screen.dart';
import 'adjust_goals_screen.dart';
import '../services/google_health_service.dart';
import 'web_view_screen.dart';
import '../models/user_details.dart';
import '../constants/app_colors.dart';
import '../services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intro_screen.dart';
import 'support_screen.dart';
import '../services/subscription_handler.dart';
import 'affiliate_program_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _userDetails;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _isPremium = false;

  // Remove local color definitions and use AppColors instead
  // These getter methods ensure backward compatibility with existing code
  Color get _primaryColor => AppColors.primary;
  Color get _accentColor => AppColors.error;
  Color get _backgroundColor => AppColors.background;
  Color get _cardColor => AppColors.cardBackground;
  Color get _textColor => AppColors.textPrimary;
  Color get _lightTextColor => AppColors.textSecondary;
  Color get _surfaceColor => AppColors.surfaceColor;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkPremiumStatus();
    
    // Remove custom status bar styling
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userDetails = await StorageService.getUserDetails();

      setState(() {
        _userDetails = userDetails?.toMap();
        _isLoading = false;
      });
    } catch (e) {

      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Check premium status
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

  // Open subscription screen
  void _openSubscriptionScreen() async {
    await SubscriptionHandler.showSubscriptionScreen(
      context,
      feature: Feature.premium,
      title: "Upgrade to Premium",
      subtitle: "Enjoy unlimited access to all premium features",
    );
    
    // Check premium status again after returning from subscription screen
    _checkPremiumStatus();
  }

  Future<void> _updateIsMetric(bool value) async {
    if (_userDetails == null) return;

    final updatedDetails = Map<String, dynamic>.from(_userDetails!);
    updatedDetails['isMetric'] = value;

    try {
      await StorageService.saveUserDetails(
        UserDetails(
          height: updatedDetails['height'] as double? ?? 0.0,
          weight: updatedDetails['weight'] as double? ?? 0.0,
          birthDate: updatedDetails['birthDate'] as DateTime? ?? DateTime.now(),
          isMetric: value,
          workoutsPerWeek: updatedDetails['workoutsPerWeek'] as int? ?? 3,
          weightGoal: updatedDetails['weightGoal'] as String? ?? 'maintain',
          targetWeight: updatedDetails['targetWeight'] as double? ?? 0.0,
          gender: updatedDetails['gender'] as String? ?? 'Other',
          motivationGoal: updatedDetails['motivationGoal'] as String? ?? 'healthier',
          dietType: updatedDetails['dietType'] as String? ?? 'classic',
          weightChangeSpeed: updatedDetails['weightChangeSpeed'] as double? ?? 0.0,
        )
      );

      setState(() {
        _userDetails = updatedDetails;
      });
    } catch (e) {

    }
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController();
    nameController.text = _userDetails?['name'] as String? ?? 'User';
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Edit Name',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
              style: TextStyle(color: _textColor),
              textCapitalization: TextCapitalization.words,
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
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF7BC27D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _updateUserName(result);
    }
  }

  Future<void> _updateUserName(String name) async {
    if (_userDetails == null) return;

    final updatedDetails = Map<String, dynamic>.from(_userDetails!);
    updatedDetails['name'] = name;

    try {
      await StorageService.saveUserDetails(
        UserDetails(
          height: updatedDetails['height'] as double? ?? 0.0,
          weight: updatedDetails['weight'] as double? ?? 0.0,
          birthDate: updatedDetails['birthDate'] as DateTime? ?? DateTime.now(),
          isMetric: updatedDetails['isMetric'] as bool? ?? false,
          workoutsPerWeek: updatedDetails['workoutsPerWeek'] as int? ?? 3,
          weightGoal: updatedDetails['weightGoal'] as String? ?? 'maintain',
          targetWeight: updatedDetails['targetWeight'] as double? ?? 0.0,
          gender: updatedDetails['gender'] as String? ?? 'Other',
          motivationGoal: updatedDetails['motivationGoal'] as String? ?? 'healthier',
          dietType: updatedDetails['dietType'] as String? ?? 'classic',
          weightChangeSpeed: updatedDetails['weightChangeSpeed'] as double? ?? 0.0,
        )
      );

      setState(() {
        _userDetails = updatedDetails;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating name: $e'),
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

  String _getInitials() {
    if (_userDetails == null) return '?';
    final name = _userDetails!['name'] as String? ?? 'User';
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0].isNotEmpty ? parts[0][0] : ""}${parts[1].isNotEmpty ? parts[1][0] : ""}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDOB() {
    if (_userDetails == null) return 'Not set';

    final dob = _userDetails!['birthDate'] as DateTime?;
    if (dob == null) return 'Not set';

    return '${dob.day}/${dob.month}/${dob.year}';
  }

  Widget _buildAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: Color(0xFF7BC27D),
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
                                   Color(0xFF7BC27D), // Medium green matching card background
                Color(0xFF4CAF50), // Darker green
                                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Modern avatar with shadow and border
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _userDetails?['name'] as String? ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _showEditNameDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_userDetails?['height']?.toString() ?? 'Not set'} ${_userDetails?['isMetric'] == true ? 'cm' : 'in'} • ${_userDetails?['weight']?.toString() ?? 'Not set'} ${_userDetails?['isMetric'] == true ? 'kg' : 'lbs'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDOB(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalDetailsScreen(),
                  ),
                ).then((_) {
                  // Refresh user data when returning from personal details screen
                  _loadUserData();
                });
              },
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF4CAF50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required Widget trailing,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    final Color textColor = disabled ? Colors.grey.shade400 : AppColors.textPrimary;
    final Color iconBackgroundColor = disabled 
        ? Colors.grey.withOpacity(0.1) 
        : (iconColor ?? AppColors.primary).withOpacity(0.15);
    final Color actualIconColor = disabled 
        ? Colors.grey.shade400 
        : (iconColor ?? AppColors.primary);
        
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: disabled ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: actualIconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: disabled ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingItem(
            title: 'Premium Status',
            subtitle: _isPremium ? 'You have premium access' : 'Unlock all premium features',
            icon: Icons.workspace_premium,
            iconColor: Color(0xFFFFD700), // Gold color
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF9800), // Orange
                    Color(0xFFFF5722), // Deep Orange
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF9800).withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _isPremium ? 'ACTIVE' : 'UPGRADE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            onTap: _openSubscriptionScreen,
          ),
          _buildSettingItem(
            title: 'Earn With Dietly',
            subtitle: 'Join our affiliate program and earn money',
            icon: Icons.monetization_on_outlined,
            iconColor: Colors.green,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AffiliateProgramScreen(),
                ),
              );
            },
          ),
          _buildSettingItem(
            title: 'Measurement Units',
            subtitle: _userDetails?['isMetric'] == true ? 'Metric (kg, cm)' : 'Imperial (lbs, in)',
            icon: Icons.straighten,
            trailing: Switch(
              value: _userDetails?['isMetric'] == true,
              onChanged: (value) {
                _updateIsMetric(value);
              },
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
          _buildSettingItem(
            title: 'Nutrition Goals',
            subtitle: 'Customize your daily nutrition targets',
            icon: Icons.fitness_center,
            iconColor: Colors.green.shade600,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdjustGoalsScreen(),
                ),
              );
            },
          ),
          _buildSettingItem(
            title: 'App Notifications',
            subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
            icon: Icons.notifications_outlined,
            iconColor: Colors.amber.shade700,
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
          _buildSettingItem(
            title: 'Meal Reminders',
            subtitle: 'Coming soon - Set reminders for daily meals',
            icon: Icons.restaurant_outlined,
            iconColor: Colors.orange.shade500,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            disabled: true,
          ),
          _buildSettingItem(
            title: 'Dark Mode',
            subtitle: 'Currently using light theme for best visibility',
            icon: Icons.dark_mode_outlined,
            iconColor: Colors.indigo.shade400,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Text(
                'Light Mode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          _buildSettingItem(
            title: 'Support & Feedback',
            subtitle: 'Get help or share your suggestions',
            icon: Icons.support_agent,
            iconColor: AppColors.info,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupportScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Legal & App Info',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingItem(
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.info,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebViewScreen(
                    url: 'https://carpal-gong-e73.notion.site/Privacy-Policy-1c50266187e180d18cb1d1bf7f5e8ba2?pvs=74',
                    title: 'Privacy Policy',
                  ),
                ),
              );
            },
          ),
          _buildSettingItem(
            title: 'Terms of Service',
            subtitle: 'Read our terms of service',
            icon: Icons.description_outlined,
            iconColor: AppColors.primary,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebViewScreen(
                    url: 'https://carpal-gong-e73.notion.site/Terms-and-Conditions-1c50266187e180259149fa10f55b29e4?pvs=74',
                    title: 'Terms of Service',
                  ),
                ),
              );
            },
          ),
          _buildSettingItem(
            title: 'App Version',
            subtitle: '1.0.5',
            icon: Icons.new_releases_outlined,
            iconColor: Colors.grey.shade600,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          _buildSettingItem(
            title: 'Delete Account',
            subtitle: 'Permanently remove all your data',
            icon: Icons.delete_outline,
            iconColor: AppColors.error,
            trailing: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever,
                size: 14,
                color: AppColors.error,
              ),
            ),
            onTap: _showDeleteConfirmation,
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This will delete all your data including your profile and nutrition plan. This action cannot be undone.',
              style: TextStyle(fontSize: 14, color: _textColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: _lightTextColor,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteUserData();
    }
  }

  Future<void> _deleteUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear all user data
      await StorageService.clearUserDetails();
      await StorageService.setFirstTime(true);
      await NutritionService.clearNutritionPlan();

      // Get current theme before resetting
      final currentTheme = await ThemeService.getThemeMode();

      // Navigate to intro screen
      if (!mounted) return;

      // Navigate to main app and let it handle the redirection based on preferences
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => const MyApp(
                  themeMode: ThemeMode.light,
                  initialScreen: IntroScreen(),
                )),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      backgroundColor: Color(0xFFF8F9FE),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SafeArea(
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
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
                              Icons.arrow_back_ios,
                              color: AppColors.textPrimary,
                              size: 18,
                            ),
                          ),
              ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Settings',
              style: TextStyle(
                                fontSize: 18,
                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
              ),
            ),
                          ),
                        ),
                        SizedBox(width: 40),
          ],
        ),
      ),
                  Expanded(
        child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileCard(),
                          const SizedBox(height: 24),
                _buildSettingsCard(),
                          const SizedBox(height: 24),
                _buildAboutCard(),
                          const SizedBox(height: 40),
              ],
            ),
          ),
                  ),
                ],
        ),
      ),
    );
  }
}
