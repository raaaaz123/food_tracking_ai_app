import 'dart:convert';

class FaceAnalysisRecommendation {
  final String title;
  final String description;

  FaceAnalysisRecommendation({
    required this.title,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }

  factory FaceAnalysisRecommendation.fromJson(Map<String, dynamic> json) {
    return FaceAnalysisRecommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class FaceAnalysis {
  final String id;
  final DateTime timestamp;
  final Map<String, int> scores;
  final Map<String, String> attributes;
  final List<FaceAnalysisRecommendation> recommendations;
  final String? faceImagePath;
  final String? angleImagePath;
  final String? sideImagePath;

  FaceAnalysis({
    required this.id,
    required this.timestamp,
    required this.scores,
    required this.attributes,
    required this.recommendations,
    this.faceImagePath,
    this.angleImagePath,
    this.sideImagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'scores': scores,
      'attributes': attributes,
      'recommendations': recommendations.map((rec) => rec.toJson()).toList(),
      'faceImagePath': faceImagePath,
      'angleImagePath': angleImagePath,
      'sideImagePath': sideImagePath,
    };
  }

  factory FaceAnalysis.fromJson(Map<String, dynamic> json) {
    return FaceAnalysis(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      scores: Map<String, int>.from(json['scores'] ?? {}),
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((recJson) => FaceAnalysisRecommendation.fromJson(recJson))
          .toList(),
      faceImagePath: json['faceImagePath'],
      angleImagePath: json['angleImagePath'],
      sideImagePath: json['sideImagePath'],
    );
  }

  // Helper method to get string representation
  @override
  String toString() {
    return jsonEncode(toJson());
  }
} 