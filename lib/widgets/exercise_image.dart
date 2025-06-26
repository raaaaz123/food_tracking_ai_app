import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import '../services/local_storage_service.dart';

class ExerciseImage extends StatelessWidget {
  final String imageSource;
  final String? localPath;
  final String label;
  final double height;
  final double width;
  final Color primaryColor;

  const ExerciseImage({
    Key? key,
    required this.imageSource,
    this.localPath,
    required this.label,
    this.height = 150,
    this.width = double.infinity,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    // If it's a URL, display it directly
    if (imageSource.startsWith('http')) {
      return Image.network(
        imageSource,
        height: height,
        width: width,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingContainer();
        },
        errorBuilder: (context, error, stackTrace) {
   
          return _buildErrorContainer();
        },
      );
    } 
    // Otherwise try to handle it as a base64 image
    else if (imageSource.startsWith('data:')) {
      try {
        // Extract base64 data from data URI
        String base64Data = imageSource.split('base64,')[1];
        
        // Decode base64 to bytes
        final Uint8List bytes = base64Decode(base64Data);
        
        // Create image from bytes
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            
            return _buildErrorContainer();
          },
        );
      } catch (e) {
     
        return _buildErrorContainer();
      }
    }
    // Fallback error container
    else {
      return _buildErrorContainer();
    }
  }

  Widget _buildLoadingContainer() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              color: Colors.grey[400],
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}