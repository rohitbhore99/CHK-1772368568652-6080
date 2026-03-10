import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import 'face_recognition_service.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FaceRecognitionService _faceService = FaceRecognitionService();

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled';
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> markAttendance({
    required String studentId,
    required String classId,
    required List<double> faceEmbedding,
    required List<double> storedEmbeddings,
    Position? location,
  }) async {
     final similarity = _faceService.calculateSimilarity(faceEmbedding, storedEmbeddings);
    if (similarity < 0.6) { // Threshold for face match
      throw 'Face verification failed. Please try again.';
    }

     final classData = await _getClassData(classId);

     final hasClassLocation = classData.location.isNotEmpty &&
        (classData.location['lat'] ?? 0.0) != 0.0 &&
        (classData.location['lng'] ?? 0.0) != 0.0;

    if (hasClassLocation) {
      if (location == null) {
        throw 'GPS location is required for this class.\n'
            'Please enable location services and try again.';
      }

      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        classData.location['lat'] ?? 0.0,
        classData.location['lng'] ?? 0.0,
      );

      final radius = classData.location['radius'] ?? 100.0; // Default 100m
      if (distance > radius) {
        throw 'Location verification failed! '
            'You are ${distance.toStringAsFixed(0)}m away from the classroom.\n'
            'Allowed radius: ${radius.toStringAsFixed(0)}m.\n'
            'Please move closer to the classroom location to mark attendance.';
      }
    }

     final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final existingAttendance = await _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    if (existingAttendance.docs.isNotEmpty) {
      throw 'Attendance already marked for today.';
    }

     final attendance = Attendance(
      id: '',
      studentId: studentId,
      classId: classId,
      date: today,
      status: 'present',
      markedBy: 'auto',
      location: location != null ? {
        'lat': location.latitude,
        'lng': location.longitude,
      } : null,
      confidence: similarity,
      verificationMethod: 'face',
    );

    await _db.collection('attendance').add(attendance.toMap());

    // Update student's last attendance
    await _db.collection('students').doc(studentId).update({
      'lastAttendance': Timestamp.fromDate(today),
    });
  }

  Future<Class> _getClassData(String classId) async {
    final doc = await _db.collection('classes').doc(classId).get();
    return Class.fromFirestore(doc);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Stream<List<Attendance>> getClassAttendance(String classId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db.collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromFirestore(doc))
            .toList());
  }

  Stream<List<Attendance>> getStudentAttendance(String studentId, {int limit = 30}) {
    return _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromFirestore(doc))
            .toList());
  }

  Future<Map<String, dynamic>> getAttendanceStats(String classId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final attendance = await _db.collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final totalRecords = attendance.docs.length;
    final presentCount = attendance.docs.where((doc) =>
        (doc.data()['status'] as String?) == 'present').length;

    final attendanceRate = totalRecords > 0 ? (presentCount / totalRecords) * 100 : 0.0;

    return {
      'totalRecords': totalRecords,
      'presentCount': presentCount,
      'attendanceRate': attendanceRate,
      'period': 'Last 30 days',
    };
  }
}
