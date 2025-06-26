import 'package:cloud_firestore/cloud_firestore.dart';

class AffiliateModel {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final String referralCode;
  final int referralCount;
  final double earnings;
  final DateTime createdAt;

  AffiliateModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.referralCode,
    this.referralCount = 0,
    this.earnings = 0.0,
    required this.createdAt,
  });

  factory AffiliateModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AffiliateModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      referralCode: data['referralCode'] ?? '',
      referralCount: data['referralCount'] ?? 0,
      earnings: (data['earnings'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'referralCode': referralCode,
      'referralCount': referralCount,
      'earnings': earnings,
      'createdAt': createdAt,
    };
  }
} 