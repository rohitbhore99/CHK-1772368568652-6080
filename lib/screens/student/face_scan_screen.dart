import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face/services/face_recognition_service.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/services/student_service.dart';

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

  bool _isProcessing = false;
  bool _isCameraReady = false;
  String _statusMessage = 'Initializing camera...';
  List<String> _availableClasses = [];
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadAvailableClasses();
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
          _statusMessage = 'Camera ready. Select a class and tap to scan.';
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

      // Add small delay between captures to allow for movement
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return frames;
  }

  Future<void> _loadAvailableClasses() async {
     
    setState(() {
      _availableClasses = ['class1', 'class2', 'class3'];
      _selectedClassId = _availableClasses.first;
    });
  }

  Future<void> _scanFace() async {
    if (!_isCameraReady || _selectedClassId == null) return;

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
      final student = await _studentService.getStudentById(currentUser.uid);
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
        classId: _selectedClassId!,
        faceEmbedding: embedding,
        storedEmbeddings: student.faceEmbeddings,
        location: position,
      );

      if (mounted) {
        setState(() => _statusMessage = 'Attendance marked successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully!'),
            backgroundColor: Colors.green,
          ),
        );

         Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = 'Camera ready. Select a class and tap to scan.';
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
           Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedClassId,
              decoration: InputDecoration(
                labelText: 'Select Class',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _availableClasses.map((classId) {
                return DropdownMenuItem(
                  value: classId,
                  child: Text('Class $classId'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedClassId = value);
              },
            ),
          ),
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
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            ),
          ),
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
                    onPressed: _isProcessing || !_isCameraReady || _selectedClassId == null
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

