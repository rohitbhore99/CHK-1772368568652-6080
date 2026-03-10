import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';

class FaceRecognitionService {
  static const int embeddingSize = 512; // FaceNet embedding size

  Future<void> loadModel() async {
     debugPrint('Face recognition model not loaded - using demo mode');
  }

  Future<void> close() async { 
     }

  Future<List<double>> generateEmbedding(Uint8List imageBytes) async {
     
    return _generateDummyEmbedding();
  }

  List<double> _generateDummyEmbedding() {
    final random = Random();
    return List.generate(embeddingSize, (_) => random.nextDouble() * 2 - 1);
  }

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  Future<List<Face>> detectFaces(InputImage image) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final faces = await faceDetector.processImage(image);
    await faceDetector.close();
    return faces;
  }

 
  Future<bool> performLivenessCheck(List<Uint8List> frames) async {
    final score = await computeLivenessScore(frames);
    return score > 0.01 && score < 1.0; // threshold >1%
  }

   
  Future<double> computeLivenessScore(List<Uint8List> frames) async {
    if (frames.length < 2) return 0.0;

    double totalMovement = 0.0;
    for (int i = 1; i < frames.length; i++) {
      final similarity = await _calculateFrameSimilarity(frames[i - 1], frames[i]);
      final movement = 1.0 - similarity;
      totalMovement += movement;
      debugPrint('Liveness frame $i movement=$movement similarity=$similarity');
    }

    double averageMovement = totalMovement / (frames.length - 1);
    
    if (averageMovement > 1.0) averageMovement = 1.0;
    debugPrint('Liveness average movement=$averageMovement');
    return averageMovement;
  }

  Future<double> _calculateFrameSimilarity(Uint8List frame1, Uint8List frame2) async {
     if (frame1.length != frame2.length) return 0.0;

    const int sampleRate = 50; // Sample every 50th pixel for finer granularity
    int differences = 0;
    int samples = 0;

    for (int i = 0; i < frame1.length; i += sampleRate) {
      samples++;
       int diff = 0;
      for (int c = 0; c < 3 && i + c < frame1.length; c++) {
        diff += (frame1[i + c] - frame2[i + c]).abs();
      }
      if (diff > 20) differences++; // Lower threshold for meaningful difference
    }

    return differences > 0 ? 1.0 - (differences / samples) : 1.0;
  }
}
