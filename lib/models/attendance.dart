import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String studentId;
  final String classId;
  final DateTime date;
  final String status;  
  final String markedBy;  
  final Map<String, double>? location; 
  final double confidence; 
  final String verificationMethod; 
  final DateTime timestamp;

  Attendance({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    this.status = 'present',
    this.markedBy = 'auto',
    this.location,
    this.confidence = 1.0,
    this.verificationMethod = 'face',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      classId: data['classId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'present',
      markedBy: data['markedBy'] ?? 'auto',
      location: data['location'] != null ? Map<String, double>.from(data['location']) : null,
      confidence: (data['confidence'] ?? 1.0).toDouble(),
      verificationMethod: data['verificationMethod'] ?? 'face',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'classId': classId,
      'date': Timestamp.fromDate(date),
      'status': status,
      'markedBy': markedBy,
      'location': location,
      'confidence': confidence,
      'verificationMethod': verificationMethod,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
