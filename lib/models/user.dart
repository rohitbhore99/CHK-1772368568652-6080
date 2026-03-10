import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String role; 
  final String name;
  final String? profileImage;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.profileImage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      name: data['name'] ?? '',
      profileImage: data['profileImage'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
