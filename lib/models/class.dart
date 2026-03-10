import 'package:cloud_firestore/cloud_firestore.dart';

class Class {
  final String id;
  final String name;
  final String teacherId;
  final String subject;
  final List<Map<String, dynamic>> schedule;  
  final Map<String, double> location;  
  final List<String> students;  
  final DateTime createdAt;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    this.subject = '',
    required this.schedule,
    required this.location,
    this.students = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Class.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Class(
      id: doc.id,
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      subject: data['subject'] ?? '',
      schedule: List<Map<String, dynamic>>.from(data['schedule'] ?? []),
      location: Map<String, double>.from(data['location'] ?? {}),
      students: List<String>.from(data['students'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'subject': subject,
      'schedule': schedule,
      'location': location,
      'students': students,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
