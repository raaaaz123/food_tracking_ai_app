import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LocalStorageService {
  static Future<String> saveBase64Image(String base64String, String fileName) async {
    try {
      // Remove data URI prefix if present
      String base64Data = base64String;
      if (base64String.contains('base64,')) {
        base64Data = base64String.split('base64,')[1];
      }

      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);

      // Get local storage directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, 'exercise_images', fileName);

      // Create directory if it doesn't exist
      final imageDir = Directory(path.dirname(filePath));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      // Write bytes to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

    
      return filePath;
    } catch (e) {
     
      rethrow;
    }
  }

  static Future<String?> loadLocalImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  static Future<bool> deleteLocalImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
     
      return false;
    }
  }
} 