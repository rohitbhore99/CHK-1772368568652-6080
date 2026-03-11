import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face/services/face_recognition_service.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/services/student_service.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/class.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final AttendanceService _attendanceService = AttendanceService();
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();

  bool _isProcessing = false;
  bool _isCameraReady = false;
  String _statusMessage = 'Initializing camera...';
  Class? _enrolledClass;
  bool _isLoadingClass = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadEnrolledClass();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera found');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusMessage = 'Camera ready. Tap to scan your face.';
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Camera error: $e');
    }
  }

  Future<List<XFile>> _captureMultipleFrames(int count) async {
    final frames = <XFile>[];

    for (int i = 0; i < count; i++) {
      final frame = await _cameraController!.takePicture();
      frames.add(frame);

      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return frames;
  }

  Future<void> _loadEnrolledClass() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingClass = false;
        _hasError = true;
        _errorMessage = 'User not logged in';
      });
      return;
    }

    try {
      // Get student data using userId (auth user id)
      final student = await _studentService.getStudentByUserId(currentUser.uid);
      
      if (student == null || student.classId.isEmpty) {
        setState(() {
          _isLoadingClass = false;
          _hasError = true;
          _errorMessage = 'No class enrolled. Please contact your teacher.';
        });
        return;
      }

      // Get the class details
      final classData = await _classService.getClassById(student.classId);
      
      if (mounted) {
        setState(() {
          _enrolledClass = classData;
          _isLoadingClass = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingClass = false;
          _hasError = true;
          _errorMessage = 'Error loading class: $e';
        });
      }
    }
  }

  Future<void> _scanFace() async {
    if (!_isCameraReady || _enrolledClass == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Detecting face...';
    });

    try {
      setState(() => _statusMessage = 'Capturing frames for liveness check...\nPlease blink or move slightly.');
      final frames = await _captureMultipleFrames(5);

      setState(() => _statusMessage = 'Processing face...');
      final faces = await _faceService.detectFaces(
        InputImage.fromFilePath(frames.first.path),
      );

      if (faces.isEmpty) {
        throw 'No face detected. Please look at the camera.';
      }

      setState(() => _statusMessage = 'Generating face embedding...');
      final imageBytes = await frames.first.readAsBytes();
      final embedding = await _faceService.generateEmbedding(imageBytes);

      setState(() => _statusMessage = 'Checking liveness...');
      final frameBytes = await Future.wait(
        frames.map((frame) => frame.readAsBytes())
      );
      final score = await _faceService.computeLivenessScore(frameBytes);
      if (score <= 0.01) {
        throw 'Liveness check failed (move your head or blink). Score: ${score.toStringAsFixed(3)}';
      }

      final currentUser = FirebaseAuth.instance.currentUser!;
      final student = await _studentService.getStudentByUserId(currentUser.uid);
      if (student == null) {
        throw 'Student data not found. Please contact administrator.';
      }

      setState(() => _statusMessage = 'Verifying identity...');
      final similarity = _faceService.calculateSimilarity(
        embedding,
        student.faceEmbeddings,
      );

      if (similarity < 0.6) {
        throw 'Face verification failed. Please try again.';
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        // Location not available, continue without it
      }

      setState(() => _statusMessage = 'Marking attendance...');
      await _attendanceService.markAttendance(
        studentId: currentUser.uid,
        classId: _enrolledClass!.id,
        faceEmbedding: embedding,
        storedEmbeddings: student.faceEmbeddings,
        location: position,
      );

      if (mounted) {
        setState(() => _statusMessage = 'Attendance marked successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked for ${_enrolledClass!.name}!'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Camera ready. Tap to scan your face.';
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Scan Attendance'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Class Info Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingClass
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : _hasError
                    ? Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.class_,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Enrolled Class',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _enrolledClass?.name ?? 'No class',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          
          // Camera Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isCameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          
          // Status and Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isProcessing ? Colors.orange : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing || !_isCameraReady || _enrolledClass == null || _hasError
                        ? null
                        : _scanFace,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Scan Face & Mark Attendance',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

