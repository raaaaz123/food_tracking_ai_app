import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/affiliate_model.dart';
import '../constants/app_colors.dart';

class AffiliateProgramScreen extends StatefulWidget {
  const AffiliateProgramScreen({super.key});

  @override
  State<AffiliateProgramScreen> createState() => _AffiliateProgramScreenState();
}

class _AffiliateProgramScreenState extends State<AffiliateProgramScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
    clientId: '152671122222-tg8j5es3664l9dpngrf4q15f0eofbc78.apps.googleusercontent.com',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _referralCodeController = TextEditingController();
  
  bool _isLoading = false;
  AffiliateModel? _affiliateData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final currentUser = await _googleSignIn.signInSilently();
    if (currentUser != null) {
      await _signInWithGoogle(currentUser);
    }
  }

  Future<void> _handleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('Starting Google Sign In...'); // Debug log
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('Sign in result: ${googleUser != null ? 'Success' : 'Cancelled'}'); // Debug log
      
      if (googleUser == null) {
        setState(() {
          _error = 'Sign in cancelled';
          _isLoading = false;
        });
        return;
      }

      await _signInWithGoogle(googleUser);
    } catch (error) {
      print('Google Sign In Error: $error'); // Debug log
      setState(() {
        if (error.toString().contains('network_error')) {
          _error = 'Network error. Please check your internet connection.';
        } else if (error.toString().contains('sign_in_failed')) {
          _error = 'Sign in failed. Please try again or contact support.';
        } else {
          _error = 'Failed to sign in: $error';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      // Get Google Sign-In authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to sign in with Firebase');
      }

      await _loadAffiliateData(googleUser);
    } catch (error) {
      print('Firebase Auth Error: $error');
      setState(() {
        _error = 'Authentication failed: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAffiliateData(GoogleSignInAccount user) async {
    try {
      // Get the Firebase user ID
      final String uid = _auth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        throw Exception('No Firebase user ID available');
      }

      final doc = await _firestore.collection('affiliates').doc(uid).get();
      
      if (doc.exists) {
        setState(() {
          _affiliateData = AffiliateModel.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        _referralCodeController.text = user.displayName?.split(' ')[0].toLowerCase() ?? '';
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Load Affiliate Data Error: $error');
      setState(() {
        _error = 'Failed to load affiliate data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAffiliateData(GoogleSignInAccount user) async {
    if (_referralCodeController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a referral code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get the Firebase user ID
      final String uid = _auth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        throw Exception('No Firebase user ID available');
      }

      // Check if referral code is already taken
      final existingCode = await _firestore
          .collection('affiliates')
          .where('referralCode', isEqualTo: _referralCodeController.text)
          .get();

      if (existingCode.docs.isNotEmpty) {
        setState(() {
          _error = 'This referral code is already taken';
          _isLoading = false;
        });
        return;
      }

      final newAffiliate = AffiliateModel(
        id: uid, // Use Firebase UID instead of Google ID
        name: user.displayName ?? '',
        email: user.email,
        photoUrl: user.photoUrl ?? '',
        referralCode: _referralCodeController.text,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('affiliates')
          .doc(uid)
          .set(newAffiliate.toMap());

      setState(() {
        _affiliateData = newAffiliate;
        _isLoading = false;
      });
    } catch (error) {
      print('Save Affiliate Data Error: $error');
      setState(() {
        _error = 'Failed to save affiliate data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
    setState(() {
      _affiliateData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Earn With Dietly',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_affiliateData == null) ...[
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    _buildSignInSection(),
                  ] else ...[
                    _buildAffiliateInfoCard(),
                    const SizedBox(height: 20),
                    _buildEarningsCard(),
                    const SizedBox(height: 20),
                    _buildReferralStatsCard(),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7BC27D),
            Color(0xFF4CAF50),
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Become an Affiliate',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join our affiliate program and earn money by referring new users to Dietly.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_googleSignIn.currentUser == null) ...[
          ElevatedButton.icon(
            onPressed: _handleSignIn,
            icon: Image.network(
              'https://www.google.com/favicon.ico',
              height: 24,
            ),
            label: Text('Sign in with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else if (_affiliateData == null) ...[
          Text(
            'Choose your referral code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referralCodeController,
            decoration: InputDecoration(
              labelText: 'Referral Code',
              hintText: 'Enter your unique referral code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _saveAffiliateData(_googleSignIn.currentUser!),
            child: Text('Save and Start Earning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAffiliateInfoCard() {
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(_affiliateData!.photoUrl),
                radius: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _affiliateData!.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _affiliateData!.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Referral Code',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _affiliateData!.referralCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleSignOut,
            child: Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Earnings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${_affiliateData!.earnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Total Earnings',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.attach_money,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralStatsCard() {
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_affiliateData!.referralCount}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Total Referrals',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 