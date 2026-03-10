import 'package:cloud_firestore/cloud_firestore.dart';

class Teacher {
  final String id;
  final String userId;
  final List<String> classes;  
  final String department;
  final String? permissions;  
  final DateTime createdAt;

  Teacher({
    required this.id,
    required this.userId,
    this.classes = const [],
    required this.department,
    this.permissions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Teacher(
      id: doc.id,
      userId: data['userId'] ?? '',
      classes: List<String>.from(data['classes'] ?? []),
      department: data['department'] ?? '',
      permissions: data['permissions'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'classes': classes,
      'department': department,
      'permissions': permissions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
