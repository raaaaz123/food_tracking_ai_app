import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service to manage API keys centrally with secure approach using Firebase Remote Config
class ApiKeyService {
  // Private constructor to prevent instantiation
  ApiKeyService._();
  
  // Static flag to track if initialization warning has been shown
  static bool _hasShownWarning = false;
  
  // Static flag to track if Firebase RemoteConfig has been initialized
  static bool _isRemoteConfigInitialized = false;
  
  // Cache for keys from Remote Config
  static String? _cachedGptKey;
  static String? _cachedGeminiKey;
  
  /// Initialize the service, must be called after Firebase.initializeApp()
  static Future<void> initialize() async {
    if (_isRemoteConfigInitialized) return;
    
    try {
      debugPrint('🔑 Initializing ApiKeyService with Firebase Remote Config');
      
      // Use Firebase Remote Config to securely fetch keys
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      try {
        // Set default values in case fetch fails
        await remoteConfig.setDefaults({
          'GPT_API_KEY': '',
          'GEMINI_API_KEY': '',
        });
        
        // Fetch fresh values
        await remoteConfig.fetchAndActivate();
        
        // Cache the keys
        _cachedGptKey = remoteConfig.getString('GPT_API_KEY');
        _cachedGeminiKey = remoteConfig.getString('GEMINI_API_KEY');
        
        debugPrint('🔐 Remote config for API keys initialized successfully');
        
        // Log key status after initialization
        logKeyStatus();
      } catch (e) {
        debugPrint('❌ Error initializing Firebase Remote Config: $e');
      }
      
      _isRemoteConfigInitialized = true;
    } catch (e) {
      debugPrint('❌ Error in ApiKeyService initialization: $e');
    }
  }
  
  /// Get the OpenAI GPT API key from Firebase Remote Config
  static String getGptApiKey() {
    try {
      if (_cachedGptKey != null && _cachedGptKey!.isNotEmpty) {
        return _cachedGptKey!;
      }
      
      // If not cached but Remote Config is available, try to get it directly
      if (_isRemoteConfigInitialized) {
        try {
          final remoteConfig = FirebaseRemoteConfig.instance;
          final key = remoteConfig.getString('GPT_API_KEY');
          _cachedGptKey = key; // Update cache
          return key;
        } catch (e) {
          debugPrint('❌ Error accessing Remote Config: $e');
        }
      }
      
      if (!_hasShownWarning) {
        debugPrint('⚠️ Warning: Failed to get GPT_API_KEY from Remote Config');
        _hasShownWarning = true;
      }
      return '';
    } catch (e) {
      debugPrint('❌ Error getting GPT API key: $e');
      return '';
    }
  }
  
  /// Get the Google Gemini API key from Firebase Remote Config
  static String getGeminiApiKey() {
    try {
      if (_cachedGeminiKey != null && _cachedGeminiKey!.isNotEmpty) {
        return _cachedGeminiKey!;
      }
      
      // If not cached but Remote Config is available, try to get it directly
      if (_isRemoteConfigInitialized) {
        try {
          final remoteConfig = FirebaseRemoteConfig.instance;
          final key = remoteConfig.getString('GEMINI_API_KEY');
          _cachedGeminiKey = key; // Update cache
          return key;
        } catch (e) {
          debugPrint('❌ Error accessing Remote Config: $e');
        }
      }
      
      if (!_hasShownWarning) {
        debugPrint('⚠️ Warning: Failed to get GEMINI_API_KEY from Remote Config');
        _hasShownWarning = true;
      }
      return '';
    } catch (e) {
      debugPrint('❌ Error getting Gemini API key: $e');
      return '';
    }
  }
  
  /// Force refresh API keys from Firebase Remote Config
  /// This can be called if keys need to be updated during runtime
  static Future<void> refreshKeys() async {
    try {
      debugPrint('🔄 Refreshing API keys from Remote Config');
      
      if (!_isRemoteConfigInitialized) {
        await initialize();
        return;
      }
      
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      
      // Update cached keys
      _cachedGptKey = remoteConfig.getString('GPT_API_KEY');
      _cachedGeminiKey = remoteConfig.getString('GEMINI_API_KEY');
      
      debugPrint('🔐 API keys refreshed successfully');
      logKeyStatus();
    } catch (e) {
      debugPrint('❌ Error refreshing API keys: $e');
    }
  }
  
  /// Check if all required API keys are available
  static bool hasRequiredKeys() {
    final gptKey = getGptApiKey();
    final geminiKey = getGeminiApiKey();
    
    return gptKey.isNotEmpty && geminiKey.isNotEmpty;
  }
  
  /// Logs the status of API keys (whether they exist or not) without exposing the actual keys
  static void logKeyStatus() {
    final gptKeyExists = getGptApiKey().isNotEmpty;
    final geminiKeyExists = getGeminiApiKey().isNotEmpty;
    
    debugPrint('API Key Status:');
    debugPrint('- GPT API Key: ${gptKeyExists ? "✅ Found" : "❌ Missing"}');
    debugPrint('- Gemini API Key: ${geminiKeyExists ? "✅ Found" : "❌ Missing"}');
    debugPrint('- Keys source: Firebase Remote Config');
  }
} 