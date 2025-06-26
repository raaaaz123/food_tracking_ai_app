import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static FirebaseFirestore? _firestore;
  
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firestore = FirebaseFirestore.instance;
   
    } catch (e) {
    
    }
  }
  
  static Future<String?> submitFeedback({
    required String name,
    required String email,
    required String subject,
    required String message,
    required String feedbackType,
    String? userId,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      if (_firestore == null) {
        await initialize();
      }
      
      final feedbackRef = _firestore!.collection('feedback').doc();
      
      await feedbackRef.set({
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
        'feedbackType': feedbackType,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId ?? 'anonymous',
        'deviceInfo': deviceInfo ?? {},
        'appVersion': '1.0.0', // Replace with actual app version
        'status': 'new',
        'id': feedbackRef.id,
      });
      
      return feedbackRef.id;
    } catch (e) {
  
      return null;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getUserFeedback(String userId) async {
    try {
      if (_firestore == null) {
        await initialize();
      }
      
      final snapshot = await _firestore!
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {

      return [];
    }
  }
} 