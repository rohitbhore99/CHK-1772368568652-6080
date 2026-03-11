import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/student.dart';

class StudentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  Future<String> registerStudentWithAuth({
    required String email,
    required String password,
    required String name,
    required String classId,
    required String enrollmentNumber,
    required List<double> faceEmbeddings,
    required String registeredByTeacherId,
  }) async {
    try {
      // Check if enrollment number already exists for this class
      final existing = await _db.collection('students')
          .where('classId', isEqualTo: classId)
          .where('enrollmentNumber', isEqualTo: enrollmentNumber)
          .get();

      if (existing.docs.isNotEmpty) {
        throw 'Enrollment number already registered for this class';
      }

      // Create Firebase Auth account for the student
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;

      // Create user document with student role
      await _db.collection('users').doc(userId).set({
        'id': userId,
        'email': email.trim(),
        'name': name.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create student document
      final student = Student(
        id: '',
        userId: userId,
        classId: classId,
        enrollmentNumber: enrollmentNumber,
        name: name.trim(),
        email: email.trim(),
        faceEmbeddings: faceEmbeddings,
        registeredAt: DateTime.now(),
        registeredBy: registeredByTeacherId,
      );

      await _db.collection('students').add(student.toMap());

      return userId;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  /// Legacy method for registering student without auth account
  Future<void> registerStudent(Student student) async {
    try {
      // Check if enrollment number already exists for this class
      final existing = await _db.collection('students')
          .where('classId', isEqualTo: student.classId)
          .where('enrollmentNumber', isEqualTo: student.enrollmentNumber)
          .get();

      if (existing.docs.isNotEmpty) throw 'Enrollment number already registered for this class';

      await _db.collection('students').add(student.toMap());
    } catch (e) {
      rethrow;
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return e.message ?? 'Registration failed.';
    }
  }

  Stream<List<Student>> getStudentsByClass(String classId) {
     return _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromFirestore(doc))
            .toList());
  }

  Future<List<Student>> getAllApprovedStudents(String teacherId) async {
    try {
      final classStream = _db
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots();

      final allStudents = <Student>[];

      await for (final classSnapshot in classStream) {
        for (final classDoc in classSnapshot.docs) {
          final studentDocs = await _db
              .collection('students')
              .where('classId', isEqualTo: classDoc.id)
              .get();

          for (final studentDoc in studentDocs.docs) {
            allStudents.add(Student.fromFirestore(studentDoc));
          }
        }
        break;  
      }

      return allStudents;
    } catch (e) {
      return [];
    }
  }

  Future<Student?> getStudentById(String studentId) async {
    final doc = await _db.collection('students').doc(studentId).get();
    if (doc.exists) {
      return Student.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateStudentFaceEmbeddings(String studentId, List<double> embeddings) async {
    await _db.collection('students').doc(studentId).update({
      'faceEmbeddings': embeddings,
    });
  }

  Future<void> deleteStudent(String studentId) async {
    await _db.collection('students').doc(studentId).delete();
  }

  /// Get total students count and today's attendance stats for teacher's classes
  Future<Map<String, dynamic>> getTeacherAttendanceStats(String teacherId) async {
    try {
      // Get all classes for this teacher
      final classSnapshot = await _db
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final classes = classSnapshot.docs;
      if (classes.isEmpty) {
        return {
          'totalStudents': 0,
          'presentToday': 0,
          'absentToday': 0,
          'totalClasses': 0,
        };
      }

      // Get all students in teacher's classes
      final classIds = classes.map((c) => c.id).toList();
      final studentsSnapshot = await _db
          .collection('students')
          .where('classId', whereIn: classIds)
          .get();

      final totalStudents = studentsSnapshot.docs.length;

      // Get today's attendance
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceSnapshot = await _db
          .collection('attendance')
          .where('classId', whereIn: classIds)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final presentToday = attendanceSnapshot.docs
          .where((doc) => doc.data()['status'] == 'present')
          .length;

      final absentToday = totalStudents - presentToday;

      return {
        'totalStudents': totalStudents,
        'presentToday': presentToday,
        'absentToday': absentToday > 0 ? absentToday : 0,
        'totalClasses': classes.length,
      };
    } catch (e) {
      debugPrint('Error getting attendance stats: $e');
      return {
        'totalStudents': 0,
        'presentToday': 0,
        'absentToday': 0,
        'totalClasses': 0,
      };
    }
  }
}
