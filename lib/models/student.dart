import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String userId;
  final String classId;
  final String enrollmentNumber;
  final String name;
  final String email;
  final List<double> faceEmbeddings;  
  final DateTime registeredAt;
  final DateTime? lastAttendance;
  final String? profileImage;
  final String? registeredBy; // Teacher ID who registered this student

  Student({
    required this.id,
    required this.userId,
    required this.classId,
    required this.enrollmentNumber,
    required this.name,
    required this.email,
    required this.faceEmbeddings,
    DateTime? registeredAt,
    this.lastAttendance,
    this.profileImage,
    this.registeredBy,
  }) : registeredAt = registeredAt ?? DateTime.now();

  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      userId: data['userId'] ?? '',
      classId: data['classId'] ?? '',
      enrollmentNumber: data['enrollmentNumber'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      faceEmbeddings: List<double>.from(data['faceEmbeddings'] ?? []),
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastAttendance: (data['lastAttendance'] as Timestamp?)?.toDate(),
      profileImage: data['profileImage'],
      registeredBy: data['registeredBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'classId': classId,
      'enrollmentNumber': enrollmentNumber,
      'name': name,
      'email': email,
      'faceEmbeddings': faceEmbeddings,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'lastAttendance': lastAttendance != null ? Timestamp.fromDate(lastAttendance!) : null,
      'profileImage': profileImage,
      'registeredBy': registeredBy,
    };
  }
}
