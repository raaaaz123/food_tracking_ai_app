import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_key_service.dart';
import 'package:crypto/crypto.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'dart:async';

/// A service for handling text-to-speech functionality using OpenAI's API
class AudioService {
  static const String _openAiAudioUrl = 'https://api.openai.com/v1/audio/speech';
  static AudioPlayer? _audioPlayer;
  static bool _isInitialized = false;
  static const String _wavResponseFormat = 'wav'; // WAV format for faster processing
  static String? _currentAudioFilePath;
  static double _playbackSpeed = 1.0;
  static final Map<String, String> _audioCache = {};
  static const String _audioCacheFolder = 'recipe_audio_cache';
  
  // Stream controllers for better state management
  static final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  static final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  static final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  
  /// Initialize the audio service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _audioPlayer = AudioPlayer();
      _isInitialized = true;
      
      // Set up listeners for better state management
      _setupPlayerListeners();
      
      debugPrint('✅ AudioService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AudioService: $e');
    }
  }
  
  /// Set up listeners for the audio player
  static void _setupPlayerListeners() {
    if (_audioPlayer == null) return;
    
    // Listen for player state changes
    _audioPlayer!.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing && playerState.processingState != ProcessingState.completed;
      _isPlayingController.add(isPlaying);
      
      // Debug state changes
      debugPrint('🔊 Player state changed: playing=${playerState.playing}, state=${playerState.processingState}');
    });
    
    // Listen for position changes
    _audioPlayer!.positionStream.listen((position) {
      _positionController.add(position);
    });
    
    // Listen for duration changes
    _audioPlayer!.durationStream.listen((duration) {
      _durationController.add(duration);
    });
  }
  
  /// Dispose resources
  static void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _currentAudioFilePath = null;
    _isInitialized = false;
    
    // Close stream controllers
    _isPlayingController.close();
    _positionController.close();
    _durationController.close();
  }
  
  /// Get the audio cache directory
  static Future<Directory> getAudioCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_audioCacheFolder');
  }
  
  /// Generate a cache key for a recipe
  static String generateCacheKey(String recipeName, String instructions, String voice) {
    final content = '$recipeName-$instructions-$voice';
    final bytes = utf8.encode(content);
    final digest = md5.convert(bytes);
    return 'recipe_audio_${digest.toString()}';
  }
  
  /// Check if audio exists in cache
  static Future<String?> getFromCache(String cacheKey) async {
    // First check memory cache
    if (_audioCache.containsKey(cacheKey)) {
      debugPrint('✅ Found audio in memory cache: $cacheKey');
      return _audioCache[cacheKey];
    }
    
    // Then check file cache
    final cacheDir = await getAudioCacheDirectory();
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    final file = File('${cacheDir.path}/$cacheKey.$_wavResponseFormat');
    
    if (await file.exists()) {
      debugPrint('✅ Found audio in file cache: $cacheKey');
      // Add to memory cache
      _audioCache[cacheKey] = file.path;
      return file.path;
    }
    
    return null;
  }
  
  /// Save audio to cache
  static Future<void> saveToCache(String cacheKey, String filePath) async {
    // Save to memory cache
    _audioCache[cacheKey] = filePath;
    
    // Save to file cache (copy the file to cache directory)
    final cacheDir = await getAudioCacheDirectory();
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    final cachedFile = File('${cacheDir.path}/$cacheKey.$_wavResponseFormat');
    
    // If the file is not already in the cache directory
    if (filePath != cachedFile.path) {
      await File(filePath).copy(cachedFile.path);
      debugPrint('✅ Saved audio to cache: $cacheKey');
    }
  }
  
  /// Generate speech from text and return the local file path
  static Future<String?> generateSpeech({
    required String text,
    String voice = 'alloy',
    String instructions = 'Speak in a clear, instructional tone.',
    String? cacheKey,
  }) async {
    try {
      // Check cache if cacheKey is provided
      if (cacheKey != null) {
        final cachedPath = await getFromCache(cacheKey);
        if (cachedPath != null) {
          return cachedPath;
        }
      }
      
      // Get API key
      final apiKey = ApiKeyService.getGptApiKey();
      if (apiKey.isEmpty) {
        debugPrint('❌ OpenAI API key is not available');
        return null;
      }
      
      debugPrint('🔊 Generating speech for text: ${text.length > 20 ? text.substring(0, 20) + "..." : text}');
      
      // Make API request
      final response = await http.post(
        Uri.parse(_openAiAudioUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': text,
          'voice': voice,
          'instructions': instructions,
          'response_format': _wavResponseFormat
        }),
      );
      
      if (response.statusCode == 200) {
        // Save audio file to temporary directory
        final tempDir = await getTemporaryDirectory();
        final fileName = 'speech_${DateTime.now().millisecondsSinceEpoch}.$_wavResponseFormat';
        final filePath = '${tempDir.path}/$fileName';
        
        // Write audio data to file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _currentAudioFilePath = filePath;
        
        // Save to cache if cacheKey is provided
        if (cacheKey != null) {
          await saveToCache(cacheKey, filePath);
        }
        
        debugPrint('✅ Speech generated successfully: $filePath');
        return filePath;
      } else {
        debugPrint('❌ Failed to generate speech: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error generating speech: $e');
      return null;
    }
  }
  
  /// Generate speech directly from recipe data for improved performance
  static Future<String?> generateRecipeSpeech({
    required String recipeName,
    required String description,
    required List<String> ingredients,
    required String instructions,
    String voice = 'alloy',
  }) async {
    try {
      // Format the recipe text without ingredients to make audio generation faster
      final recipeText = _formatRecipeForSpeech(
        recipeName: recipeName,
        description: description,
        instructions: instructions
      );
      
      // Generate a cache key for this recipe
      final cacheKey = generateCacheKey(recipeName, instructions, voice);
      
      return await generateSpeech(
        text: recipeText,
        voice: voice,
        instructions: 'Speak in a clear, instructional tone with appropriate pauses between sections.',
        cacheKey: cacheKey
      );
    } catch (e) {
      debugPrint('❌ Error generating recipe speech: $e');
      return null;
    }
  }
  
  /// Format recipe data for speech synthesis (excluding ingredients)
  static String _formatRecipeForSpeech({
    required String recipeName,
    required String description,
    required String instructions,
  }) {
    final StringBuffer buffer = StringBuffer();
    
    // Introduction
    buffer.writeln("Recipe for $recipeName.");
    buffer.writeln(description);
    buffer.writeln();
    
    // Instructions (skip ingredients section)
    buffer.writeln("Instructions:");
    buffer.writeln(instructions);
    
    return buffer.toString();
  }
  
  /// Clear audio cache
  static Future<void> clearCache() async {
    try {
      // Clear memory cache
      _audioCache.clear();
      
      // Clear file cache
      final cacheDir = await getAudioCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      
      debugPrint('🧹 Audio cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing audio cache: $e');
    }
  }
  
  /// Get cache size in MB
  static Future<double> getCacheSizeMB() async {
    try {
      final cacheDir = await getAudioCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0.0;
      }
      
      int totalSize = 0;
      await for (var entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      // Convert to MB
      return totalSize / (1024 * 1024);
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0.0;
    }
  }
  
  /// Play audio from a file path
  static Future<bool> playAudio(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      _currentAudioFilePath = filePath;
      
      // Stop any currently playing audio
      await _audioPlayer!.stop();
      
      // Set the audio source and play
      await _audioPlayer!.setFilePath(filePath);
      await _audioPlayer!.setSpeed(_playbackSpeed);
      await _audioPlayer!.play();
      
      debugPrint('▶️ Playing audio: $filePath');
      return true;
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      return false;
    }
  }
  
  /// Resume playback if paused
  static Future<bool> resumePlayback() async {
    try {
      if (_audioPlayer == null) return false;
      
      // Force play regardless of current state
      await _audioPlayer!.play();
      
      // Update the playing state
      _isPlayingController.add(true);
      
      debugPrint('▶️ Resumed audio playback');
      return true;
    } catch (e) {
      debugPrint('❌ Error resuming audio: $e');
      return false;
    }
  }
  
  /// Pause playback
  static Future<bool> pausePlayback() async {
    try {
      if (_audioPlayer == null) return false;
      
      // Force pause regardless of current state
      await _audioPlayer!.pause();
      
      // Update the playing state
      _isPlayingController.add(false);
      
      debugPrint('⏸️ Paused audio playback');
      return true;
    } catch (e) {
      debugPrint('❌ Error pausing audio: $e');
      return false;
    }
  }
  
  /// Toggle play/pause
  static Future<bool> togglePlayPause() async {
    try {
      if (_audioPlayer == null) return false;
      
      final playerState = _audioPlayer!.playerState;
      
      if (playerState.playing) {
        await _audioPlayer!.pause();
        debugPrint('⏸️ Paused audio playback');
      } else {
        await _audioPlayer!.play();
        debugPrint('▶️ Resumed audio playback');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
      return false;
    }
  }
  
  /// Seek to a specific position in the audio
  static Future<bool> seekTo(Duration position) async {
    try {
      if (_audioPlayer == null) return false;
      
      await _audioPlayer!.seek(position);
      debugPrint('⏩ Seeked to position: ${position.inSeconds}s');
      return true;
    } catch (e) {
      debugPrint('❌ Error seeking audio: $e');
      return false;
    }
  }
  
  /// Set playback speed
  static Future<bool> setPlaybackSpeed(double speed) async {
    try {
      if (_audioPlayer == null) return false;
      
      _playbackSpeed = speed;
      await _audioPlayer!.setSpeed(speed);
      debugPrint('🚀 Set playback speed to: ${speed}x');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting playback speed: $e');
      return false;
    }
  }
  
  /// Get current playback speed
  static double getPlaybackSpeed() {
    return _playbackSpeed;
  }
  
  /// Restart audio from beginning
  static Future<bool> restartAudio() async {
    try {
      if (_audioPlayer == null) return false;
      
      await _audioPlayer!.seek(Duration.zero);
      await _audioPlayer!.play();
      
      debugPrint('🔄 Restarted audio playback');
      return true;
    } catch (e) {
      debugPrint('❌ Error restarting audio: $e');
      return false;
    }
  }
  
  /// Stop audio playback
  static Future<void> stopAudio() async {
    try {
      await _audioPlayer?.stop();
      debugPrint('⏹️ Audio playback stopped');
    } catch (e) {
      debugPrint('❌ Error stopping audio: $e');
    }
  }
  
  /// Check if audio is currently playing
  static bool isPlaying() {
    if (_audioPlayer == null) return false;
    final playerState = _audioPlayer!.playerState;
    return playerState.playing && playerState.processingState != ProcessingState.completed;
  }
  
  /// Check if audio is currently paused
  static bool isPaused() {
    if (_audioPlayer == null) return false;
    final playerState = _audioPlayer!.playerState;
    return !playerState.playing && playerState.processingState != ProcessingState.completed;
  }
  
  /// Check if audio is completed
  static bool isCompleted() {
    if (_audioPlayer == null) return false;
    return _audioPlayer!.playerState.processingState == ProcessingState.completed;
  }
  
  /// Get current position of audio playback
  static Duration getCurrentPosition() {
    return _audioPlayer?.position ?? Duration.zero;
  }
  
  /// Get total duration of current audio
  static Duration? getTotalDuration() {
    return _audioPlayer?.duration;
  }
  
  /// Get a stream of player states
  static Stream<PlayerState>? getPlayerStateStream() {
    return _audioPlayer?.playerStateStream;
  }
  
  /// Get a stream of current position
  static Stream<Duration>? getPositionStream() {
    return _audioPlayer?.positionStream;
  }
  
  /// Get a stream of duration updates
  static Stream<Duration?>? getDurationStream() {
    return _audioPlayer?.durationStream;
  }
  
  /// Get a stream of playing state changes (true = playing, false = paused/stopped)
  static Stream<bool> getPlayingStream() {
    return _isPlayingController.stream;
  }
} 