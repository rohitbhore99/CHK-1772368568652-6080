import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';

class StudentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
}
