import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student.dart';
import '../services/student_service.dart';
import '../services/face_recognition_service.dart';
import '../services/class_service.dart';
import '../models/class.dart';

class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({super.key});

  @override
  State<StudentRegistrationPage> createState() => _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  final ClassService _classService = ClassService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _enrollmentController = TextEditingController();
  String? _selectedClass;
  bool _isProcessing = false;
  bool _isCameraReady = false;
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

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
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera error: $e');
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

  Future<void> _captureAndRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _enrollmentController.text.isEmpty ||
        _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
       final frames = await _captureMultipleFrames(5);

       final inputImage = InputImage.fromFilePath(frames.first.path);
      final imageBytes = await frames.first.readAsBytes();

       final List<Face> faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) throw 'No face detected. Please look at the camera.';

       final frameBytes = await Future.wait(
        frames.map((frame) => frame.readAsBytes())
      );
      final score = await _faceService.computeLivenessScore(frameBytes);
      if (score <= 0.01) {
        throw 'Liveness check failed (move your head or blink). Score: ${score.toStringAsFixed(3)}';
      }

      
      final embedding = await _faceService.generateEmbedding(imageBytes);

      final student = Student(
        id: '',
        userId: FirebaseAuth.instance.currentUser!.uid,
        classId: _selectedClass!,
        enrollmentNumber: _enrollmentController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        faceEmbeddings: embedding,
      );

      await StudentService().registerStudent(student);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! You have been added to the class.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _nameController.dispose();
    _emailController.dispose();
    _enrollmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Student'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _enrollmentController,
              decoration: InputDecoration(
                labelText: 'Enrollment Number',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<Class>>(
              stream: _classService.getAllClasses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasError) {
                  return Text('Error loading classes: ${snapshot.error}');
                }

                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return const Text('No classes available');
                }

                return DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: classes.map((classItem) {
                    return DropdownMenuItem(
                      value: classItem.id,
                      child: Text(classItem.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedClass = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a class';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 24),

             Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isCameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: Text('Initializing camera...'),
                      ),
              ),
            ),
            const SizedBox(height: 16),

 
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Please look directly at the camera and blink or move slightly when capturing. Ensure good lighting and remove any face coverings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

             ElevatedButton(
              onPressed: _isProcessing || !_isCameraReady ? null : _captureAndRegister,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Capture Face & Register',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
