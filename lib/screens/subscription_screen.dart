import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:io';
import 'dart:math';  // Add import for math functions
import '../constants/app_colors.dart';
import '../services/subscription_handler.dart';
import 'dart:developer' as dev;

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onContinueWithoutPurchase;
  final VoidCallback? onPurchaseCompleted;
  final Widget? destinationScreen;
  final String title;
  final String subtitle;
  final bool forceFallback;
  final bool initialShowTrial;
  final String source;

  const SubscriptionScreen({
    Key? key,
    this.onContinueWithoutPurchase,
    this.onPurchaseCompleted,
    this.destinationScreen,
    this.title = "Dietly Premium",
    this.subtitle = "Unlock the full potential of your nutrition journey",
    this.forceFallback = false,
    this.initialShowTrial = false,
    this.source = 'direct',
  }) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Package> _availablePackages = [];
  Package? _selectedPackage;
  bool _processingPurchase = false;
  bool _includeTrial = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _hasUserPurchasedAnnual = false; // Track if user has purchased annual plan before

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutBack,
    );
    
    // Repeat the animation for the logo
    _animationController.repeat(reverse: true);
    
    // Always set trial flag to true by default
    _includeTrial = true;
    
    // Call the async method without awaiting it
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Track subscription screen open with source
    await Posthog().capture(
      eventName: 'user_open_subscription',
      properties: {
        'source': widget.source,
        'show_trial': _includeTrial,
      },
    );
    
    _loadRevenueCatOfferings();
    _checkPreviousPurchases();
  }
  
  Future<void> _checkPreviousPurchases() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Check if user has purchased annual plan before
      _hasUserPurchasedAnnual = customerInfo.allPurchasedProductIdentifiers
          .any((productId) => productId.toLowerCase().contains('annual') || 
                             productId.toLowerCase().contains('year'));
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      dev.log("Error checking previous purchases: $e");
      // Default to false if we can't check
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRevenueCatOfferings() async {
    try {
      setState(() => _isLoading = true);
      dev.log("Loading RevenueCat offerings");
      
      // Attempt to get offerings from RevenueCat
      final offerings = await Purchases.getOfferings();
      dev.log("RevenueCat offerings loaded: ${offerings.all.length} offerings available");
      
      if (offerings.current != null) {
        dev.log("Current offering: ${offerings.current!.identifier}");
        dev.log("Available packages: ${offerings.current!.availablePackages.length}");
        
        // Log all packages 
        for (var package in offerings.current!.availablePackages) {
          dev.log("Package: ${package.identifier}, Type: ${package.packageType}, Price: ${package.storeProduct.priceString}");
        }
        
        setState(() {
          _availablePackages = offerings.current!.availablePackages;
          
          // Default to the first package
          if (_availablePackages.isNotEmpty) {
            _selectedPackage = _findBestPackage(_availablePackages);
          }
          
          // Ensure weekly package is selected if free trial is enabled
          if (_includeTrial && _availablePackages.isNotEmpty) {
            final weeklyPackage = _findPackageByType(PackageType.weekly);
            if (weeklyPackage != null) {
              _selectedPackage = weeklyPackage;
            }
          }
          
          _isLoading = false;
        });
      } else {
        // No current offering, check all offerings
        if (offerings.all.isNotEmpty) {
          dev.log("No current offering but ${offerings.all.length} total offerings");
          
          // Get the first offering with packages
          for (var offering in offerings.all.values) {
            if (offering.availablePackages.isNotEmpty) {
              dev.log("Using offering: ${offering.identifier} with ${offering.availablePackages.length} packages");
        
        setState(() {
                _availablePackages = offering.availablePackages;
                
                if (_availablePackages.isNotEmpty) {
                  _selectedPackage = _findBestPackage(_availablePackages);
                }
                
          _isLoading = false;
        });
              
              break;
            }
          }
      } else {
          // No packages available
          dev.log("No offerings available");
        setState(() {
          _availablePackages = [];
          _isLoading = false;
        });
        }
      }
    } catch (e) {
      dev.log("Error loading RevenueCat offerings: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Package? _findBestPackage(List<Package> packages) {
    // If free trial is enabled, prioritize weekly package
    if (_includeTrial) {
      for (var package in packages) {
        if (package.packageType == PackageType.weekly) {
          return package;
        }
      }
    }
    
    // Try to find a weekly package first
    for (var package in packages) {
      if (package.packageType == PackageType.weekly) {
        return package;
      }
    }
    
    // Then try monthly
    for (var package in packages) {
      if (package.packageType == PackageType.monthly) {
        return package;
      }
    }
    
    // Then try annual
    for (var package in packages) {
      if (package.packageType == PackageType.annual) {
        return package;
      }
    }
    
    // Default to first package
    return packages.first;
  }
  
  Future<void> _onPurchaseSuccess() async {
    // Handle successful purchase
    await Posthog().capture(
  eventName: 'user_purchased',
);
    if (widget.onPurchaseCompleted != null) {
      widget.onPurchaseCompleted!();
    } else if (widget.destinationScreen != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.destinationScreen!),
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
  
  String _getPackageDisplayName(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return 'Monthly Plan';
      case PackageType.annual:
        return 'Annual Plan';
      case PackageType.weekly:
        return 'Weekly Plan';
      case PackageType.lifetime:
        return 'Lifetime Access';
      default:
        if (package.identifier.toLowerCase().contains('month')) {
          return 'Monthly Plan';
        } else if (package.identifier.toLowerCase().contains('year') || 
                  package.identifier.toLowerCase().contains('annual')) {
          return 'Annual Plan';
        } else if (package.identifier.toLowerCase().contains('week')) {
          return 'Weekly Plan';
        } else {
          return package.identifier.replaceAll('_', ' ').replaceAll('-', ' ');
        }
    }
  }

  String _getPackagePricePerPeriod(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return _formatPrice(package.storeProduct.priceString);
      case PackageType.annual:
        // Extract just the weekly equivalent
        double yearlyPrice = package.storeProduct.price;
        double weeklyEquivalent = yearlyPrice / 52;
        String currencySymbol = _extractCurrencySymbol(package.storeProduct.priceString);
        // Format weekly equivalent with no decimal part if it's close to a whole number
        if ((weeklyEquivalent * 10).round() / 10 == weeklyEquivalent.round()) {
          return '$currencySymbol${weeklyEquivalent.round()}/week';
        }
        return '$currencySymbol${weeklyEquivalent.toStringAsFixed(2)}/week';
      case PackageType.weekly:
        return '${_formatPrice(package.storeProduct.priceString)}/week';
      default:
        return _formatPrice(package.storeProduct.priceString);
    }
  }
  
  // Extract currency symbol from price string
  String _extractCurrencySymbol(String priceString) {
    // This regex tries to match common currency symbols or currency codes
    RegExp currencyRegex = RegExp(r'^[^\d\s]+');
    var match = currencyRegex.firstMatch(priceString);
    return match != null ? match.group(0)! : '';
  }

  String _getBillingTerms(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return 'per month';
      case PackageType.annual:
        return 'billed annually';
      case PackageType.weekly:
        return 'per week';
      case PackageType.lifetime:
        return 'one-time payment';
      default:
        return '';
    }
  }
  
  String _getPackageSavings(Package package, Package? comparisonPackage) {
    try {
      if (package.packageType == PackageType.annual && comparisonPackage != null) {
        if (comparisonPackage.packageType == PackageType.monthly) {
          double monthlyPrice = comparisonPackage.storeProduct.price;
          double annualPrice = package.storeProduct.price;
        
        // Calculate yearly cost of monthly subscription
        double yearlyMonthlyPrice = monthlyPrice * 12;
        
        // Calculate percentage saved
        double savingsPercent = ((yearlyMonthlyPrice - annualPrice) / yearlyMonthlyPrice) * 100;
        
        if (savingsPercent > 0) {
          return 'Save ${savingsPercent.round()}%';
          }
        }
      }
      
      return '';
    } catch (e) {
      return '';
    }
  }

  // Get monthly package if available
  Package? get _monthlyPackage {
    for (var package in _availablePackages) {
      if (package.packageType == PackageType.monthly) {
        return package;
      }
    }
    return null;
  }

  // Get annual package if available
  Package? get _annualPackage {
    for (var package in _availablePackages) {
      if (package.packageType == PackageType.annual) {
        return package;
      }
    }
    return null;
  }

  Future<void> _purchasePackage(Package? package) async {
    await Posthog().capture(
  eventName: 'user_clicked_subscribe',
);
    if (_processingPurchase || package == null) return;
    
    try {
      setState(() => _processingPurchase = true);
      
      // Purchase the package through RevenueCat
      await Purchases.purchasePackage(package);
      
      // Check if purchase was successful
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.isNotEmpty;
      
      if (isPremium) {
        _onPurchaseSuccess();
      } else {
        setState(() => _processingPurchase = false);
      }
    } catch (e) {
      dev.log("Error making purchase: $e");
      setState(() => _processingPurchase = false);
      await Posthog().capture(
  eventName: 'user_skipped_purchase',
);
      if (mounted) {
      
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final logoSize = isSmallScreen ? 50.0 : 60.0;
    
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: Stack(
        children: [
          // Subtle top background decoration
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          // Subtle bottom background decoration
          Positioned(
            bottom: size.height * 0.3,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : Column(
                  children: [
                    // Add safe area padding at the top
                    SizedBox(height: MediaQuery.of(context).padding.top),
                    
                    // Scrollable content - more compact spacing
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              child: Column(
                                children: [
                                  // Reduced top padding for the logo
                                  SizedBox(height: isSmallScreen ? 16 : 20),
                                  
                                  // More compact logo and header section
                                  Row(
                                    children: [
                                      _buildCompactLogo(logoSize),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.title.isNotEmpty ? widget.title : "Premium Experience",
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 15 : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              widget.subtitle.isNotEmpty ? widget.subtitle : "Unlock all premium features",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 12),
                                ],
                              ),
                            ),
                            
                            // Premium Features Title
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.15),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.primary.withOpacity(0.1),
                                    width: 1,
                                  ),
                                  top: BorderSide(
                                    color: AppColors.primary.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                "Premium Features",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            
                            // Features list - more compact
                            _buildCompactFeatureItem(
                              icon: Icons.camera_alt_outlined,
                              text: "Scan unlimited foods with AI",
                              description: "No limits on food scanning",
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: 8),
                            
                            _buildCompactFeatureItem(
                              icon: Icons.auto_graph_outlined,
                              text: "Advanced nutrition insights",
                              description: "Detailed analytics and reports",
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: 8),
                            
                            _buildCompactFeatureItem(
                              icon: Icons.restaurant_menu_outlined,
                              text: "Unlimited Daily Meal Plans",
                              description: "No Limitations for Meal Plans",
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: 8),
                            
                            _buildCompactFeatureItem(
                              icon: Icons.widgets_outlined,
                              text: "Daily Face Glow Workouts",
                              description: "Personalized workouts for jawline, neck, and face",
                              isSmallScreen: isSmallScreen,
                            ),
                            
                            SizedBox(height: isSmallScreen ? 16 : 20),
                          ],
                        ),
                      ),
                    ),
                    
                    // Fixed bottom section with subscription options
                    Container(
                      padding: EdgeInsets.only(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        top: 20,
                        bottom: 20 + MediaQuery.of(context).padding.bottom, // Account for safe area
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: Offset(0, -3),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subscription title with free trial toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Choose Your Plan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              
                              // Free trial toggle
                              Row(
                                children: [
                                  Text(
                                    "3-Day Free Trial",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Switch(
                                    value: _includeTrial,
                                    onChanged: (value) {
                                      setState(() {
                                        _includeTrial = value;
                                        if (value) {
                                          // Always select weekly plan when free trial is enabled
                                          final weeklyPackage = _findPackageByType(PackageType.weekly);
                                          if (weeklyPackage != null) {
                                            _selectedPackage = weeklyPackage;
                                          }
                                        }
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    activeTrackColor: AppColors.primary.withOpacity(0.4),
                                    inactiveThumbColor: Colors.grey.shade400,
                                    inactiveTrackColor: Colors.grey.shade300,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          // More compact subscription options
                          _buildCompactSubscriptionOptions(isSmallScreen),
                          
                          SizedBox(height: 20),
                          
                          // Enhanced subscribe button
                          _buildEnhancedSubscribeButton(isSmallScreen),
                          
                          SizedBox(height: 16),
                          
                          // Terms and restore links
                          Container(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _showRestorePurchasesLoader();
                                  },
                                  child: Text(
                                    "Restore",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    "•",
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                
                                GestureDetector(
                                  onTap: () async {
                                    final termsUrl = 'https://carpal-gong-e73.notion.site/Terms-and-Conditions-1c50266187e180259149fa10f55b29e4?pvs=74';
                                    await _launchUrl(termsUrl);
                                  },
                                  child: Text(
                                    "Terms",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    "•",
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                
                                GestureDetector(
                                  onTap: () async {
                                    final privacyPolicyUrl = 'https://carpal-gong-e73.notion.site/Privacy-Policy-1c50266187e180d18cb1d1bf7f5e8ba2?pvs=74';
                                    await _launchUrl(privacyPolicyUrl);
                                  },
                                  child: Text(
                                    "Privacy",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  // Simplified compact logo
  Widget _buildCompactLogo(double logoSize) {
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.workspace_premium,
        color: AppColors.primary,
        size: logoSize * 0.6,
      ),
    );
  }
  
  // More compact feature item with global colors
  Widget _buildCompactFeatureItem({
    required IconData icon,
    required String text,
    required String description,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: AppColors.primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  // More compact subscription options
  Widget _buildCompactSubscriptionOptions(bool isSmallScreen) {
    final Package? yearlyPackage = _findPackageByType(PackageType.annual);
    final Package? weeklyPackage = _findPackageByType(PackageType.weekly);
    final Package? monthlyPackage = _findPackageByType(PackageType.monthly);
    
    // Calculate discount percentage dynamically based on available packages
    String discountPercentage = "SAVE";
    String originalPrice = "";
    
    if (yearlyPackage != null && monthlyPackage != null) {
      // Calculate yearly equivalent of monthly plan
      double monthlyPrice = monthlyPackage.storeProduct.price;
      double yearlyMonthlyPrice = monthlyPrice * 12;
      double yearlyPrice = yearlyPackage.storeProduct.price;
      
      // Calculate discount percentage
      int discountPercent = ((yearlyMonthlyPrice - yearlyPrice) / yearlyMonthlyPrice * 100).round();
      discountPercentage = "$discountPercent% OFF";
      originalPrice = _formatPrice(yearlyPackage.storeProduct.priceString);
    } else if (yearlyPackage != null) {
      originalPrice = _formatPrice(yearlyPackage.storeProduct.priceString);
      discountPercentage = "50% OFF";
    } else {
      originalPrice = "\$399";
      discountPercentage = "90% OFF";
    }
    
    if (_availablePackages.isEmpty) {
      return const Text(
        "No subscription options available",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.red,
          fontSize: 14,
        ),
      );
    }
    
    // Calculate final display price for yearly plan
    String yearlyDisplayPrice = yearlyPackage != null ? 
        _getYearlyDisplayPrice(yearlyPackage, monthlyPackage) : 
        "\$39";
    
    // Extract percentage value from discount percentage string
    String discountPercent = "50";
    if (discountPercentage.contains("%")) {
      discountPercent = discountPercentage.replaceAll(RegExp(r'[^0-9]'), '');
    }
    
    return Column(
      children: [
        // Modern card-like subscription options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Yearly plan card
                Expanded(
                  child: _buildPremiumSubscriptionCard(
                    isSelected: _selectedPackage?.packageType == PackageType.annual,
                    title: "Annual",
                    price: yearlyDisplayPrice,
                    originalPrice: originalPrice,
                    billPeriod: "per year",
                    discountTag: discountPercentage,
                    features: ["Best value", "Full access", "One payment"],
                    onTap: () {
                      if (yearlyPackage != null) {
                        setState(() {
                          _selectedPackage = yearlyPackage;
                          // Automatically turn off free trial when yearly plan is selected
                          _includeTrial = false;
                        });
                      }
                    },
                    isPopular: true,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(width: 12),
                // Weekly plan card
                Expanded(
                  child: _buildPremiumSubscriptionCard(
                    isSelected: _selectedPackage?.packageType == PackageType.weekly,
                    title: "Weekly",
                    // Show FREE instead of price when trial is enabled
                    price: _includeTrial ? "FREE" : 
                        (weeklyPackage?.storeProduct.priceString != null ? 
                        _formatPrice(weeklyPackage!.storeProduct.priceString) : "\$7"),
                    originalPrice: null,
                    // Change billing period text when free trial is enabled
                    billPeriod: _includeTrial ? "3-day trial" : "per week",
                    discountTag: null,
                    features: _includeTrial ? ["No charge today", "Full access", "Cancel anytime"] : ["Pay weekly", "Full access", "Cancel anytime"],
                    onTap: () {
                      if (weeklyPackage != null) {
                        setState(() {
                          _selectedPackage = weeklyPackage;
                          _includeTrial = true;
                        });
                      }
                    },
                    showTrialBadge: _includeTrial,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // New premium subscription card widget
  Widget _buildPremiumSubscriptionCard({
    required bool isSelected,
    required String title,
    required String price,
    required String? originalPrice,
    required String billPeriod,
    required String? discountTag,
    required List<String> features,
    required VoidCallback onTap,
    bool isPopular = false,
    bool showTrialBadge = false,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Popular badge
            if (isPopular)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    "BEST VALUE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
              
            // Free trial badge
            if (showTrialBadge)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    "FREE TRIAL",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            
            // Radio button and title
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: 1.5,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected ? Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ) : null,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Price section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original price with strikethrough if discount is available
                if (originalPrice != null && discountTag != null)
                  Row(
                    children: [
                      Text(
                        _formatPrice(originalPrice),
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          discountTag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: originalPrice != null ? 4 : 0),
                
                // Current price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatPrice(price),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primary : Colors.black,
                      ),
                    ),
                    SizedBox(width: 2),
                    Text(
                      billPeriod,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 10),
            
            // Description text instead of feature list
            Text(
              features.join(' • '),
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced subscribe button with gradient and animation
  Widget _buildEnhancedSubscribeButton(bool isSmallScreen) {
    String buttonText = _includeTrial && _selectedPackage?.packageType == PackageType.weekly ? 
        "Start Free Trial" : 
        "Get Premium";
    
    return SizedBox(
      width: double.infinity,
      height: 56, // Increased height for better visibility
      child: ElevatedButton(
        onPressed: () => _processingPurchase ? null : _purchasePackage(_selectedPackage),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Use transparent to allow the gradient to show
          foregroundColor: Colors.white,
          elevation: 8, // Increased elevation
          shadowColor: AppColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Slightly more rounded
          ),
          padding: EdgeInsets.zero, // Remove padding to apply our own
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, AppColors.accent, 0.6)!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: _processingPurchase
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.97, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _includeTrial && _selectedPackage?.packageType == PackageType.weekly
                                  ? Icons.bolt_rounded
                                  : Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: null,
                  ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Enhanced terms and restore section
  Widget _buildEnhancedTermsAndRestore() {
    final privacyPolicyUrl = 'https://carpal-gong-e73.notion.site/Privacy-Policy-1c50266187e180d18cb1d1bf7f5e8ba2?pvs=74';
    final termsUrl = 'https://carpal-gong-e73.notion.site/Terms-and-Conditions-1c50266187e180259149fa10f55b29e4?pvs=74';
    
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEnhancedLink(
            text: "Restore",
            onTap: () {
              _showRestorePurchasesLoader();
            },
          ),
          
          _buildEnhancedDotSeparator(),
          
          _buildEnhancedLink(
            text: "Terms",
            onTap: () async {
              await _launchUrl(termsUrl);
            },
          ),
          
          _buildEnhancedDotSeparator(),
          
          _buildEnhancedLink(
            text: "Privacy",
            onTap: () async {
              await _launchUrl(privacyPolicyUrl);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildEnhancedLink({required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildEnhancedDotSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        "•",
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showRestorePurchasesLoader() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
                    child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                        Text(
                  "Restoring Purchases...",
                          style: TextStyle(
                    fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                SizedBox(height: 8),
                        Text(
                  "Please wait while we restore your purchases.",
                  textAlign: TextAlign.center,
                          style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
          ],
        ),
      ),
    );
      },
    );
    
    // Perform restore
    _restorePurchases().then((_) {
      // Close dialog when complete
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _restorePurchases() async {
    try {
      // Restore purchases
      await Purchases.restorePurchases();
      
      // Get customer info to check if restoration was successful
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.isNotEmpty;
      
      if (mounted) {
        if (isPremium) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your purchases have been successfully restored!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Handle successful restoration
          _onPurchaseSuccess();
        } else {
          // Show no purchases found message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No previous purchases found to restore.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper function to find package by type
  Package? _findPackageByType(PackageType type) {
    for (var package in _availablePackages) {
      if (package.packageType == type) {
        return package;
      }
    }
    return null;
  }
  
  // Calculate display price for yearly package
  String _getYearlyDisplayPrice(Package yearlyPackage, Package? monthlyPackage) {
    // If we have both yearly and monthly packages, we can calculate a realistic discount
    if (monthlyPackage != null) {
      // Calculate yearly equivalent of monthly plan
      double monthlyPrice = monthlyPackage.storeProduct.price;
      double yearlyMonthlyPrice = monthlyPrice * 12;
      double yearlyPrice = yearlyPackage.storeProduct.price;
      
      // Calculate the discounted price (50% of yearly price)
      String currencySymbol = _extractCurrencySymbol(yearlyPackage.storeProduct.priceString);
      double discountedPrice = yearlyPrice * 0.5; // 50% of yearly price
      
      // Format with no decimal part if it's close to a whole number
      if (discountedPrice.round() == discountedPrice) {
        return '$currencySymbol${discountedPrice.round()}';
      }
      
      return '$currencySymbol${discountedPrice.toStringAsFixed(0)}';
    }
    
    // If we only have yearly package, apply 50% discount
    String currencySymbol = _extractCurrencySymbol(yearlyPackage.storeProduct.priceString);
    double originalPrice = yearlyPackage.storeProduct.price;
    double discountedPrice = originalPrice * 0.5; // 50% discount
    
    // Format with no decimal part if it's close to a whole number
    if (discountedPrice.round() == discountedPrice) {
      return '$currencySymbol${discountedPrice.round()}';
    }
    
    return '$currencySymbol${discountedPrice.toStringAsFixed(0)}';
  }

  // Calculate discounted price for package (primarily for annual plans)
  String _getDiscountedPrice(Package package) {
    if (package.packageType == PackageType.annual) {
      // Check if we can dynamically calculate the discount
      Package? monthlyPackage = _findPackageByType(PackageType.monthly);
      
      if (monthlyPackage != null) {
        // Calculate the yearly equivalent of the monthly plan
        double monthlyPrice = monthlyPackage.storeProduct.price;
        double yearlyMonthlyPrice = monthlyPrice * 12;
        double yearlyPrice = package.storeProduct.price;
        
        // If yearly price is already lower than yearly equivalent of monthly, just return it
        if (yearlyPrice < yearlyMonthlyPrice) {
          // Remove decimal part if it's a whole number
          if (yearlyPrice == yearlyPrice.round()) {
            return package.storeProduct.priceString.replaceAll(RegExp(r'\.\d+'), '');
          }
          return package.storeProduct.priceString;
        }
      }
      
      // Return the actual yearly price, no artificial discount applied
      // Remove decimal part if it's a whole number
      if (package.storeProduct.price == package.storeProduct.price.round()) {
        return package.storeProduct.priceString.replaceAll(RegExp(r'\.\d+'), '');
      }
      return package.storeProduct.priceString;
    }
    
    // Remove decimal part if it's a whole number
    if (package.storeProduct.price == package.storeProduct.price.round()) {
      return package.storeProduct.priceString.replaceAll(RegExp(r'\.\d+'), '');
    }
    return package.storeProduct.priceString;
  }

  // Helper method to launch URLs
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      // Show error message if URL can't be launched
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Format price without decimal part if it's a whole number
  String _formatPrice(String priceString) {
    // Extract just the price part (remove currency symbol)
    final priceMatch = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(priceString);
    if (priceMatch != null) {
      final priceValue = double.tryParse(priceMatch.group(0) ?? '0');
      if (priceValue != null) {
        // Check if it's a whole number
        if (priceValue == priceValue.round()) {
          // Replace the decimal part with empty string
          return priceString.replaceAll(RegExp(r'\.\d+'), '');
        }
      }
    }
    return priceString;
  }
} 